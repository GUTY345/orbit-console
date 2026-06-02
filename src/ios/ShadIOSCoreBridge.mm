#import "ShadIOSCoreBridge.h"

#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>
#include <TargetConditionals.h>
#include <atomic>
#include <chrono>
#include <cstdio>
#include <cstring>
#include <csignal>
#include <filesystem>
#include <malloc/malloc.h>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <vector>
#include <cstdlib>
#include <system_error>
#include <sys/sysctl.h>
#include <sys/syscall.h>
#include <unistd.h>

#ifndef CS_OPS_STATUS
#define CS_OPS_STATUS 0
#endif
#ifndef CS_DEBUGGED
#define CS_DEBUGGED 0x10000000
#endif

#include "common/singleton.h"
#include "common/ios_low_memory.h"
#include "common/path_util.h"
#include "core/emulator_settings.h"
#include "core/libraries/kernel/time.h"
#include "emulator.h"
#include "input/controller.h"

static NSString* const ShadFrameLimitDefaultsKey = @"ShadIOSFrameLimit";
static NSString* const ShadSettingEnableLogKey = @"ShadIOSSettingEnableLog";
static NSString* const ShadSettingInternalResolutionKey = @"ShadIOSSettingInternalResolution";
static NSString* const ShadSettingVSyncKey = @"ShadIOSSettingVSync";
static NSString* const ShadSettingFrameGenerationKey = @"ShadIOSSettingFrameGeneration";
static NSString* const ShadSettingMoltenVKValidationKey = @"ShadIOSSettingMoltenVKValidation";
static NSString* const ShadSettingMoltenVKFastMathKey = @"ShadIOSSettingMoltenVKFastMath";
static NSString* const ShadSettingMoltenVKPresentModeKey = @"ShadIOSSettingMoltenVKPresentMode";
static NSString* const ShadSettingRuntimeStatsOverlayKey = @"ShadIOSSettingRuntimeStatsOverlay";
static NSString* const ShadSettingRuntimeStatsFPSKey = @"ShadIOSSettingRuntimeStatsFPS";
static NSString* const ShadSettingMasterVolumeKey = @"ShadIOSSettingMasterVolume";
static NSString* const ShadSettingAudioDriverBackendKey = @"ShadIOSSettingAudioDriverBackend";
static NSString* const ShadSettingSDLBufferModeKey = @"ShadIOSSettingSDLBufferMode";
static NSString* const ShadSettingThermalGuardKey = @"ShadIOSSettingThermalGuard";
static NSString* const ShadSettingShaderCacheEnabledKey = @"ShadIOSDebugShaderCacheEnabled";
static NSString* const ShadSettingPipelineCacheEnabledKey = @"ShadIOSDebugPipelineCacheEnabled";
static NSString* const ShadSettingShaderMissLoggingKey = @"ShadIOSDebugShaderMissLogging";
static NSString* const ShadSettingShaderDumpKey = @"ShadIOSDebugShaderDump";

static NSInteger ShadIOSClampedFrameLimit(NSInteger fps) {
    if (fps <= 0) {
        return 30;
    }
    return MIN(MAX(fps, 30), 40);
}

static NSTimeInterval ShadIOSJITSettleDelay() {
    const char* raw = getenv("SHADPS4_IOS_JIT_SETTLE_DELAY_MS");
    if (raw == nullptr || raw[0] == '\0') {
        return 1.5;
    }
    char* end = nullptr;
    const long parsed = strtol(raw, &end, 10);
    if (end == raw) {
        return 1.5;
    }
    return MAX(0.0, MIN((NSTimeInterval)parsed / 1000.0, 3.0));
}

static std::atomic_bool gShadIOSCrashHandlersInstalled{false};
static std::atomic<void*> gShadIOSNativeMetalLayer{nullptr};
static std::atomic<float> gShadIOSNativeRenderScale{1.0f};
static std::atomic<int> gShadIOSCoreStage{0};
static char gShadIOSCrashCheckpoint[256] = "bridge initialized";
static char gShadIOSCoreStageDescription[256] = "idle";

extern "C" void ShadIOSAppendDiagnosticLog(const char* message) {
    @autoreleasepool {
        if (message == nullptr || message[0] == '\0') {
            return;
        }

        NSArray<NSURL*>* urls = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory
                                                                      inDomains:NSUserDomainMask];
        NSURL* documentsURL = urls.firstObject;
        if (documentsURL == nil) {
            return;
        }

        NSURL* logURL = [documentsURL URLByAppendingPathComponent:@"orbit_console_cpu.log"];
        NSString* line = [NSString stringWithFormat:@"%lld %s\n",
                                                    (long long)(NSDate.date.timeIntervalSince1970 * 1000.0),
                                                    message];
        NSData* data = [line dataUsingEncoding:NSUTF8StringEncoding];
        if (![NSFileManager.defaultManager fileExistsAtPath:logURL.path]) {
            [data writeToURL:logURL atomically:YES];
            return;
        }

        NSFileHandle* handle = [NSFileHandle fileHandleForWritingToURL:logURL error:nil];
        if (handle == nil) {
            return;
        }
        @try {
            [handle seekToEndOfFile];
            [handle writeData:data];
        } @catch (__unused NSException* exception) {
        }
        [handle closeFile];
    }
}

static void ShadIOSSetCrashCheckpoint(const char* checkpoint) {
    if (checkpoint == nullptr) {
        return;
    }
    std::snprintf(gShadIOSCrashCheckpoint, sizeof(gShadIOSCrashCheckpoint), "%s", checkpoint);
    NSLog(@"shadPS4 iOS checkpoint: %s", gShadIOSCrashCheckpoint);
    ShadIOSAppendDiagnosticLog(gShadIOSCrashCheckpoint);
}

extern "C" void ShadIOSSetCoreStage(int stage, const char* description) {
    gShadIOSCoreStage.store(stage, std::memory_order_release);
    if (description != nullptr) {
        std::snprintf(gShadIOSCoreStageDescription, sizeof(gShadIOSCoreStageDescription), "%s",
                      description);
        NSLog(@"shadPS4 iOS core stage %d: %s", stage, gShadIOSCoreStageDescription);
        ShadIOSAppendDiagnosticLog(
            std::string("core stage " + std::to_string(stage) + ": " + gShadIOSCoreStageDescription)
                .c_str());
    }
}

extern "C" int ShadIOSGetCoreStage(void) {
    return gShadIOSCoreStage.load(std::memory_order_acquire);
}

extern "C" const char* ShadIOSGetCoreStageDescription(void) {
    return gShadIOSCoreStageDescription;
}

static const char* ShadIOSSignalName(int signalNumber) {
    switch (signalNumber) {
    case SIGSEGV:
        return "SIGSEGV Bad Access";
    case SIGBUS:
        return "SIGBUS Memory Error";
    case SIGILL:
        return "SIGILL Illegal Instruction";
    case SIGTRAP:
        return "SIGTRAP Debug Trap";
    default:
        return "Unknown Signal";
    }
}

static void ShadIOSSignalCrashHandler(int signalNumber, siginfo_t* info, void*) {
    char message[640];
    const int length = std::snprintf(
        message, sizeof(message),
        "\nshadPS4 iOS CRASH DETECTED: %s (%d) address=%p last_checkpoint=\"%s\"\n"
        "Open Console.app or Xcode device logs and search for \"shadPS4 iOS checkpoint\" to find the last stage before Core::Emulator::Run failed.\n",
        ShadIOSSignalName(signalNumber), signalNumber, info != nullptr ? info->si_addr : nullptr,
        gShadIOSCrashCheckpoint);
    if (length > 0) {
        write(STDERR_FILENO, message, (size_t)MIN(length, (int)sizeof(message) - 1));
    }
    signal(signalNumber, SIG_DFL);
    raise(signalNumber);
}

static void ShadIOSInstallCrashHandlers(void) {
    bool expected = false;
    if (!gShadIOSCrashHandlersInstalled.compare_exchange_strong(expected, true)) {
        return;
    }

    struct sigaction action {};
    action.sa_sigaction = ShadIOSSignalCrashHandler;
    sigemptyset(&action.sa_mask);
    action.sa_flags = SA_SIGINFO | SA_NODEFER;
    sigaction(SIGSEGV, &action, nullptr);
    sigaction(SIGBUS, &action, nullptr);
    sigaction(SIGILL, &action, nullptr);
    sigaction(SIGTRAP, &action, nullptr);
    NSLog(@"shadPS4 iOS core: advanced signal crash handler installed");
}

static BOOL ShadIOSBoolForKey(NSString* key, BOOL defaultValue) {
    id stored = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    return stored == nil ? defaultValue : [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

static NSInteger ShadIOSIntegerForKey(NSString* key, NSInteger defaultValue) {
    id stored = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    return stored == nil ? defaultValue : [[NSUserDefaults standardUserDefaults] integerForKey:key];
}

static NSInteger ShadIOSResolutionHeight(void) {
    NSInteger selected = ShadIOSIntegerForKey(ShadSettingInternalResolutionKey, 2);
    if (selected <= 0) {
        return 720;
    }
    if (selected == 1) {
        return 900;
    }
    return 1080;
}

static NSInteger ShadIOSFrameLimitFromDefaults(void) {
    id stored = [[NSUserDefaults standardUserDefaults] objectForKey:ShadFrameLimitDefaultsKey];
    if (stored == nil) {
        return 30;
    }
    NSInteger raw = [[NSUserDefaults standardUserDefaults] integerForKey:ShadFrameLimitDefaultsKey];
    if (raw >= 30) {
        return ShadIOSClampedFrameLimit(raw);
    }
    NSArray<NSNumber*>* table = @[ @30, @35, @40 ];
    return table[(NSUInteger)MIN(MAX(raw, 0), 2)].integerValue;
}

static NSInteger ShadIOSSDLBufferFrames(void) {
    const NSInteger mode = ShadIOSIntegerForKey(ShadSettingSDLBufferModeKey, 1);
    if (mode <= 0) {
        return 512;
    }
    return 1024;
}

static std::filesystem::path ShadIOSResolveRunnablePath(NSString* pathString) {
    std::filesystem::path path(pathString.UTF8String ?: "");
    if (std::filesystem::is_directory(path)) {
        const std::filesystem::path direct = path / "eboot.bin";
        if (std::filesystem::exists(direct)) {
            return direct;
        }
        const std::filesystem::path nested = path / "sce_sys" / ".." / "eboot.bin";
        if (std::filesystem::exists(nested)) {
            return std::filesystem::weakly_canonical(nested);
        }
    }
    return path;
}

static bool ShadIOSProcessIsDebugged(void) {
#if TARGET_OS_IOS
    uint32_t flags = 0;
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};
    struct kinfo_proc info {};
    size_t infoSize = sizeof(info);
    if (sysctl(mib, 4, &info, &infoSize, nullptr, 0) == 0 && (info.kp_proc.p_flag & P_TRACED) != 0) {
        return true;
    }
    if (syscall(SYS_csops, getpid(), CS_OPS_STATUS, &flags, sizeof(flags)) == 0) {
        return (flags & CS_DEBUGGED) != 0;
    }
#endif
    return false;
}

static void ShadIOSRemovePathIfPresent(const std::filesystem::path& path) {
    if (path.empty()) {
        return;
    }
    std::error_code ec;
    if (!std::filesystem::exists(path, ec)) {
        return;
    }
    ShadIOSSetCrashCheckpoint("purging stale graphics cache");
    const auto removed = std::filesystem::remove_all(path, ec);
    if (ec) {
        NSLog(@"shadPS4 iOS cache purge: failed to remove %s: %s", path.string().c_str(),
              ec.message().c_str());
    } else {
        NSLog(@"shadPS4 iOS cache purge: removed %llu entries from %s",
              (unsigned long long)removed, path.string().c_str());
    }
}

static void ShadIOSClearGraphicsCaches(void) {
    ShadIOSSetCrashCheckpoint("clearing MoltenVK/shader/pipeline caches");

    std::error_code ec;
    const std::filesystem::path cacheDir = Common::FS::GetUserPath(Common::FS::PathType::CacheDir);
    const std::filesystem::path shaderDir = Common::FS::GetUserPath(Common::FS::PathType::ShaderDir);
    ShadIOSRemovePathIfPresent(cacheDir);
    ShadIOSRemovePathIfPresent(shaderDir / "dump");
    std::filesystem::create_directories(cacheDir, ec);
    std::filesystem::create_directories(shaderDir, ec);

    NSFileManager* fileManager = NSFileManager.defaultManager;
    NSArray<NSURL*>* cacheRoots = [fileManager URLsForDirectory:NSCachesDirectory
                                                       inDomains:NSUserDomainMask];
    NSURL* root = cacheRoots.firstObject;
    NSArray<NSString*>* staleNames = @[
        @"MoltenVK", @"ShaderCache", @"PipelineCache", @"pipeline_cache", @"shader_cache",
        @"shadPS4", @"shadps4"
    ];
    for (NSString* name in staleNames) {
        NSURL* url = [root URLByAppendingPathComponent:name];
        if ([fileManager fileExistsAtPath:url.path]) {
            NSError* removeError = nil;
            [fileManager removeItemAtURL:url error:&removeError];
            if (removeError != nil) {
                NSLog(@"shadPS4 iOS cache purge: failed to remove %@: %@", url.path,
                      removeError.localizedDescription);
            } else {
                NSLog(@"shadPS4 iOS cache purge: removed %@", url.path);
            }
        }
    }
}

static void ShadIOSApplySafeGraphicsBootstrap(void) {
    ShadIOSSetCrashCheckpoint("applying safe MoltenVK bootstrap");
    setenv("MVK_CONFIG_FAST_MATH_ENABLED", "0", 1);
    setenv("MVK_CONFIG_SYNCHRONOUS_QUEUE_SUBMITS", "1", 1);
    setenv("MVK_CONFIG_PREFILL_METAL_COMMAND_BUFFERS", "0", 1);
    setenv("MVK_CONFIG_MAX_ACTIVE_METAL_COMMAND_BUFFERS_PER_QUEUE", "8", 1);
    setenv("MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS", "0", 1);
    setenv("MVK_CONFIG_RESUME_LOST_DEVICE", "1", 1);
    setenv("MVK_CONFIG_LOG_LEVEL", "2", 1);
    setenv("MVK_CONFIG_PERFORMANCE_TRACKING", "0", 1);
    setenv("SHADPS4_IOS_SAFE_GRAPHICS_BOOTSTRAP", "1", 1);

    EmulatorSettings.SetPresentMode("Fifo");
    EmulatorSettings.SetVkValidationGpuEnabled(false);
    EmulatorSettings.SetFsrEnabled(false);
    EmulatorSettings.SetPipelineCacheEnabled(false);
    EmulatorSettings.SetPipelineCacheArchived(false);
    EmulatorSettings.SetDumpShaders(false);
    EmulatorSettings.SetShaderCollect(false);
    EmulatorSettings.SetCopyGpuBuffers(false);
    EmulatorSettings.SetReadbacksMode((u32)GpuReadbacksMode::Disabled);
    EmulatorSettings.SetReadbackLinearImagesEnabled(false);
    EmulatorSettings.SetDirectMemoryAccessEnabled(false);
}

static void ShadIOSApplyAggressiveMemorySavingMode(void) {
    ShadIOSSetCrashCheckpoint("applying aggressive memory saving mode");
    Common::IOSLowMemory::ConfigureProcess();
    setenv("SHADPS4_IOS_AGGRESSIVE_MEMORY_SAVING", "1", 1);
    setenv("SHADPS4_IOS_VM_COMMIT_STRATEGY", "lazy", 1);
    setenv("SHADPS4_IOS_PRELOAD_DISABLED", "1", 1);
    setenv("SHADPS4_IOS_ASSET_STREAMING", "1", 1);
    setenv("SHADPS4_IOS_PIPELINE_PREWARM", "0", 1);
    setenv("SHADPS4_IOS_MEMORY_PRESSURE_TRIM", "1", 1);

    const NSInteger frameLimit = MIN(ShadIOSFrameLimitFromDefaults(), 35);
    EmulatorSettings.SetVblankFrequency((u32)frameLimit);

    @autoreleasepool {
        [[NSURLCache sharedURLCache] removeAllCachedResponses];
        NSString* temporary = NSTemporaryDirectory();
        NSArray<NSString*>* temporaryItems =
            [NSFileManager.defaultManager contentsOfDirectoryAtPath:temporary error:nil];
        for (NSString* item in temporaryItems) {
            NSString* fullPath = [temporary stringByAppendingPathComponent:item];
            [NSFileManager.defaultManager removeItemAtPath:fullPath error:nil];
        }
    }
    malloc_zone_pressure_relief(nullptr, 0);
    Common::IOSLowMemory::PurgeNow("launch bootstrap");
    NSLog(@"shadPS4 iOS memory guard: aggressive mode enabled, launch frame cap=%ld",
          (long)frameLimit);
}

static void ShadIOSApplySettingsToCore(void) {
    auto settings = EmulatorSettingsImpl::GetInstance();
    EmulatorSettingsImpl::SetInstance(settings);

    const NSInteger frameLimit = ShadIOSFrameLimitFromDefaults();
    const NSInteger height = ShadIOSResolutionHeight();
    const NSInteger width = (height * 16) / 9;
    const BOOL enableLogs = ShadIOSBoolForKey(ShadSettingEnableLogKey, YES);
    const BOOL showStats = ShadIOSBoolForKey(ShadSettingRuntimeStatsOverlayKey, YES) &&
                           ShadIOSBoolForKey(ShadSettingRuntimeStatsFPSKey, YES);
    const BOOL pipelineCache = ShadIOSBoolForKey(ShadSettingPipelineCacheEnabledKey, YES) ||
                               ShadIOSBoolForKey(ShadSettingShaderCacheEnabledKey, YES);
    const BOOL validation = ShadIOSBoolForKey(ShadSettingMoltenVKValidationKey, NO);
    const BOOL dumpShaders = ShadIOSBoolForKey(ShadSettingShaderDumpKey, NO);
    const NSInteger presentMode = ShadIOSIntegerForKey(ShadSettingMoltenVKPresentModeKey, 0);
    const NSInteger audioBackend = ShadIOSIntegerForKey(ShadSettingAudioDriverBackendKey, 0);
    const NSInteger sdlBufferFrames = ShadIOSSDLBufferFrames();
    const NSInteger volume = (NSInteger)lrintf(([[NSUserDefaults standardUserDefaults] objectForKey:ShadSettingMasterVolumeKey] == nil
                                                   ? 0.82f
                                                   : [[NSUserDefaults standardUserDefaults] floatForKey:ShadSettingMasterVolumeKey]) *
                                               100.0f);

    EmulatorSettings.SetLogEnable(enableLogs);
    EmulatorSettings.SetVolumeSlider((int)MIN(MAX(volume, 0), 100));
    EmulatorSettings.SetAudioBackend(audioBackend == 0 ? AudioBackend::OpenAL : AudioBackend::SDL);
    EmulatorSettings.SetConnectedToNetwork(true);
    EmulatorSettings.SetShowFpsCounter(showStats);
    EmulatorSettings.SetWindowWidth((u32)width);
    EmulatorSettings.SetWindowHeight((u32)height);
    EmulatorSettings.SetInternalScreenWidth((u32)width);
    EmulatorSettings.SetInternalScreenHeight((u32)height);
    EmulatorSettings.SetVblankFrequency((u32)frameLimit);
    EmulatorSettings.SetDumpShaders(dumpShaders);
    EmulatorSettings.SetShaderCollect(ShadIOSBoolForKey(ShadSettingShaderMissLoggingKey, NO));
    EmulatorSettings.SetPipelineCacheEnabled(pipelineCache);
    EmulatorSettings.SetPipelineCacheArchived(pipelineCache);
    EmulatorSettings.SetVkValidationEnabled(validation);
    EmulatorSettings.SetVkValidationCoreEnabled(validation);
    EmulatorSettings.SetVkValidationSyncEnabled(validation);
    EmulatorSettings.SetVkValidationGpuEnabled(NO);
    EmulatorSettings.SetFsrEnabled(ShadIOSBoolForKey(ShadSettingFrameGenerationKey, NO));
    EmulatorSettings.SetPresentMode(presentMode == 1 ? "Mailbox" : (presentMode == 2 ? "Immediate" : "Fifo"));

    setenv("MVK_CONFIG_FAST_MATH_ENABLED",
           ShadIOSBoolForKey(ShadSettingMoltenVKFastMathKey, YES) ? "1" : "0", 1);
    setenv("MVK_CONFIG_SYNCHRONOUS_QUEUE_SUBMITS",
           presentMode == 0 || !ShadIOSBoolForKey(ShadSettingVSyncKey, YES) ? "1" : "0", 1);
    setenv("SHADPS4_IOS_FRAME_LIMIT", std::to_string((long long)frameLimit).c_str(), 1);
    setenv("SHADPS4_IOS_AUDIO_BACKEND", audioBackend == 0 ? "coreaudio" : "sdl", 1);
    setenv("SHADPS4_IOS_SDL_BUFFER_FRAMES", std::to_string((long long)sdlBufferFrames).c_str(), 1);
    setenv("SHADPS4_IOS_GET_MORE_RAM", "1", 1);
    setenv("SHADPS4_IOS_MEMORY_PRESSURE_TRIM", "1", 1);

    NSError* audioError = nil;
    AVAudioSession* session = AVAudioSession.sharedInstance;
    [session setCategory:AVAudioSessionCategoryPlayback
             withOptions:AVAudioSessionCategoryOptionMixWithOthers
                   error:&audioError];
    if (audioError != nil) {
        NSLog(@"shadPS4 iOS audio: failed to set playback session: %@", audioError);
    }
    audioError = nil;
    [session setPreferredIOBufferDuration:(double)sdlBufferFrames / 48000.0 error:&audioError];
    if (audioError != nil) {
        NSLog(@"shadPS4 iOS audio: failed to set IO buffer duration: %@", audioError);
    }
    audioError = nil;
    [session setActive:YES error:&audioError];
    if (audioError != nil) {
        NSLog(@"shadPS4 iOS audio: failed to activate audio session: %@", audioError);
    }

    NSLog(@"shadPS4 iOS core: applied settings %ldx%ld @ %ld FPS, validation=%d, pipelineCache=%d, audio=%s, sdlFrames=%ld",
          (long)width, (long)height, (long)frameLimit, validation, pipelineCache,
          audioBackend == 0 ? "CoreAudio/OpenAL" : "SDL/CoreAudio", (long)sdlBufferFrames);
}

extern "C" void ShadIOSApplyPendingEmulatorSettings(void) {
    ShadIOSApplySettingsToCore();
}

extern "C" void* ShadIOSGetNativeMetalLayer(void) {
    return gShadIOSNativeMetalLayer.load(std::memory_order_acquire);
}

extern "C" float ShadIOSGetNativeRenderScale(void) {
    return gShadIOSNativeRenderScale.load(std::memory_order_acquire);
}

@implementation ShadIOSCoreBridge {
    std::atomic_bool _running;
    std::atomic_int _activeFrameLimit;
    std::mutex _launchMutex;
    std::unique_ptr<std::thread> _emulatorThread;
    MTKView* _metalView;
}

+ (instancetype)sharedBridge {
    static ShadIOSCoreBridge* bridge = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        bridge = [[ShadIOSCoreBridge alloc] init];
    });
    return bridge;
}

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _running = false;
        _activeFrameLimit = 30;
        [self prepareRuntimeEnvironment];
    }
    return self;
}

- (BOOL)isRunning {
    return _running.load();
}

- (BOOL)isDebuggerAttached {
    return ShadIOSProcessIsDebugged();
}

- (BOOL)waitForJITHandshakeWithTimeout:(NSTimeInterval)timeout error:(NSError**)error {
    if (getenv("SHADPS4_IOS_ALLOW_UNDEBUGGED_JIT") != nullptr) {
        NSLog(@"shadPS4 iOS JIT: un-debugged launch override is enabled");
        [NSThread sleepForTimeInterval:ShadIOSJITSettleDelay()];
        return YES;
    }

    ShadIOSSetCrashCheckpoint("waiting for Stik Debugs CS_DEBUGGED handshake");
    const auto deadline = std::chrono::steady_clock::now() +
                          std::chrono::milliseconds((int)lrint(timeout * 1000.0));
    int attempts = 0;
    while (std::chrono::steady_clock::now() < deadline) {
        attempts++;
        if ([self isDebuggerAttached]) {
            setenv("SHADPS4_IOS_JIT_HANDSHAKE", "debugged", 1);
            NSLog(@"shadPS4 iOS JIT: CS_DEBUGGED/P_TRACED detected after %d polls", attempts);
            const NSTimeInterval settleDelay = ShadIOSJITSettleDelay();
            if (settleDelay > 0.0) {
                ShadIOSSetCrashCheckpoint("Stik Debugs JIT settle delay");
                NSLog(@"shadPS4 iOS JIT: waiting %.2fs for VM/JIT ports to settle", settleDelay);
                [NSThread sleepForTimeInterval:settleDelay];
            }
            return YES;
        }
        [NSThread sleepForTimeInterval:0.05];
    }

    if (error != nil) {
        *error = [NSError errorWithDomain:@"ShadIOSCoreBridge"
                                     code:2
                                 userInfo:@{NSLocalizedDescriptionKey :
                                                @"Stik Debugs did not finish attaching within 3 seconds. Attach Stik Debugs first, then start the game again."}];
    }
    NSLog(@"shadPS4 iOS JIT: handshake timeout after %d polls; CS_DEBUGGED/P_TRACED not active",
          attempts);
    return NO;
}

- (NSInteger)activeFrameLimit {
    return _activeFrameLimit.load();
}

- (void)prepareRuntimeEnvironment {
    setenv("SHADPS4_IOS_NATIVE_UI", "1", 1);
    setenv("SHADPS4_IOS_STIKDEBUG_EXPECTED", "1", 1);
    setenv("SHADPS4_IOS_GET_MORE_RAM", "1", 1);
    setenv("SHADPS4_IOS_JIT_SETTLE_DELAY_MS", "1500", 1);
    setenv("MallocNanoZone", "0", 1);
    [self applyUserDefaultsToCore];
}

- (void)attachMetalView:(MTKView*)metalView {
    _metalView = metalView;
    metalView.preferredFramesPerSecond = ShadIOSFrameLimitFromDefaults();
    metalView.framebufferOnly = NO;
    metalView.paused = NO;
    gShadIOSNativeMetalLayer.store((__bridge void*)metalView.layer, std::memory_order_release);
    gShadIOSNativeRenderScale.store((float)UIScreen.mainScreen.scale, std::memory_order_release);
    NSLog(@"shadPS4 iOS core: attached MTKView layer %@ scale %.2f", metalView.layer,
          gShadIOSNativeRenderScale.load());
}

- (void)updateRenderSurfaceDrawableSize:(CGSize)drawableSize {
    const u32 width = (u32)MAX((NSInteger)lrint(drawableSize.width), 1);
    const u32 height = (u32)MAX((NSInteger)lrint(drawableSize.height), 1);
    EmulatorSettings.SetWindowWidth(width);
    EmulatorSettings.SetWindowHeight(height);
    EmulatorSettings.SetInternalScreenWidth(width);
    EmulatorSettings.SetInternalScreenHeight(height);
    MTKView* view = _metalView;
    if (view != nil) {
        view.drawableSize = CGSizeMake(width, height);
        gShadIOSNativeMetalLayer.store((__bridge void*)view.layer, std::memory_order_release);
        const CGFloat screenScale = view.window.screen != nil ? view.window.screen.scale
                                                              : UIScreen.mainScreen.scale;
        gShadIOSNativeRenderScale.store((float)MAX(screenScale, 1.0), std::memory_order_release);
    }
    NSLog(@"shadPS4 iOS core: render surface matched to %ux%u", width, height);
}

- (void)applyUserDefaultsToCore {
    _activeFrameLimit = (int)ShadIOSFrameLimitFromDefaults();
    ShadIOSApplySettingsToCore();
    MTKView* view = _metalView;
    if (view != nil) {
        view.preferredFramesPerSecond = _activeFrameLimit.load();
        const NSInteger height = ShadIOSResolutionHeight();
        const CGFloat scale = UIScreen.mainScreen.scale;
        view.drawableSize = CGSizeMake((height * 16.0 / 9.0) * scale, height * scale);
        gShadIOSNativeMetalLayer.store((__bridge void*)view.layer, std::memory_order_release);
        gShadIOSNativeRenderScale.store((float)MAX(scale, 1.0), std::memory_order_release);
    }
}

- (BOOL)startGameAtPath:(NSString*)gamePath error:(NSError**)error {
    ShadIOSInstallCrashHandlers();
    ShadIOSSetCrashCheckpoint("startGameAtPath entry");
    ShadIOSSetCoreStage(1, "start requested");

#if defined(__aarch64__) || defined(_M_ARM64)
    ShadIOSSetCoreStage(2, "ARM64 custom CPU bridge enabled");
#endif

    if (gamePath.length == 0) {
        if (error != nil) {
            *error = [NSError errorWithDomain:@"ShadIOSCoreBridge"
                                         code:1
                                     userInfo:@{NSLocalizedDescriptionKey : @"Game path is empty."}];
        }
        return NO;
    }

    if (![self waitForJITHandshakeWithTimeout:3.0 error:error]) {
        return NO;
    }

    std::filesystem::path runnable = ShadIOSResolveRunnablePath(gamePath);
    ShadIOSSetCrashCheckpoint("resolved runnable path");
    if (!std::filesystem::exists(runnable)) {
        if (error != nil) {
            NSString* resolved = [NSString stringWithUTF8String:runnable.string().c_str()];
            *error = [NSError errorWithDomain:@"ShadIOSCoreBridge"
                                         code:3
                                     userInfo:@{NSLocalizedDescriptionKey :
                                                    [NSString stringWithFormat:@"Runnable game file not found: %@", resolved]}];
        }
        return NO;
    }

    std::lock_guard lock(_launchMutex);
    if (_running.load()) {
        if (error != nil) {
            *error = [NSError errorWithDomain:@"ShadIOSCoreBridge"
                                         code:4
                                     userInfo:@{NSLocalizedDescriptionKey : @"An emulator session is already running."}];
        }
        return NO;
    }

    [self applyUserDefaultsToCore];
    ShadIOSApplyAggressiveMemorySavingMode();
    ShadIOSClearGraphicsCaches();
    ShadIOSApplySafeGraphicsBootstrap();
    Common::IOSLowMemory::LogLaunchProfile(runnable);
    Common::IOSLowMemory::StartWatchdog();

    _running = true;
    std::string path = runnable.string();
    ShadIOSAppendDiagnosticLog(std::string("resolved runnable: " + path).c_str());
    ShadIOSCoreBridge* bridge = self;
    _emulatorThread.reset(new std::thread([bridge, path]() {
        @autoreleasepool {
            ShadIOSSetCrashCheckpoint("emulator thread launched");
            ShadIOSSetCoreStage(10, "emulator thread launched");
            NSLog(@"shadPS4 iOS core: starting Core::Emulator::Run(%s)", path.c_str());
            ShadIOSAppendDiagnosticLog(std::string("Core::Emulator::Run path: " + path).c_str());
            try {
                ShadIOSSetCrashCheckpoint("Core::Emulator singleton");
                ShadIOSSetCoreStage(20, "Core::Emulator singleton");
                auto* emulator = Common::Singleton<Core::Emulator>::Instance();
                ShadIOSSetCrashCheckpoint("Core::Emulator configured");
                ShadIOSSetCoreStage(30, "Core::Emulator configured");
                emulator->executableName = "shadps4-ios";
                emulator->waitForDebuggerBeforeRun = false;
                ShadIOSSetCrashCheckpoint("pre Core::Emulator::Run JIT delay");
                ShadIOSSetCoreStage(40, "pre Core::Emulator::Run JIT delay");
                [NSThread sleepForTimeInterval:ShadIOSJITSettleDelay()];
                ShadIOSSetCrashCheckpoint("Core::Emulator::Run executing");
                ShadIOSSetCoreStage(50, "Core::Emulator::Run executing");
                emulator->Run(std::filesystem::path(path), {});
                ShadIOSSetCrashCheckpoint("Core::Emulator::Run returned");
                ShadIOSSetCoreStage(800, "Core::Emulator::Run returned");
            } catch (const std::exception& ex) {
                ShadIOSSetCrashCheckpoint("Core::Emulator::Run C++ exception");
                ShadIOSSetCoreStage(901, "Core::Emulator::Run C++ exception");
                ShadIOSAppendDiagnosticLog(
                    std::string("Core::Emulator::Run C++ exception what(): " + std::string(ex.what()))
                        .c_str());
                NSLog(@"shadPS4 iOS core: emulator exited with exception: %s", ex.what());
            } catch (...) {
                ShadIOSSetCrashCheckpoint("Core::Emulator::Run unknown exception");
                ShadIOSSetCoreStage(902, "Core::Emulator::Run unknown exception");
                ShadIOSAppendDiagnosticLog("Core::Emulator::Run unknown non-std exception");
                NSLog(@"shadPS4 iOS core: emulator exited with unknown exception");
            }
            Common::IOSLowMemory::StopWatchdog();
            bridge->_running = false;
        }
    }));
    _emulatorThread->detach();
    return YES;
}

- (void)applyThermalState:(NSProcessInfoThermalState)thermalState {
    if (!ShadIOSBoolForKey(ShadSettingThermalGuardKey, YES)) {
        return;
    }
    NSInteger target = ShadIOSFrameLimitFromDefaults();
    if (thermalState == NSProcessInfoThermalStateSerious) {
        target = MIN(target, 35);
    } else if (thermalState == NSProcessInfoThermalStateCritical) {
        target = 30;
    }
    if (_activeFrameLimit.load() == target) {
        return;
    }
    _activeFrameLimit = (int)target;
    EmulatorSettings.SetVblankFrequency((u32)target);
    setenv("SHADPS4_IOS_FRAME_LIMIT", std::to_string((long long)target).c_str(), 1);
    MTKView* view = _metalView;
    if (view != nil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            view.preferredFramesPerSecond = target;
        });
    }
    NSLog(@"shadPS4 iOS thermal guard: thermalState=%ld, frame limit=%ld",
          (long)thermalState, (long)target);
}

- (Input::GameController*)primaryController {
    return Common::Singleton<Input::GameControllers>::Instance()->operator[](0);
}

- (BOOL)coreInputReady {
    if (!_running.load()) {
        return NO;
    }
    if (Libraries::Kernel::Dev::GetClock() == nullptr) {
        static std::atomic_bool loggedClockWait{false};
        bool expected = false;
        if (loggedClockWait.compare_exchange_strong(expected, true)) {
            NSLog(@"shadPS4 iOS input: core clock is not initialized yet; delaying virtual controller state.");
        }
        return NO;
    }
    return YES;
}

- (void)releaseAllInputs {
    if (![self coreInputReady]) {
        return;
    }
    NSArray<NSString*>* buttons = @[
        @"dpadUp", @"dpadDown", @"dpadLeft", @"dpadRight", @"l1", @"l2", @"r1", @"r2", @"square",
        @"triangle", @"cross", @"circle", @"share", @"options", @"leftStick", @"rightStick"
    ];
    for (NSString* button in buttons) {
        [self setButton:button pressed:NO];
    }
    [self setLeftStickX:0.0f y:0.0f];
    [self setRightStickX:0.0f y:0.0f];
    [self setDpadX:0.0f y:0.0f];
    [self setLeftTrigger:0.0f];
    [self setRightTrigger:0.0f];
}

- (void)setButton:(NSString*)button pressed:(BOOL)pressed {
    if (![self coreInputReady]) {
        return;
    }
    using Libraries::Pad::OrbisPadButtonDataOffset;
    static NSDictionary<NSString*, NSNumber*>* table = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        table = [@{
            @"dpadUp" : @((u32)OrbisPadButtonDataOffset::Up),
            @"dpadDown" : @((u32)OrbisPadButtonDataOffset::Down),
            @"dpadLeft" : @((u32)OrbisPadButtonDataOffset::Left),
            @"dpadRight" : @((u32)OrbisPadButtonDataOffset::Right),
            @"l1" : @((u32)OrbisPadButtonDataOffset::L1),
            @"l2" : @((u32)OrbisPadButtonDataOffset::L2),
            @"r1" : @((u32)OrbisPadButtonDataOffset::R1),
            @"r2" : @((u32)OrbisPadButtonDataOffset::R2),
            @"square" : @((u32)OrbisPadButtonDataOffset::Square),
            @"triangle" : @((u32)OrbisPadButtonDataOffset::Triangle),
            @"cross" : @((u32)OrbisPadButtonDataOffset::Cross),
            @"circle" : @((u32)OrbisPadButtonDataOffset::Circle),
            @"share" : @((u32)OrbisPadButtonDataOffset::TouchPad),
            @"options" : @((u32)OrbisPadButtonDataOffset::Options),
            @"leftStick" : @((u32)OrbisPadButtonDataOffset::L3),
            @"rightStick" : @((u32)OrbisPadButtonDataOffset::R3),
        } retain];
    });
    NSNumber* raw = table[button];
    if (raw == nil) {
        return;
    }
    [self primaryController]->Button((OrbisPadButtonDataOffset)raw.unsignedIntValue, pressed);
}

- (void)setLeftStickX:(float)x y:(float)y {
    if (![self coreInputReady]) {
        return;
    }
    Input::GameController* controller = [self primaryController];
    controller->Axis(Input::Axis::LeftX, Input::GetAxis(-128, 127, (int)lrintf(x * 127.0f)), false);
    controller->Axis(Input::Axis::LeftY, Input::GetAxis(-128, 127, (int)lrintf(-y * 127.0f)), false);
}

- (void)setRightStickX:(float)x y:(float)y {
    if (![self coreInputReady]) {
        return;
    }
    Input::GameController* controller = [self primaryController];
    controller->Axis(Input::Axis::RightX, Input::GetAxis(-128, 127, (int)lrintf(x * 127.0f)), false);
    controller->Axis(Input::Axis::RightY, Input::GetAxis(-128, 127, (int)lrintf(-y * 127.0f)), false);
}

- (void)setDpadX:(float)x y:(float)y {
    [self setButton:@"dpadLeft" pressed:x < -0.35f];
    [self setButton:@"dpadRight" pressed:x > 0.35f];
    [self setButton:@"dpadUp" pressed:y > 0.35f];
    [self setButton:@"dpadDown" pressed:y < -0.35f];
}

- (void)setLeftTrigger:(float)value {
    if (![self coreInputReady]) {
        return;
    }
    [self primaryController]->Axis(Input::Axis::TriggerLeft, MIN(MAX((int)lrintf(value * 255.0f), 0), 255), false);
}

- (void)setRightTrigger:(float)value {
    if (![self coreInputReady]) {
        return;
    }
    [self primaryController]->Axis(Input::Axis::TriggerRight, MIN(MAX((int)lrintf(value * 255.0f), 0), 255), false);
}

@end
