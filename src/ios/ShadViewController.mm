#import "ShadViewController.h"

#import "OrbitIconRenderer.h"
#import "ShadIOSCoreBridge.h"

#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <GameController/GameController.h>
#import <PhotosUI/PhotosUI.h>
#import <QuartzCore/QuartzCore.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#include <math.h>
#include <mach/mach.h>
#include <objc/message.h>
#include <string.h>
#include <sys/sysctl.h>

static NSString* const ShadGameLibraryDefaultsKey = @"ShadIOSGameLibrary";
static NSString* const ShadDashboardBackgroundDefaultsKey = @"ShadIOSDashboardBackground";
static NSString* const ShadDashboardBackgroundModeDefaultsKey = @"ShadIOSDashboardBackgroundMode";
static NSString* const ShadDashboardDynamicStyleDefaultsKey = @"ShadIOSDashboardDynamicStyle";
static NSString* const ShadDashboardBackgroundChangedNotification = @"ShadDashboardBackgroundChanged";
static NSString* const ShadVirtualControllerLayoutDefaultsKey = @"ShadIOSVirtualControllerLayout";
static NSString* const ShadFirstLaunchCompleteDefaultsKey = @"ShadIOSFirstLaunchComplete";
static NSString* const ShadUserProfilesDefaultsKey = @"ShadIOSUserProfiles";
static NSString* const ShadCurrentUserIDDefaultsKey = @"ShadIOSCurrentUserID";
static NSString* const ShadProfileChangedNotification = @"ShadIOSProfileChanged";
static NSString* const ShadControllerMappingDefaultsKey = @"ShadIOSControllerMapping";
static NSString* const ShadCompatibilityBaseURL =
    @"https://api.github.com/search/issues?q=repo:shadps4-compatibility/shadps4-game-compatibility%20is:issue%20";
static NSString* const ShadFrameLimitDefaultsKey = @"ShadIOSFrameLimit";
static NSString* const ShadFrameLimitChangedNotification = @"ShadFrameLimitChanged";
static NSString* const ShadPlayUISoundNotification = @"ShadPlayUISound";
static NSString* const ShadRuntimeOverlaySettingsChangedNotification = @"ShadRuntimeOverlaySettingsChanged";
static NSString* const ShadSettingEnableLogKey = @"ShadIOSSettingEnableLog";
static NSString* const ShadSettingFirmwareKey = @"ShadIOSSettingFirmware";
static NSString* const ShadSettingInternalResolutionKey = @"ShadIOSSettingInternalResolution";
static NSString* const ShadSettingVSyncKey = @"ShadIOSSettingVSync";
static NSString* const ShadSettingFrameGenerationKey = @"ShadIOSSettingFrameGeneration";
static NSString* const ShadSettingAspectModeKey = @"ShadIOSSettingAspectMode";
static NSString* const ShadSettingMenuThrottleKey = @"ShadIOSSettingMenuThrottle";
static NSString* const ShadSettingThermalGuardKey = @"ShadIOSSettingThermalGuard";
static NSString* const ShadSettingMoltenVKValidationKey = @"ShadIOSSettingMoltenVKValidation";
static NSString* const ShadSettingMoltenVKFastMathKey = @"ShadIOSSettingMoltenVKFastMath";
static NSString* const ShadSettingMoltenVKSyncModeKey = @"ShadIOSSettingMoltenVKSyncMode";
static NSString* const ShadSettingMoltenVKPresentModeKey = @"ShadIOSSettingMoltenVKPresentMode";
static NSString* const ShadSettingMetalFXEnabledKey = @"ShadIOSSettingMetalFXEnabled";
static NSString* const ShadSettingMetalFXModeKey = @"ShadIOSSettingMetalFXMode";
static NSString* const ShadSettingMetalFXSharpnessKey = @"ShadIOSSettingMetalFXSharpness";
static NSString* const ShadSettingRuntimeStatsOverlayKey = @"ShadIOSSettingRuntimeStatsOverlay";
static NSString* const ShadSettingRuntimeStatsFPSKey = @"ShadIOSSettingRuntimeStatsFPS";
static NSString* const ShadSettingRuntimeStatsCPUKey = @"ShadIOSSettingRuntimeStatsCPU";
static NSString* const ShadSettingRuntimeStatsGPUKey = @"ShadIOSSettingRuntimeStatsGPU";
static NSString* const ShadSettingRuntimeStatsRAMKey = @"ShadIOSSettingRuntimeStatsRAM";
static NSString* const ShadSettingRuntimeStatsOpacityKey = @"ShadIOSSettingRuntimeStatsOpacity";
static NSString* const ShadSettingRuntimeStatsPositionKey = @"ShadIOSSettingRuntimeStatsPosition";
static NSString* const ShadSettingMasterVolumeKey = @"ShadIOSSettingMasterVolume";
static NSString* const ShadSettingAudioDriverBackendKey = @"ShadIOSSettingAudioDriverBackend";
static NSString* const ShadSettingSDLBufferModeKey = @"ShadIOSSettingSDLBufferMode";
static NSString* const ShadSettingUISoundEffectsKey = @"ShadIOSSettingUISoundEffects";
static NSString* const ShadSettingConsoleSoundThemeKey = @"ShadIOSSettingConsoleSoundTheme";
static NSString* const ShadSettingClickVolumeKey = @"ShadIOSSettingClickVolume";
static NSString* const ShadSettingAudioOutputKey = @"ShadIOSSettingAudioOutput";
static NSString* const ShadSettingTouchOverlayStartupKey = @"ShadIOSSettingTouchOverlayStartup";
static NSString* const ShadSettingTouchOverlayOpacityKey = @"ShadIOSSettingTouchOverlayOpacity";
static NSString* const ShadSettingBluetoothControllerKey = @"ShadIOSSettingBluetoothController";
static NSString* const ShadSettingControllerRumbleKey = @"ShadIOSSettingControllerRumble";
static NSString* const ShadSettingMenuNavigationKey = @"ShadIOSSettingMenuNavigation";
static NSString* const ShadSettingAnimationEffectKey = @"ShadIOSSettingAnimationEffect";
static NSString* const ShadSettingAnimationIntensityKey = @"ShadIOSSettingAnimationIntensity";
static NSString* const ShadSettingShaderCacheEnabledKey = @"ShadIOSDebugShaderCacheEnabled";
static NSString* const ShadSettingPipelineCacheEnabledKey = @"ShadIOSDebugPipelineCacheEnabled";
static NSString* const ShadSettingShaderPrecompileKey = @"ShadIOSDebugShaderPrecompile";
static NSString* const ShadSettingShaderMissLoggingKey = @"ShadIOSDebugShaderMissLogging";
static NSString* const ShadSettingShaderDumpKey = @"ShadIOSDebugShaderDump";

extern "C" uint64_t ShadIOSGetPresenterGameFrameCount(void);
extern "C" uint64_t ShadIOSGetPresenterBlankFrameCount(void);
extern "C" uint64_t ShadIOSGetPresenterPresentCount(void);
extern "C" int ShadIOSGetCoreStage(void);
extern "C" const char* ShadIOSGetCoreStageDescription(void);

static NSInteger ShadClampedFrameLimit(NSInteger fps) {
    if (fps <= 0) {
        return 30;
    }
    return MIN(MAX(fps, 30), 40);
}

static void ShadPostUISound(NSString* kind) {
    [[NSNotificationCenter defaultCenter] postNotificationName:ShadPlayUISoundNotification
                                                        object:nil
                                                      userInfo:@{ @"kind" : kind ?: @"move" }];
}

static NSMutableArray<NSMutableDictionary*>* ShadMutableProfiles(void) {
    NSArray* stored = [[NSUserDefaults standardUserDefaults] arrayForKey:ShadUserProfilesDefaultsKey];
    NSMutableArray* profiles = [NSMutableArray array];
    for (NSDictionary* profile in stored) {
        if ([profile isKindOfClass:NSDictionary.class]) {
            [profiles addObject:[[profile mutableCopy] autorelease]];
        }
    }
    return profiles;
}

static void ShadSaveProfiles(NSArray* profiles) {
    [[NSUserDefaults standardUserDefaults] setObject:profiles ?: @[] forKey:ShadUserProfilesDefaultsKey];
}

static NSString* ShadCurrentUserID(void) {
    return [[NSUserDefaults standardUserDefaults] stringForKey:ShadCurrentUserIDDefaultsKey];
}

static NSMutableDictionary* ShadCurrentProfile(void) {
    NSString* currentID = ShadCurrentUserID();
    for (NSMutableDictionary* profile in ShadMutableProfiles()) {
        if ([profile[@"id"] isEqualToString:currentID]) {
            return profile;
        }
    }
    return nil;
}

static UIColor* ShadProfileColor(NSString* identifier) {
    NSUInteger hash = identifier.hash;
    NSArray<UIColor*>* colors = @[
        [UIColor colorWithRed:0.12 green:0.54 blue:1.00 alpha:1.0],
        [UIColor colorWithRed:0.60 green:0.32 blue:0.92 alpha:1.0],
        [UIColor colorWithRed:0.12 green:0.74 blue:0.54 alpha:1.0],
        [UIColor colorWithRed:0.95 green:0.46 blue:0.18 alpha:1.0],
    ];
    return colors[hash % colors.count];
}

static GCControllerButtonInput* ShadOptionalButtonInput(id gamepad, SEL selector) {
    if (gamepad == nil || ![gamepad respondsToSelector:selector]) {
        return nil;
    }
    return ((GCControllerButtonInput* (*)(id, SEL))objc_msgSend)(gamepad, selector);
}

static void ShadAppendLE16(NSMutableData* data, uint16_t value) {
    uint16_t little = CFSwapInt16HostToLittle(value);
    [data appendBytes:&little length:sizeof(little)];
}

static void ShadAppendLE32(NSMutableData* data, uint32_t value) {
    uint32_t little = CFSwapInt32HostToLittle(value);
    [data appendBytes:&little length:sizeof(little)];
}

struct ShadVirtualPadState {
    bool dpad;
    bool l1;
    bool l2;
    bool r1;
    bool r2;
    bool square;
    bool triangle;
    bool cross;
    bool circle;
    bool share;
    bool options;
    bool leftStick;
    bool rightStick;
};

@interface ShadDashboardWavesView : UIView
@property(nonatomic, assign) CGFloat phase;
@property(nonatomic, assign) CGFloat amplitudeScale;
@property(nonatomic, assign) CGFloat speed;
- (void)startAnimating;
- (void)stopAnimating;
@end

@implementation ShadDashboardWavesView {
    CADisplayLink* _displayLink;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        self.backgroundColor = UIColor.clearColor;
        self.userInteractionEnabled = NO;
        self.contentMode = UIViewContentModeRedraw;
        self.amplitudeScale = 1.0;
        self.speed = 1.0;
    }
    return self;
}

- (void)dealloc {
    [_displayLink invalidate];
    [super dealloc];
}

- (void)startAnimating {
    if (_displayLink != nil) {
        return;
    }
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(stepWaves:)];
    _displayLink.preferredFramesPerSecond = 30;
    [_displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}

- (void)stopAnimating {
    [_displayLink invalidate];
    _displayLink = nil;
}

- (void)stepWaves:(CADisplayLink*)link {
    self.phase += (CGFloat)link.duration * self.speed;
    if (self.phase > M_PI * 2.0) {
        self.phase -= (CGFloat)(M_PI * 2.0);
    }
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (context == nil) {
        return;
    }

    const CGFloat width = CGRectGetWidth(rect);
    const CGFloat midY = CGRectGetHeight(rect) * 0.55;
    const CGFloat safeWidth = MAX(width, 1.0);
    NSArray<UIColor*>* colors = @[
        [UIColor colorWithWhite:1.0 alpha:0.14],
        [UIColor colorWithRed:0.54 green:0.86 blue:1.0 alpha:0.12],
        [UIColor colorWithWhite:1.0 alpha:0.08],
    ];

    for (NSUInteger wave = 0; wave < colors.count; wave++) {
        UIBezierPath* path = [UIBezierPath bezierPath];
        const CGFloat amplitude = (28.0 + (CGFloat)wave * 18.0) * MAX(self.amplitudeScale, 0.15);
        const CGFloat baseline = midY + (CGFloat)wave * 64.0;
        for (CGFloat x = -20.0; x <= width + 20.0; x += 12.0) {
            CGFloat y = baseline + sin((x / safeWidth) * M_PI * (1.65 + (CGFloat)wave * 0.18) +
                                       (CGFloat)wave * 0.92 + self.phase * (0.65 + (CGFloat)wave * 0.16)) *
                                     amplitude;
            if (x <= -20.0) {
                [path moveToPoint:CGPointMake(x, y)];
            } else {
                [path addLineToPoint:CGPointMake(x, y)];
            }
        }
        path.lineWidth = 1.4;
        [colors[wave] setStroke];
        [path stroke];
    }
}

@end

@interface ShadSettingsViewController : UIViewController <PHPickerViewControllerDelegate>

@property(nonatomic, strong) UIStackView* settingsStack;
@property(nonatomic, strong) NSMutableArray<UIButton*>* categoryButtons;
@property(nonatomic, strong) NSMutableArray<UIControl*>* settingsFocusableControls;
@property(nonatomic, strong) NSMutableDictionary<NSString*, UILabel*>* valueLabels;
@property(nonatomic, strong) UIVisualEffectView* sidebarView;
@property(nonatomic, strong) UIVisualEffectView* detailsView;
@property(nonatomic, strong) UIScrollView* settingsScrollView;
@property(nonatomic, strong) CADisplayLink* settingsControllerPollLink;
@property(nonatomic, assign) NSInteger selectedCategory;
@property(nonatomic, assign) NSInteger selectedSettingsIndex;
@property(nonatomic, assign) CFTimeInterval lastSettingsControllerMoveTime;
@property(nonatomic, assign) BOOL settingsControllerAWasPressed;
@property(nonatomic, assign) BOOL settingsControllerBWasPressed;

@end

@interface ShadTrophiesViewController : UIViewController
- (instancetype)initWithGame:(NSDictionary*)game;
@end

@interface ShadOnboardingViewController : UIViewController
@end

@interface ShadControllerTestViewController : UIViewController
@end

@interface ShadUserSelectionViewController : UIViewController
@end

@interface ShadProfileViewController : UIViewController <PHPickerViewControllerDelegate>
@end

@implementation ShadTrophiesViewController {
    NSDictionary* _game;
}

- (instancetype)initWithGame:(NSDictionary*)game {
    self = [super initWithNibName:nil bundle:nil];
    if (self != nil) {
        _game = [game copy] ?: @{};
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.00 green:0.09 blue:0.32 alpha:0.92];

    UIVisualEffectView* sidebar =
        [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark]];
    sidebar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:sidebar];

    UILabel* title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"Trophies";
    title.textColor = UIColor.whiteColor;
    title.font = [UIFont systemFontOfSize:38.0 weight:UIFontWeightLight];
    [sidebar.contentView addSubview:title];

    UIButton* close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.translatesAutoresizingMaskIntoConstraints = NO;
    close.tintColor = UIColor.whiteColor;
    [close setTitle:@"○ Back" forState:UIControlStateNormal];
    close.titleLabel.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
    [close addTarget:self action:@selector(closePressed) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:close];

    UIVisualEffectView* panel =
        [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark]];
    panel.translatesAutoresizingMaskIntoConstraints = NO;
    panel.layer.cornerRadius = 6.0;
    panel.clipsToBounds = YES;
    [self.view addSubview:panel];

    UIStackView* stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 18.0;
    [panel.contentView addSubview:stack];

    NSString* gameTitle = _game[@"title"] ?: @"No Game Selected";
    NSArray<NSString*>* rows = @[
        [NSString stringWithFormat:@"%@  -  Progress 57%%", gameTitle],
        @"Platinum 0    Gold 1    Silver 9    Bronze 40",
        @"Most Recent Trophy    Here Kitty-Kitty",
        @"Top Trophy Earned     Disorganised Crime",
        @"Compatibility data is shown on the dashboard game detail panel.",
    ];
    [rows enumerateObjectsUsingBlock:^(NSString* rowText, NSUInteger idx, BOOL* stop) {
        UILabel* row = [[UILabel alloc] init];
        row.text = rowText;
        row.textColor = [UIColor colorWithWhite:1.0 alpha:0.86];
        row.font = [UIFont systemFontOfSize:idx == 0 ? 22.0 : 17.0
                                     weight:UIFontWeightRegular];
        row.numberOfLines = 0;
        [stack addArrangedSubview:row];
    }];

    UILayoutGuide* safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [sidebar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [sidebar.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [sidebar.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [sidebar.widthAnchor constraintEqualToConstant:330.0],

        [title.leadingAnchor constraintEqualToAnchor:sidebar.contentView.leadingAnchor constant:48.0],
        [title.topAnchor constraintEqualToAnchor:safe.topAnchor constant:72.0],

        [panel.leadingAnchor constraintEqualToAnchor:sidebar.trailingAnchor constant:38.0],
        [panel.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-64.0],
        [panel.topAnchor constraintEqualToAnchor:safe.topAnchor constant:82.0],
        [panel.heightAnchor constraintGreaterThanOrEqualToConstant:260.0],

        [stack.leadingAnchor constraintEqualToAnchor:panel.contentView.leadingAnchor constant:44.0],
        [stack.trailingAnchor constraintEqualToAnchor:panel.contentView.trailingAnchor constant:-44.0],
        [stack.topAnchor constraintEqualToAnchor:panel.contentView.topAnchor constant:36.0],
        [stack.bottomAnchor constraintLessThanOrEqualToAnchor:panel.contentView.bottomAnchor constant:-36.0],

        [close.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-42.0],
        [close.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-28.0],
    ]];
}

- (void)closePressed {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

@implementation ShadOnboardingViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.00 green:0.08 blue:0.30 alpha:1.0];

    CAGradientLayer* gradient = [CAGradientLayer layer];
    gradient.frame = self.view.bounds;
    gradient.colors = @[
        (__bridge id)[UIColor colorWithRed:0.00 green:0.08 blue:0.30 alpha:1.0].CGColor,
        (__bridge id)[UIColor colorWithRed:0.00 green:0.27 blue:0.84 alpha:1.0].CGColor,
    ];
    gradient.startPoint = CGPointMake(0.0, 0.0);
    gradient.endPoint = CGPointMake(1.0, 1.0);
    [self.view.layer insertSublayer:gradient atIndex:0];

    UIVisualEffectView* panel =
        [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark]];
    panel.translatesAutoresizingMaskIntoConstraints = NO;
    panel.layer.cornerRadius = 8.0;
    panel.clipsToBounds = YES;
    [self.view addSubview:panel];

    UIStackView* stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 18.0;
    [panel.contentView addSubview:stack];

    UILabel* title = [[UILabel alloc] init];
    title.text = @"Welcome to Orbit Console";
    title.textColor = UIColor.whiteColor;
    title.font = [UIFont systemFontOfSize:34.0 weight:UIFontWeightLight];
    [stack addArrangedSubview:title];

    NSArray<NSString*>* tips = @[
        @"Add your own games with the + tile.",
        @"Use Orbit Console Settings > Input Controls to test controllers before launching.",
        @"Frame limit is capped at 30-40 FPS to protect thermals.",
        @"Touch controls and runtime stats only appear after starting a game.",
    ];
    for (NSString* tip in tips) {
        UILabel* label = [[UILabel alloc] init];
        label.text = [NSString stringWithFormat:@"• %@", tip];
        label.textColor = [UIColor colorWithWhite:1.0 alpha:0.78];
        label.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightRegular];
        label.numberOfLines = 0;
        [stack addArrangedSubview:label];
    }

    UISegmentedControl* fps = [[UISegmentedControl alloc] initWithItems:@[ @"30 FPS", @"35 FPS", @"40 FPS" ]];
    fps.selectedSegmentIndex = 0;
    fps.accessibilityIdentifier = ShadFrameLimitDefaultsKey;
    [fps addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
    [stack addArrangedSubview:fps];

    UISwitch* sounds = [[UISwitch alloc] init];
    sounds.on = YES;
    sounds.accessibilityIdentifier = ShadSettingUISoundEffectsKey;
    [sounds addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    [stack addArrangedSubview:[self onboardingSwitchRow:@"UI sound effects" control:sounds]];

    UISwitch* touch = [[UISwitch alloc] init];
    touch.on = YES;
    touch.accessibilityIdentifier = ShadSettingTouchOverlayStartupKey;
    [touch addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    [stack addArrangedSubview:[self onboardingSwitchRow:@"Show touch controls when game starts" control:touch]];

    UIButton* done = [UIButton buttonWithType:UIButtonTypeSystem];
    done.tintColor = UIColor.whiteColor;
    done.backgroundColor = [UIColor colorWithRed:0.05 green:0.34 blue:0.86 alpha:0.86];
    done.layer.cornerRadius = 6.0;
    [done setTitle:@"Start" forState:UIControlStateNormal];
    done.titleLabel.font = [UIFont systemFontOfSize:19.0 weight:UIFontWeightSemibold];
    [done.heightAnchor constraintEqualToConstant:48.0].active = YES;
    [done addTarget:self action:@selector(donePressed) forControlEvents:UIControlEventTouchUpInside];
    [stack addArrangedSubview:done];

    [NSLayoutConstraint activateConstraints:@[
        [panel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [panel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [panel.widthAnchor constraintEqualToConstant:560.0],
        [stack.leadingAnchor constraintEqualToAnchor:panel.contentView.leadingAnchor constant:34.0],
        [stack.trailingAnchor constraintEqualToAnchor:panel.contentView.trailingAnchor constant:-34.0],
        [stack.topAnchor constraintEqualToAnchor:panel.contentView.topAnchor constant:30.0],
        [stack.bottomAnchor constraintEqualToAnchor:panel.contentView.bottomAnchor constant:-30.0],
    ]];
}

- (UIView*)onboardingSwitchRow:(NSString*)title control:(UISwitch*)control {
    UIStackView* row = [[UIStackView alloc] init];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentCenter;
    row.spacing = 16.0;
    UILabel* label = [[UILabel alloc] init];
    label.text = title;
    label.textColor = [UIColor colorWithWhite:1.0 alpha:0.82];
    label.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightRegular];
    [row addArrangedSubview:label];
    [row addArrangedSubview:control];
    return row;
}

- (void)segmentChanged:(UISegmentedControl*)sender {
    NSArray<NSNumber*>* fpsValues = @[ @30, @35, @40 ];
    [[NSUserDefaults standardUserDefaults] setInteger:fpsValues[(NSUInteger)sender.selectedSegmentIndex].integerValue
                                              forKey:ShadFrameLimitDefaultsKey];
}

- (void)switchChanged:(UISwitch*)sender {
    if ([sender.accessibilityIdentifier isEqualToString:ShadSettingTouchOverlayStartupKey]) {
        [[NSUserDefaults standardUserDefaults] setInteger:(sender.on ? 1 : 0) forKey:sender.accessibilityIdentifier];
    } else {
        [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:sender.accessibilityIdentifier];
    }
}

- (void)donePressed {
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:ShadFirstLaunchCompleteDefaultsKey];
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

@interface ShadControllerPreviewView : UIView
@property(nonatomic, copy) NSString* controllerStyle;
@property(nonatomic, copy) NSSet<NSString*>* pressedButtons;
@end

@implementation ShadControllerPreviewView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        self.backgroundColor = UIColor.clearColor;
        self.controllerStyle = @"generic";
        self.pressedButtons = [NSSet set];
        self.contentMode = UIViewContentModeRedraw;
    }
    return self;
}

- (void)dealloc {
    self.controllerStyle = nil;
    self.pressedButtons = nil;
    [super dealloc];
}

- (BOOL)isPlayStationStyle {
    NSString* style = self.controllerStyle.lowercaseString ?: @"";
    return [style containsString:@"playstation"] || [style containsString:@"dualshock"] || [style containsString:@"dualsense"] ||
           [style containsString:@"ps4"] || [style containsString:@"ps5"];
}

- (void)drawCircle:(CGRect)rect label:(NSString*)label active:(BOOL)active context:(CGContextRef)context {
    UIColor* fill = active ? [UIColor colorWithRed:0.14 green:0.55 blue:1.0 alpha:0.96]
                           : [UIColor colorWithWhite:1.0 alpha:0.14];
    UIColor* stroke = active ? UIColor.whiteColor : [UIColor colorWithWhite:1.0 alpha:0.36];
    CGContextSetFillColorWithColor(context, fill.CGColor);
    CGContextFillEllipseInRect(context, rect);
    CGContextSetStrokeColorWithColor(context, stroke.CGColor);
    CGContextSetLineWidth(context, active ? 2.2 : 1.2);
    CGContextStrokeEllipseInRect(context, rect);
    NSMutableParagraphStyle* paragraph = [[[NSMutableParagraphStyle alloc] init] autorelease];
    paragraph.alignment = NSTextAlignmentCenter;
    NSDictionary* attrs = @{
        NSFontAttributeName : [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold],
        NSForegroundColorAttributeName : UIColor.whiteColor,
        NSParagraphStyleAttributeName : paragraph,
    };
    CGSize size = [label sizeWithAttributes:attrs];
    CGRect textRect = CGRectMake(CGRectGetMidX(rect) - size.width / 2.0,
                                 CGRectGetMidY(rect) - size.height / 2.0,
                                 size.width,
                                 size.height);
    [label drawInRect:textRect withAttributes:attrs];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (context == nil) {
        return;
    }
    CGRect body = CGRectInset(rect, 18.0, 22.0);
    UIBezierPath* shell = [UIBezierPath bezierPathWithRoundedRect:body cornerRadius:42.0];
    [[UIColor colorWithWhite:1.0 alpha:0.10] setFill];
    [shell fill];
    [[UIColor colorWithWhite:1.0 alpha:0.28] setStroke];
    shell.lineWidth = 1.2;
    [shell stroke];

    BOOL ps = [self isPlayStationStyle];
    CGFloat w = CGRectGetWidth(body);
    CGFloat h = CGRectGetHeight(body);
    CGPoint leftStick = CGPointMake(CGRectGetMinX(body) + w * (ps ? 0.36 : 0.30), CGRectGetMinY(body) + h * (ps ? 0.62 : 0.45));
    CGPoint rightStick = CGPointMake(CGRectGetMinX(body) + w * (ps ? 0.64 : 0.58), CGRectGetMinY(body) + h * (ps ? 0.62 : 0.66));
    CGRect leftStickRect = CGRectMake(leftStick.x - 24.0, leftStick.y - 24.0, 48.0, 48.0);
    CGRect rightStickRect = CGRectMake(rightStick.x - 24.0, rightStick.y - 24.0, 48.0, 48.0);
    [self drawCircle:leftStickRect label:@"L" active:[self.pressedButtons containsObject:@"Left Stick"] context:context];
    [self drawCircle:rightStickRect label:@"R" active:NO context:context];

    CGRect dpad = CGRectMake(CGRectGetMinX(body) + w * 0.18 - 28.0, CGRectGetMinY(body) + h * 0.62 - 28.0, 56.0, 56.0);
    [[UIColor colorWithWhite:1.0 alpha:[self.pressedButtons containsObject:@"D-Pad"] ? 0.32 : 0.16] setFill];
    UIRectFill(CGRectMake(CGRectGetMidX(dpad) - 9.0, CGRectGetMinY(dpad), 18.0, 56.0));
    UIRectFill(CGRectMake(CGRectGetMinX(dpad), CGRectGetMidY(dpad) - 9.0, 56.0, 18.0));

    NSArray<NSString*>* face = ps ? @[ @"△", @"○", @"×", @"□" ] : @[ @"Y", @"B", @"A", @"X" ];
    NSArray<NSString*>* keys = @[ @"Y / Triangle", @"B / Circle", @"A / Cross", @"X / Square" ];
    CGPoint faceCenter = CGPointMake(CGRectGetMinX(body) + w * 0.80, CGRectGetMinY(body) + h * 0.50);
    NSArray<NSValue*>* offsets = @[
        [NSValue valueWithCGPoint:CGPointMake(0.0, -32.0)],
        [NSValue valueWithCGPoint:CGPointMake(32.0, 0.0)],
        [NSValue valueWithCGPoint:CGPointMake(0.0, 32.0)],
        [NSValue valueWithCGPoint:CGPointMake(-32.0, 0.0)],
    ];
    for (NSUInteger i = 0; i < face.count; i++) {
        CGPoint o = offsets[i].CGPointValue;
        CGRect r = CGRectMake(faceCenter.x + o.x - 18.0, faceCenter.y + o.y - 18.0, 36.0, 36.0);
        [self drawCircle:r label:face[i] active:[self.pressedButtons containsObject:keys[i]] context:context];
    }

    [self drawCircle:CGRectMake(CGRectGetMinX(body) + w * 0.38 - 17.0, CGRectGetMinY(body) + 18.0, 34.0, 22.0)
               label:@"L1"
              active:[self.pressedButtons containsObject:@"L1"]
             context:context];
    [self drawCircle:CGRectMake(CGRectGetMinX(body) + w * 0.62 - 17.0, CGRectGetMinY(body) + 18.0, 34.0, 22.0)
               label:@"R1"
              active:[self.pressedButtons containsObject:@"R1"]
             context:context];
    [self drawCircle:CGRectMake(CGRectGetMidX(body) - 48.0, CGRectGetMidY(body) - 13.0, 38.0, 26.0)
               label:ps ? @"SH" : @"View"
              active:NO
             context:context];
    [self drawCircle:CGRectMake(CGRectGetMidX(body) + 10.0, CGRectGetMidY(body) - 13.0, 38.0, 26.0)
               label:ps ? @"OP" : @"Menu"
              active:[self.pressedButtons containsObject:@"Options"]
             context:context];
}

@end

@implementation ShadControllerTestViewController {
    UILabel* _nameLabel;
    UILabel* _stateLabel;
    UILabel* _controllerKindLabel;
    ShadControllerPreviewView* _controllerPreview;
    NSMutableDictionary<NSString*, UILabel*>* _buttonLabels;
    NSMutableDictionary<NSString*, UISegmentedControl*>* _mappingControls;
    CADisplayLink* _link;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.00 green:0.08 blue:0.30 alpha:0.96];
    _buttonLabels = [NSMutableDictionary dictionary];
    _mappingControls = [NSMutableDictionary dictionary];

    UILabel* title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"Controller Test";
    title.textColor = UIColor.whiteColor;
    title.font = [UIFont systemFontOfSize:38.0 weight:UIFontWeightLight];
    [self.view addSubview:title];

    _nameLabel = [[UILabel alloc] init];
    _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _nameLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.82];
    _nameLabel.font = [UIFont systemFontOfSize:18.0 weight:UIFontWeightMedium];
    [self.view addSubview:_nameLabel];

    UIVisualEffectView* panel =
        [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark]];
    panel.translatesAutoresizingMaskIntoConstraints = NO;
    panel.layer.cornerRadius = 8.0;
    panel.clipsToBounds = YES;
    [self.view addSubview:panel];

    UIStackView* grid = [[UIStackView alloc] init];
    grid.translatesAutoresizingMaskIntoConstraints = NO;
    grid.axis = UILayoutConstraintAxisVertical;
    grid.spacing = 12.0;
    [panel.contentView addSubview:grid];

    _controllerKindLabel = [[UILabel alloc] init];
    _controllerKindLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _controllerKindLabel.text = @"Controller Layout";
    _controllerKindLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.78];
    _controllerKindLabel.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
    [panel.contentView addSubview:_controllerKindLabel];

    _controllerPreview = [[ShadControllerPreviewView alloc] init];
    _controllerPreview.translatesAutoresizingMaskIntoConstraints = NO;
    [panel.contentView addSubview:_controllerPreview];

    NSArray<NSArray<NSString*>*>* rows = @[
        @[ @"A / Cross", @"B / Circle", @"X / Square", @"Y / Triangle" ],
        @[ @"L1", @"R1", @"L2", @"R2" ],
        @[ @"Menu", @"Options", @"D-Pad", @"Left Stick" ],
    ];
    for (NSArray<NSString*>* rowItems in rows) {
        UIStackView* row = [[UIStackView alloc] init];
        row.axis = UILayoutConstraintAxisHorizontal;
        row.distribution = UIStackViewDistributionFillEqually;
        row.spacing = 12.0;
        for (NSString* item in rowItems) {
            UILabel* label = [[UILabel alloc] init];
            label.text = item;
            label.textAlignment = NSTextAlignmentCenter;
            label.textColor = [UIColor colorWithWhite:1.0 alpha:0.62];
            label.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold];
            label.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
            label.layer.cornerRadius = 6.0;
            label.clipsToBounds = YES;
            [label.heightAnchor constraintEqualToConstant:50.0].active = YES;
            _buttonLabels[item] = label;
            [row addArrangedSubview:label];
        }
        [grid addArrangedSubview:row];
    }

    _stateLabel = [[UILabel alloc] init];
    _stateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _stateLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.72];
    _stateLabel.font = [UIFont monospacedSystemFontOfSize:15.0 weight:UIFontWeightRegular];
    _stateLabel.numberOfLines = 0;
    [self.view addSubview:_stateLabel];

    UIVisualEffectView* mappingPanel =
        [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark]];
    mappingPanel.translatesAutoresizingMaskIntoConstraints = NO;
    mappingPanel.layer.cornerRadius = 8.0;
    mappingPanel.clipsToBounds = YES;
    [self.view addSubview:mappingPanel];

    UIStackView* mappingStack = [[UIStackView alloc] init];
    mappingStack.translatesAutoresizingMaskIntoConstraints = NO;
    mappingStack.axis = UILayoutConstraintAxisVertical;
    mappingStack.spacing = 10.0;
    [mappingPanel.contentView addSubview:mappingStack];

    UILabel* mappingTitle = [[UILabel alloc] init];
    mappingTitle.text = @"Button Mapping";
    mappingTitle.textColor = UIColor.whiteColor;
    mappingTitle.font = [UIFont systemFontOfSize:22.0 weight:UIFontWeightSemibold];
    [mappingStack addArrangedSubview:mappingTitle];
    [mappingStack addArrangedSubview:[self mappingRowForPhysical:@"A" defaultTarget:@"Cross"]];
    [mappingStack addArrangedSubview:[self mappingRowForPhysical:@"B" defaultTarget:@"Circle"]];
    [mappingStack addArrangedSubview:[self mappingRowForPhysical:@"X" defaultTarget:@"Square"]];
    [mappingStack addArrangedSubview:[self mappingRowForPhysical:@"Y" defaultTarget:@"Triangle"]];

    UIButton* close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.translatesAutoresizingMaskIntoConstraints = NO;
    close.tintColor = UIColor.whiteColor;
    [close setTitle:@"○ Back" forState:UIControlStateNormal];
    close.titleLabel.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
    [close addTarget:self action:@selector(closePressed) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:close];

    UILayoutGuide* safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [title.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:64.0],
        [title.topAnchor constraintEqualToAnchor:safe.topAnchor constant:52.0],
        [_nameLabel.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [_nameLabel.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:10.0],
        [panel.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [panel.trailingAnchor constraintEqualToAnchor:self.view.centerXAnchor constant:-12.0],
        [panel.topAnchor constraintEqualToAnchor:_nameLabel.bottomAnchor constant:30.0],
        [_controllerKindLabel.leadingAnchor constraintEqualToAnchor:panel.contentView.leadingAnchor constant:24.0],
        [_controllerKindLabel.trailingAnchor constraintEqualToAnchor:panel.contentView.trailingAnchor constant:-24.0],
        [_controllerKindLabel.topAnchor constraintEqualToAnchor:panel.contentView.topAnchor constant:20.0],
        [_controllerPreview.leadingAnchor constraintEqualToAnchor:panel.contentView.leadingAnchor constant:22.0],
        [_controllerPreview.trailingAnchor constraintEqualToAnchor:panel.contentView.trailingAnchor constant:-22.0],
        [_controllerPreview.topAnchor constraintEqualToAnchor:_controllerKindLabel.bottomAnchor constant:8.0],
        [_controllerPreview.heightAnchor constraintEqualToConstant:190.0],
        [grid.leadingAnchor constraintEqualToAnchor:panel.contentView.leadingAnchor constant:24.0],
        [grid.trailingAnchor constraintEqualToAnchor:panel.contentView.trailingAnchor constant:-24.0],
        [grid.topAnchor constraintEqualToAnchor:_controllerPreview.bottomAnchor constant:16.0],
        [grid.bottomAnchor constraintEqualToAnchor:panel.contentView.bottomAnchor constant:-24.0],
        [_stateLabel.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [_stateLabel.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor],
        [_stateLabel.topAnchor constraintEqualToAnchor:panel.bottomAnchor constant:24.0],
        [mappingPanel.leadingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:24.0],
        [mappingPanel.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-64.0],
        [mappingPanel.topAnchor constraintEqualToAnchor:panel.topAnchor],
        [mappingPanel.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor],
        [mappingStack.leadingAnchor constraintEqualToAnchor:mappingPanel.contentView.leadingAnchor constant:22.0],
        [mappingStack.trailingAnchor constraintEqualToAnchor:mappingPanel.contentView.trailingAnchor constant:-22.0],
        [mappingStack.topAnchor constraintEqualToAnchor:mappingPanel.contentView.topAnchor constant:20.0],
        [mappingStack.bottomAnchor constraintEqualToAnchor:mappingPanel.contentView.bottomAnchor constant:-20.0],
        [close.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-42.0],
        [close.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-28.0],
    ]];

    _link = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateControllerState)];
    _link.preferredFramesPerSecond = 30;
    [_link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}

- (UIView*)mappingRowForPhysical:(NSString*)physical defaultTarget:(NSString*)defaultTarget {
    UIStackView* row = [[UIStackView alloc] init];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentCenter;
    row.spacing = 12.0;

    UILabel* label = [[UILabel alloc] init];
    label.text = physical;
    label.textColor = [UIColor colorWithWhite:1.0 alpha:0.78];
    label.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold];
    [label.widthAnchor constraintEqualToConstant:24.0].active = YES;
    [row addArrangedSubview:label];

    NSArray<NSString*>* targets = @[ @"Cross", @"Circle", @"Square", @"Triangle", @"Options", @"Share" ];
    UISegmentedControl* control = [[UISegmentedControl alloc] initWithItems:targets];
    control.accessibilityIdentifier = physical;
    NSDictionary* mapping = [[NSUserDefaults standardUserDefaults] dictionaryForKey:ShadControllerMappingDefaultsKey] ?: @{};
    NSString* selected = mapping[physical] ?: defaultTarget;
    NSUInteger index = [targets indexOfObject:selected];
    control.selectedSegmentIndex = index == NSNotFound ? 0 : (NSInteger)index;
    [control addTarget:self action:@selector(mappingChanged:) forControlEvents:UIControlEventValueChanged];
    [row addArrangedSubview:control];
    _mappingControls[physical] = control;
    return row;
}

- (void)mappingChanged:(UISegmentedControl*)sender {
    NSArray<NSString*>* targets = @[ @"Cross", @"Circle", @"Square", @"Triangle", @"Options", @"Share" ];
    NSMutableDictionary* mapping =
        [[[NSUserDefaults standardUserDefaults] dictionaryForKey:ShadControllerMappingDefaultsKey] mutableCopy] ?: [NSMutableDictionary dictionary];
    mapping[sender.accessibilityIdentifier] = targets[(NSUInteger)sender.selectedSegmentIndex];
    [[NSUserDefaults standardUserDefaults] setObject:mapping forKey:ShadControllerMappingDefaultsKey];
    [mapping release];
}

- (void)dealloc {
    [_link invalidate];
    [super dealloc];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [_link invalidate];
    _link = nil;
}

- (void)closePressed {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)updateControllerState {
    GCController* controller = GCController.controllers.firstObject;
    GCExtendedGamepad* gamepad = controller.extendedGamepad;
    NSString* vendor = controller.vendorName ?: @"Controller";
    _nameLabel.text = controller != nil ? [NSString stringWithFormat:@"%@ connected", vendor]
                                        : @"No controller connected";
    NSString* vendorLower = vendor.lowercaseString;
    NSString* style = ([vendorLower containsString:@"xbox"] || [vendorLower containsString:@"wireless controller"] == NO)
                          ? @"xbox"
                          : @"playstation";
    if ([vendorLower containsString:@"playstation"] || [vendorLower containsString:@"dualshock"] ||
        [vendorLower containsString:@"dualsense"] || [vendorLower containsString:@"ps4"] ||
        [vendorLower containsString:@"ps5"]) {
        style = @"playstation";
    }
    _controllerPreview.controllerStyle = style;
    _controllerKindLabel.text = [style isEqualToString:@"playstation"] ? @"PlayStation Controller Layout"
                                                                       : @"Xbox / Generic Controller Layout";
    NSArray<NSString*>* keys = _buttonLabels.allKeys;
    for (NSString* key in keys) {
        UILabel* label = _buttonLabels[key];
        label.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
        label.textColor = [UIColor colorWithWhite:1.0 alpha:0.62];
    }
    if (gamepad == nil) {
        _stateLabel.text = @"Connect an Xbox, PlayStation, or MFi controller from iPadOS Bluetooth settings.";
        _controllerPreview.pressedButtons = [NSSet set];
        [_controllerPreview setNeedsDisplay];
        return;
    }
    NSMutableSet<NSString*>* activeButtons = [NSMutableSet set];

    void (^mark)(NSString*, BOOL) = ^(NSString* key, BOOL active) {
        UILabel* label = _buttonLabels[key];
        if (active) {
            label.backgroundColor = [UIColor colorWithRed:0.10 green:0.48 blue:1.0 alpha:0.78];
            label.textColor = UIColor.whiteColor;
            [activeButtons addObject:key];
        }
    };
    mark(@"A / Cross", gamepad.buttonA.isPressed);
    mark(@"B / Circle", gamepad.buttonB.isPressed);
    mark(@"X / Square", gamepad.buttonX.isPressed);
    mark(@"Y / Triangle", gamepad.buttonY.isPressed);
    mark(@"L1", gamepad.leftShoulder.isPressed);
    mark(@"R1", gamepad.rightShoulder.isPressed);
    mark(@"L2", gamepad.leftTrigger.value > 0.15f);
    mark(@"R2", gamepad.rightTrigger.value > 0.15f);
    GCControllerButtonInput* menuButton = ShadOptionalButtonInput(gamepad, @selector(buttonMenu));
    GCControllerButtonInput* optionsButton = ShadOptionalButtonInput(gamepad, @selector(buttonOptions));
    mark(@"Menu", menuButton != nil && menuButton.isPressed);
    mark(@"Options", optionsButton != nil && optionsButton.isPressed);
    mark(@"D-Pad", fabsf(gamepad.dpad.xAxis.value) > 0.15f || fabsf(gamepad.dpad.yAxis.value) > 0.15f);
    mark(@"Left Stick", fabsf(gamepad.leftThumbstick.xAxis.value) > 0.15f || fabsf(gamepad.leftThumbstick.yAxis.value) > 0.15f);
    _controllerPreview.pressedButtons = activeButtons;
    [_controllerPreview setNeedsDisplay];
    _stateLabel.text = [NSString stringWithFormat:@"Left stick  X %.2f  Y %.2f\nRight stick X %.2f  Y %.2f\nL2 %.2f   R2 %.2f",
                                                  gamepad.leftThumbstick.xAxis.value,
                                                  gamepad.leftThumbstick.yAxis.value,
                                                  gamepad.rightThumbstick.xAxis.value,
                                                  gamepad.rightThumbstick.yAxis.value,
                                                  gamepad.leftTrigger.value,
                                                  gamepad.rightTrigger.value];
}

@end

@implementation ShadUserSelectionViewController {
    UIStackView* _profileStack;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.00 green:0.08 blue:0.30 alpha:1.0];

    CAGradientLayer* gradient = [CAGradientLayer layer];
    gradient.frame = self.view.bounds;
    gradient.colors = @[
        (__bridge id)[UIColor colorWithRed:0.00 green:0.07 blue:0.28 alpha:1.0].CGColor,
        (__bridge id)[UIColor colorWithRed:0.00 green:0.24 blue:0.72 alpha:1.0].CGColor,
    ];
    gradient.startPoint = CGPointMake(0.0, 0.0);
    gradient.endPoint = CGPointMake(1.0, 1.0);
    [self.view.layer insertSublayer:gradient atIndex:0];

    UILabel* title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"Select User";
    title.textColor = UIColor.whiteColor;
    title.font = [UIFont systemFontOfSize:42.0 weight:UIFontWeightLight];
    [self.view addSubview:title];

    _profileStack = [[UIStackView alloc] init];
    _profileStack.translatesAutoresizingMaskIntoConstraints = NO;
    _profileStack.axis = UILayoutConstraintAxisHorizontal;
    _profileStack.spacing = 24.0;
    _profileStack.alignment = UIStackViewAlignmentCenter;
    [self.view addSubview:_profileStack];

    UIButton* create = [UIButton buttonWithType:UIButtonTypeSystem];
    create.translatesAutoresizingMaskIntoConstraints = NO;
    create.tintColor = UIColor.whiteColor;
    create.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.12];
    create.layer.cornerRadius = 8.0;
    create.layer.borderWidth = 1.0;
    create.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.28].CGColor;
    [create setTitle:@"＋ New User" forState:UIControlStateNormal];
    create.titleLabel.font = [UIFont systemFontOfSize:21.0 weight:UIFontWeightMedium];
    [create addTarget:self action:@selector(createUserPressed) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:create];

    UILayoutGuide* safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [title.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [title.topAnchor constraintEqualToAnchor:safe.topAnchor constant:82.0],
        [_profileStack.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_profileStack.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-4.0],
        [create.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [create.topAnchor constraintEqualToAnchor:_profileStack.bottomAnchor constant:42.0],
        [create.widthAnchor constraintEqualToConstant:220.0],
        [create.heightAnchor constraintEqualToConstant:54.0],
    ]];

    [self reloadProfiles];
    if (ShadMutableProfiles().count == 0) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self createUserPressed];
        });
    }
}

- (void)reloadProfiles {
    for (UIView* view in _profileStack.arrangedSubviews) {
        [_profileStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }
    NSArray* profiles = ShadMutableProfiles();
    for (NSUInteger index = 0; index < profiles.count; index++) {
        NSDictionary* profile = profiles[index];
        UIButton* button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.tag = (NSInteger)index;
        button.tintColor = UIColor.whiteColor;
        button.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.10];
        button.layer.cornerRadius = 8.0;
        button.layer.borderWidth = 1.0;
        button.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.28].CGColor;
        NSString* name = profile[@"name"] ?: @"User";
        [button setTitle:name forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:20.0 weight:UIFontWeightMedium];
        [button addTarget:self action:@selector(profilePressed:) forControlEvents:UIControlEventTouchUpInside];
        [button.widthAnchor constraintEqualToConstant:170.0].active = YES;
        [button.heightAnchor constraintEqualToConstant:170.0].active = YES;

        UIImageView* avatar = [[UIImageView alloc] initWithImage:[self avatarImageForProfile:profile]];
        avatar.translatesAutoresizingMaskIntoConstraints = NO;
        avatar.contentMode = UIViewContentModeScaleAspectFill;
        avatar.clipsToBounds = YES;
        avatar.layer.cornerRadius = 38.0;
        avatar.backgroundColor = ShadProfileColor(profile[@"id"]);
        avatar.userInteractionEnabled = NO;
        [button addSubview:avatar];
        [NSLayoutConstraint activateConstraints:@[
            [avatar.centerXAnchor constraintEqualToAnchor:button.centerXAnchor],
            [avatar.topAnchor constraintEqualToAnchor:button.topAnchor constant:26.0],
            [avatar.widthAnchor constraintEqualToConstant:76.0],
            [avatar.heightAnchor constraintEqualToConstant:76.0],
        ]];

        [_profileStack addArrangedSubview:button];
    }
}

- (UIImage*)avatarImageForProfile:(NSDictionary*)profile {
    NSString* path = profile[@"avatarPath"];
    UIImage* image = path.length > 0 ? [UIImage imageWithContentsOfFile:path] : nil;
    if (image != nil) {
        return image;
    }
    return [UIImage systemImageNamed:@"person.crop.circle.fill"];
}

- (void)profilePressed:(UIButton*)sender {
    NSMutableArray* profiles = ShadMutableProfiles();
    if (sender.tag < 0 || sender.tag >= (NSInteger)profiles.count) {
        return;
    }
    NSDictionary* profile = profiles[(NSUInteger)sender.tag];
    NSString* passcode = profile[@"passcode"];
    if (passcode.length > 0) {
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Enter Passcode"
                                                                       message:profile[@"name"]
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addTextFieldWithConfigurationHandler:^(UITextField* textField) {
            textField.placeholder = @"Passcode";
            textField.secureTextEntry = YES;
        }];
        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction* action) {
                                                    if ([alert.textFields.firstObject.text isEqualToString:passcode]) {
                                                        [self selectProfile:profile];
                                                    }
                                                }]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    [self selectProfile:profile];
}

- (void)selectProfile:(NSDictionary*)profile {
    [[NSUserDefaults standardUserDefaults] setObject:profile[@"id"] forKey:ShadCurrentUserIDDefaultsKey];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:ShadFirstLaunchCompleteDefaultsKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:ShadProfileChangedNotification object:nil];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)createUserPressed {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Create User"
                                                                   message:@"Name is required. Passcode is optional."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField* textField) {
        textField.placeholder = @"User name";
        textField.text = @"User";
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField* textField) {
        textField.placeholder = @"Passcode (optional)";
        textField.secureTextEntry = YES;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Create"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction* action) {
                                                NSString* name = alert.textFields.firstObject.text;
                                                if (name.length == 0) {
                                                    name = @"User";
                                                }
                                                NSMutableArray* profiles = ShadMutableProfiles();
                                                NSString* identifier = NSUUID.UUID.UUIDString;
                                                [profiles addObject:[@{
                                                    @"id" : identifier,
                                                    @"name" : name,
                                                    @"passcode" : alert.textFields.lastObject.text ?: @"",
                                                } mutableCopy]];
                                                ShadSaveProfiles(profiles);
                                                [self reloadProfiles];
                                                [self selectProfile:profiles.lastObject];
                                            }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

@implementation ShadProfileViewController {
    UIImageView* _avatarView;
    UILabel* _nameLabel;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.00 green:0.08 blue:0.30 alpha:0.96];

    UIVisualEffectView* panel =
        [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark]];
    panel.translatesAutoresizingMaskIntoConstraints = NO;
    panel.layer.cornerRadius = 8.0;
    panel.clipsToBounds = YES;
    [self.view addSubview:panel];

    _avatarView = [[UIImageView alloc] init];
    _avatarView.translatesAutoresizingMaskIntoConstraints = NO;
    _avatarView.contentMode = UIViewContentModeScaleAspectFill;
    _avatarView.clipsToBounds = YES;
    _avatarView.layer.cornerRadius = 52.0;
    [panel.contentView addSubview:_avatarView];

    _nameLabel = [[UILabel alloc] init];
    _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _nameLabel.textColor = UIColor.whiteColor;
    _nameLabel.textAlignment = NSTextAlignmentCenter;
    _nameLabel.font = [UIFont systemFontOfSize:30.0 weight:UIFontWeightLight];
    [panel.contentView addSubview:_nameLabel];

    UIStackView* actions = [[UIStackView alloc] init];
    actions.translatesAutoresizingMaskIntoConstraints = NO;
    actions.axis = UILayoutConstraintAxisVertical;
    actions.spacing = 12.0;
    [panel.contentView addSubview:actions];
    [actions addArrangedSubview:[self actionButton:@"Change Name" selector:@selector(changeNamePressed)]];
    [actions addArrangedSubview:[self actionButton:@"Change Picture" selector:@selector(changePicturePressed)]];
    [actions addArrangedSubview:[self actionButton:@"Log Out" selector:@selector(logoutPressed)]];
    [actions addArrangedSubview:[self actionButton:@"Delete Account" selector:@selector(deleteAccountPressed)]];
    [actions addArrangedSubview:[self actionButton:@"Back" selector:@selector(closePressed)]];

    [NSLayoutConstraint activateConstraints:@[
        [panel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [panel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [panel.widthAnchor constraintEqualToConstant:430.0],
        [_avatarView.centerXAnchor constraintEqualToAnchor:panel.contentView.centerXAnchor],
        [_avatarView.topAnchor constraintEqualToAnchor:panel.contentView.topAnchor constant:36.0],
        [_avatarView.widthAnchor constraintEqualToConstant:104.0],
        [_avatarView.heightAnchor constraintEqualToConstant:104.0],
        [_nameLabel.leadingAnchor constraintEqualToAnchor:panel.contentView.leadingAnchor constant:24.0],
        [_nameLabel.trailingAnchor constraintEqualToAnchor:panel.contentView.trailingAnchor constant:-24.0],
        [_nameLabel.topAnchor constraintEqualToAnchor:_avatarView.bottomAnchor constant:18.0],
        [actions.leadingAnchor constraintEqualToAnchor:panel.contentView.leadingAnchor constant:42.0],
        [actions.trailingAnchor constraintEqualToAnchor:panel.contentView.trailingAnchor constant:-42.0],
        [actions.topAnchor constraintEqualToAnchor:_nameLabel.bottomAnchor constant:28.0],
        [actions.bottomAnchor constraintEqualToAnchor:panel.contentView.bottomAnchor constant:-34.0],
    ]];
    [self refreshProfile];
}

- (UIButton*)actionButton:(NSString*)title selector:(SEL)selector {
    UIButton* button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.tintColor = UIColor.whiteColor;
    button.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.10];
    button.layer.cornerRadius = 6.0;
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    [button.heightAnchor constraintEqualToConstant:46.0].active = YES;
    return button;
}

- (void)refreshProfile {
    NSDictionary* profile = ShadCurrentProfile();
    _nameLabel.text = profile[@"name"] ?: @"User";
    NSString* path = profile[@"avatarPath"];
    UIImage* image = path.length > 0 ? [UIImage imageWithContentsOfFile:path] : nil;
    _avatarView.image = image ?: [UIImage systemImageNamed:@"person.crop.circle.fill"];
    _avatarView.tintColor = UIColor.whiteColor;
    _avatarView.backgroundColor = ShadProfileColor(profile[@"id"]);
}

- (void)changeNamePressed {
    NSMutableDictionary* current = ShadCurrentProfile();
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Change Name"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField* textField) {
        textField.text = current[@"name"] ?: @"User";
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Save"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction* action) {
                                                NSString* name = alert.textFields.firstObject.text;
                                                if (name.length > 0) {
                                                    NSMutableArray* profiles = ShadMutableProfiles();
                                                    for (NSMutableDictionary* profile in profiles) {
                                                        if ([profile[@"id"] isEqualToString:current[@"id"]]) {
                                                            profile[@"name"] = name;
                                                            break;
                                                        }
                                                    }
                                                    ShadSaveProfiles(profiles);
                                                    [[NSNotificationCenter defaultCenter] postNotificationName:ShadProfileChangedNotification object:nil];
                                                    [self refreshProfile];
                                                }
                                            }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)changePicturePressed {
    PHPickerConfiguration* config = [[PHPickerConfiguration alloc] init];
    config.filter = [PHPickerFilter imagesFilter];
    config.selectionLimit = 1;
    PHPickerViewController* picker = [[PHPickerViewController alloc] initWithConfiguration:config];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)picker:(PHPickerViewController*)picker didFinishPicking:(NSArray<PHPickerResult*>*)results {
    [picker dismissViewControllerAnimated:YES completion:nil];
    PHPickerResult* result = results.firstObject;
    if (result == nil) {
        return;
    }
    [result.itemProvider loadDataRepresentationForTypeIdentifier:UTTypeImage.identifier
                                               completionHandler:^(NSData* data, NSError* error) {
                                                   if (data.length == 0) {
                                                       return;
                                                   }
                                                   UIImage* selectedImage = [UIImage imageWithData:data];
                                                   NSData* imageData = selectedImage != nil ? UIImageJPEGRepresentation(selectedImage, 0.86) : data;
                                                   NSURL* docs = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
                                                   NSURL* dir = [docs URLByAppendingPathComponent:@"Profiles" isDirectory:YES];
                                                   [NSFileManager.defaultManager createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil];
                                                   NSString* currentID = ShadCurrentUserID() ?: NSUUID.UUID.UUIDString;
                                                   NSURL* destination = [dir URLByAppendingPathComponent:[currentID stringByAppendingString:@".jpg"]];
                                                   [imageData writeToURL:destination atomically:YES];
                                                   dispatch_async(dispatch_get_main_queue(), ^{
                                                       NSMutableArray* profiles = ShadMutableProfiles();
                                                       for (NSMutableDictionary* profile in profiles) {
                                                           if ([profile[@"id"] isEqualToString:currentID]) {
                                                               profile[@"avatarPath"] = destination.path;
                                                               break;
                                                           }
                                                       }
                                                       ShadSaveProfiles(profiles);
                                                       [[NSNotificationCenter defaultCenter] postNotificationName:ShadProfileChangedNotification object:nil];
                                                       [self refreshProfile];
                                                   });
                                               }];
}

- (void)logoutPressed {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:ShadCurrentUserIDDefaultsKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:ShadProfileChangedNotification object:nil];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)deleteAccountPressed {
    NSDictionary* current = ShadCurrentProfile();
    NSString* name = current[@"name"] ?: @"User";
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Delete Account"
                                                                   message:[NSString stringWithFormat:@"Delete %@ from this iPad?", name]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Delete"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction* action) {
                                                NSString* currentID = current[@"id"];
                                                NSString* avatarPath = current[@"avatarPath"];
                                                if (avatarPath.length > 0) {
                                                    [NSFileManager.defaultManager removeItemAtPath:avatarPath error:nil];
                                                }
                                                NSMutableArray* profiles = ShadMutableProfiles();
                                                NSIndexSet* matches = [profiles indexesOfObjectsPassingTest:^BOOL(NSDictionary* profile, NSUInteger idx, BOOL* stop) {
                                                    return [profile[@"id"] isEqualToString:currentID];
                                                }];
                                                [profiles removeObjectsAtIndexes:matches];
                                                ShadSaveProfiles(profiles);
                                                [[NSUserDefaults standardUserDefaults] removeObjectForKey:ShadCurrentUserIDDefaultsKey];
                                                [[NSNotificationCenter defaultCenter] postNotificationName:ShadProfileChangedNotification object:nil];
                                                [self dismissViewControllerAnimated:YES completion:nil];
                                            }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)closePressed {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

@interface ShadExternalDisplayViewController : UIViewController

@property(nonatomic, strong, readonly) UIView* renderContainerView;
@property(nonatomic, strong, readonly) UILabel* statusLabel;

- (void)updateForScreen:(UIScreen*)screen activeGame:(BOOL)activeGame;

@end

@implementation ShadExternalDisplayViewController {
    UIView* _renderContainerView;
    UILabel* _statusLabel;
}

- (UIView*)renderContainerView {
    return _renderContainerView;
}

- (UILabel*)statusLabel {
    return _statusLabel;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.edgesForExtendedLayout = UIRectEdgeAll;
    self.extendedLayoutIncludesOpaqueBars = YES;
    self.view.insetsLayoutMarginsFromSafeArea = NO;
    self.view.frame = UIScreen.mainScreen.bounds;
    self.view.backgroundColor = UIColor.blackColor;

    _renderContainerView = [[UIView alloc] init];
    _renderContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    _renderContainerView.backgroundColor = UIColor.blackColor;
    [self.view addSubview:_renderContainerView];

    _statusLabel = [[UILabel alloc] init];
    _statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _statusLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.72];
    _statusLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightMedium];
    _statusLabel.textAlignment = NSTextAlignmentRight;
    _statusLabel.text = @"Orbit Console external display ready";
    [self.view addSubview:_statusLabel];

    UILayoutGuide* safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [_renderContainerView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_renderContainerView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_renderContainerView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_renderContainerView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [_statusLabel.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-24.0],
        [_statusLabel.topAnchor constraintEqualToAnchor:safe.topAnchor constant:18.0],
        [_statusLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:safe.leadingAnchor constant:24.0],
    ]];
}

- (void)updateForScreen:(UIScreen*)screen activeGame:(BOOL)activeGame {
    CGSize pixelSize = CGSizeMake(CGRectGetWidth(screen.bounds) * screen.scale,
                                  CGRectGetHeight(screen.bounds) * screen.scale);
    _statusLabel.text = activeGame
                            ? [NSString stringWithFormat:@"External Game Display %.0fx%.0f",
                                                         pixelSize.width, pixelSize.height]
                            : [NSString stringWithFormat:@"External Display Ready %.0fx%.0f",
                                                         pixelSize.width, pixelSize.height];
    _statusLabel.alpha = activeGame ? 0.0 : 1.0;
}

@end

@interface ShadViewController () <UIDocumentPickerDelegate, UIScrollViewDelegate>

@property(nonatomic, strong) MTKView* metalView;
@property(nonatomic, strong) NSArray<NSLayoutConstraint*>* metalViewConstraints;
@property(nonatomic, strong) UIView* dashboardView;
@property(nonatomic, strong) UIImageView* backgroundImageView;
@property(nonatomic, strong) ShadDashboardWavesView* dashboardWavesView;
@property(nonatomic, strong) UIView* topBar;
@property(nonatomic, strong) UILabel* clockLabel;
@property(nonatomic, strong) UIButton* profileButton;
@property(nonatomic, strong) UILabel* profileNameLabel;
@property(nonatomic, strong) UIScrollView* gameScrollView;
@property(nonatomic, strong) UIStackView* gameStack;
@property(nonatomic, strong) UILabel* selectedTitleLabel;
@property(nonatomic, strong) UILabel* selectedDetailLabel;
@property(nonatomic, strong) UILabel* selectedCompatibilityLabel;
@property(nonatomic, strong) UIView* selectedCompatibilityDot;
@property(nonatomic, strong) UILabel* selectedPathLabel;
@property(nonatomic, strong) UILabel* selectedTypeLabel;
@property(nonatomic, strong) UILabel* selectedLastPlayedLabel;
@property(nonatomic, strong) UIVisualEffectView* gameDetailPanel;
@property(nonatomic, strong) UIVisualEffectView* emptyStateView;
@property(nonatomic, strong) UIVisualEffectView* importOverlayView;
@property(nonatomic, strong) UIProgressView* importProgressView;
@property(nonatomic, strong) UILabel* importProgressLabel;
@property(nonatomic, strong) UIButton* deleteGameButton;
@property(nonatomic, strong) UIButton* startGameButton;
@property(nonatomic, strong) UIButton* editGameButton;
@property(nonatomic, strong) UIView* touchOverlay;
@property(nonatomic, strong) UIVisualEffectView* virtualLayoutEditPanel;
@property(nonatomic, strong) UILabel* virtualLayoutEditHintLabel;
@property(nonatomic, strong) NSMutableDictionary<NSString*, UIButton*>* virtualControlButtons;
@property(nonatomic, strong) NSMutableSet<NSString*>* pressedVirtualControls;
@property(nonatomic, copy) NSDictionary* virtualLayoutEditSnapshot;
@property(nonatomic, copy) NSString* selectedVirtualControlKey;
@property(nonatomic, strong) UIVisualEffectView* overlayMenuView;
@property(nonatomic, strong) UIButton* runtimeMenuButton;
@property(nonatomic, strong) UIVisualEffectView* performanceOverlayView;
@property(nonatomic, strong) UILabel* performanceOverlayLabel;
@property(nonatomic, strong) NSLayoutConstraint* performanceOverlayLeadingConstraint;
@property(nonatomic, strong) NSLayoutConstraint* performanceOverlayCenterConstraint;
@property(nonatomic, strong) NSLayoutConstraint* performanceOverlayTrailingConstraint;
@property(nonatomic, strong) NSLayoutConstraint* performanceOverlayTopConstraint;
@property(nonatomic, strong) UILabel* statusLabel;
@property(nonatomic, strong) UIView* bootIntroView;
@property(nonatomic, strong) NSMutableArray<NSMutableDictionary*>* games;
@property(nonatomic, strong) NSMutableArray<UIButton*>* gameButtons;
@property(nonatomic, strong) NSMutableArray<UIButton*>* topMenuButtons;
@property(nonatomic, strong) UIButton* addGameTile;
@property(nonatomic, strong) NSTimer* clockTimer;
@property(nonatomic, strong) NSTimer* runtimeStatsTimer;
@property(nonatomic, strong) CADisplayLink* controllerPollLink;
@property(nonatomic, strong) AVAudioPlayer* moveSoundPlayer;
@property(nonatomic, strong) AVAudioPlayer* acceptSoundPlayer;
@property(nonatomic, strong) AVAudioPlayer* backSoundPlayer;
@property(nonatomic, strong) AVAudioPlayer* startupSoundPlayer;
@property(nonatomic, strong) AVAudioPlayer* consoleMoveSoundPlayer;
@property(nonatomic, strong) AVAudioPlayer* consoleAcceptSoundPlayer;
@property(nonatomic, strong) AVAudioPlayer* consoleBackSoundPlayer;
@property(nonatomic, strong) AVAudioPlayer* consoleStartupSoundPlayer;
@property(nonatomic, assign) GCController* activeController;
@property(nonatomic, assign) NSInteger selectedGameIndex;
@property(nonatomic, assign) NSInteger topMenuIndex;
@property(nonatomic, assign) BOOL topMenuFocused;
@property(nonatomic, assign) BOOL touchControlsVisible;
@property(nonatomic, assign) BOOL virtualLayoutEditing;
@property(nonatomic, assign) BOOL importingGame;
@property(nonatomic, assign) ShadVirtualPadState virtualPadState;
@property(nonatomic, assign) CFTimeInterval lastDrawTime;
@property(nonatomic, assign) CFTimeInterval lastStatsUpdateTime;
@property(nonatomic, assign) CFTimeInterval previousStatsFrameTime;
@property(nonatomic, assign) NSUInteger framesSinceStatsUpdate;
@property(nonatomic, assign) double currentFPS;
@property(nonatomic, assign) double currentCPUPercent;
@property(nonatomic, assign) double currentGPULoadPercent;
@property(nonatomic, assign) double currentRAMMB;
@property(nonatomic, assign) uint64_t lastPresenterPresentCount;
@property(nonatomic, assign) CFTimeInterval lastControllerMoveTime;
@property(nonatomic, assign) NSInteger frameLimit;
@property(nonatomic, assign) BOOL didShowBootIntro;
@property(nonatomic, assign) NSProcessInfoThermalState lastThermalState;
@property(nonatomic, assign) CFTimeInterval lastThermalCheckTime;
@property(nonatomic, copy) NSString* pendingGameImportMode;
@property(nonatomic, strong) UIWindow* externalDisplayWindow;
@property(nonatomic, strong) ShadExternalDisplayViewController* externalDisplayViewController;
@property(nonatomic, strong) UIScreen* externalDisplayScreen;
@property(nonatomic, assign) BOOL externalDisplayActive;

@end

@implementation ShadSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.42];
    self.valueLabels = [NSMutableDictionary dictionary];
    self.settingsFocusableControls = [NSMutableArray array];
    self.selectedSettingsIndex = 0;

    UIVisualEffectView* sidebar =
        [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterialDark]];
    sidebar.translatesAutoresizingMaskIntoConstraints = NO;
    sidebar.clipsToBounds = YES;
    self.sidebarView = sidebar;
    [self.view addSubview:sidebar];

    UILabel* title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"Settings";
    title.textColor = UIColor.whiteColor;
    title.font = [UIFont systemFontOfSize:31.0 weight:UIFontWeightLight];
    [sidebar.contentView addSubview:title];

    UIStackView* categoryStack = [[UIStackView alloc] init];
    categoryStack.translatesAutoresizingMaskIntoConstraints = NO;
    categoryStack.axis = UILayoutConstraintAxisVertical;
    categoryStack.spacing = 12.0;
    [sidebar.contentView addSubview:categoryStack];

    self.categoryButtons = [NSMutableArray array];
    NSArray<NSString*>* categories = @[ @"Orbit Console", @"Appearance", @"Graphics & Video", @"Audio", @"Input Controls", @"Debug" ];
    for (NSUInteger i = 0; i < categories.count; i++) {
        UIButton* row = [UIButton buttonWithType:UIButtonTypeSystem];
        row.tag = (NSInteger)i;
        row.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        row.tintColor = UIColor.whiteColor;
        [row setTitle:categories[i] forState:UIControlStateNormal];
        row.titleLabel.font = [UIFont systemFontOfSize:19.0 weight:i == 0 ? UIFontWeightSemibold : UIFontWeightRegular];
        row.backgroundColor = i == 0 ? [UIColor colorWithWhite:1.0 alpha:0.13] : UIColor.clearColor;
        row.layer.cornerRadius = 4.0;
        row.clipsToBounds = YES;
        row.contentEdgeInsets = UIEdgeInsetsMake(0, 12, 0, 0);
        [row addTarget:self action:@selector(categoryPressed:) forControlEvents:UIControlEventTouchUpInside];
        [categoryStack addArrangedSubview:row];
        [self.categoryButtons addObject:row];
        [self.settingsFocusableControls addObject:row];
        [row.heightAnchor constraintEqualToConstant:44.0].active = YES;
    }

    UIVisualEffectView* details =
        [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark]];
    details.translatesAutoresizingMaskIntoConstraints = NO;
    details.layer.cornerRadius = 6.0;
    details.clipsToBounds = YES;
    self.detailsView = details;
    [self.view addSubview:details];

    UIScrollView* settingsScroll = [[UIScrollView alloc] init];
    settingsScroll.translatesAutoresizingMaskIntoConstraints = NO;
    settingsScroll.showsVerticalScrollIndicator = YES;
    settingsScroll.alwaysBounceVertical = YES;
    self.settingsScrollView = settingsScroll;
    [details.contentView addSubview:settingsScroll];

    self.settingsStack = [[UIStackView alloc] init];
    self.settingsStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.settingsStack.axis = UILayoutConstraintAxisVertical;
    self.settingsStack.spacing = 14.0;
    [settingsScroll addSubview:self.settingsStack];

    UIButton* backButton = [UIButton buttonWithType:UIButtonTypeSystem];
    backButton.translatesAutoresizingMaskIntoConstraints = NO;
    backButton.tintColor = [UIColor colorWithWhite:1.0 alpha:0.76];
    backButton.titleLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    [backButton setTitle:@"○ Back" forState:UIControlStateNormal];
    [backButton addTarget:self action:@selector(dismissSettingsPressed) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:backButton];

    UISwipeGestureRecognizer* closeSwipe =
        [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(dismissSettingsPressed)];
    closeSwipe.direction = UISwipeGestureRecognizerDirectionRight;
    [self.view addGestureRecognizer:closeSwipe];

    [NSLayoutConstraint activateConstraints:@[
        [sidebar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [sidebar.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [sidebar.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [sidebar.widthAnchor constraintEqualToConstant:310.0],

        [title.leadingAnchor constraintEqualToAnchor:sidebar.contentView.leadingAnchor constant:34.0],
        [title.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:34.0],

        [categoryStack.leadingAnchor constraintEqualToAnchor:sidebar.contentView.leadingAnchor constant:22.0],
        [categoryStack.trailingAnchor constraintEqualToAnchor:sidebar.contentView.trailingAnchor constant:-22.0],
        [categoryStack.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:36.0],

        [details.leadingAnchor constraintEqualToAnchor:sidebar.trailingAnchor constant:34.0],
        [details.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-44.0],
        [details.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:48.0],
        [details.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-72.0],

        [settingsScroll.leadingAnchor constraintEqualToAnchor:details.contentView.leadingAnchor],
        [settingsScroll.trailingAnchor constraintEqualToAnchor:details.contentView.trailingAnchor],
        [settingsScroll.topAnchor constraintEqualToAnchor:details.contentView.topAnchor],
        [settingsScroll.bottomAnchor constraintEqualToAnchor:details.contentView.bottomAnchor],

        [self.settingsStack.leadingAnchor constraintEqualToAnchor:settingsScroll.contentLayoutGuide.leadingAnchor constant:28.0],
        [self.settingsStack.trailingAnchor constraintEqualToAnchor:settingsScroll.contentLayoutGuide.trailingAnchor constant:-28.0],
        [self.settingsStack.topAnchor constraintEqualToAnchor:settingsScroll.contentLayoutGuide.topAnchor constant:24.0],
        [self.settingsStack.bottomAnchor constraintEqualToAnchor:settingsScroll.contentLayoutGuide.bottomAnchor constant:-24.0],
        [self.settingsStack.widthAnchor constraintEqualToAnchor:settingsScroll.frameLayoutGuide.widthAnchor constant:-56.0],

        [backButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-36.0],
        [backButton.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-22.0],
        [backButton.widthAnchor constraintEqualToConstant:96.0],
        [backButton.heightAnchor constraintEqualToConstant:38.0],
    ]];

    [self renderCategory:0];
    [self installSettingsControllerNavigation];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.sidebarView.transform = CGAffineTransformMakeTranslation(-42.0, 0.0);
    self.detailsView.transform = CGAffineTransformMakeTranslation(28.0, 0.0);
    self.sidebarView.alpha = 0.0;
    self.detailsView.alpha = 0.0;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.view.window setFrame:UIScreen.mainScreen.bounds];
    [UIView animateWithDuration:0.34
                          delay:0.0
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
                         self.sidebarView.transform = CGAffineTransformIdentity;
                         self.detailsView.transform = CGAffineTransformIdentity;
                         self.sidebarView.alpha = 1.0;
                         self.detailsView.alpha = 1.0;
                     }
                     completion:nil];
}

- (void)dealloc {
    [self.settingsControllerPollLink invalidate];
    [super dealloc];
}

- (UILabel*)settingsHeader:(NSString*)title {
    UILabel* label = [[UILabel alloc] init];
    label.text = title;
    label.textColor = [UIColor colorWithWhite:1.0 alpha:0.96];
    label.font = [UIFont systemFontOfSize:21.0 weight:UIFontWeightSemibold];
    return label;
}

- (void)registerSettingsControl:(UIControl*)control {
    if (control == nil) {
        return;
    }
    [self.settingsFocusableControls addObject:control];
}

- (void)updateSettingsFocusAnimated:(BOOL)animated {
    if (self.settingsFocusableControls.count == 0) {
        return;
    }
    self.selectedSettingsIndex =
        MIN(MAX(self.selectedSettingsIndex, 0), (NSInteger)self.settingsFocusableControls.count - 1);

    void (^changes)(void) = ^{
        for (NSUInteger idx = 0; idx < self.settingsFocusableControls.count; idx++) {
            UIControl* control = self.settingsFocusableControls[idx];
            const BOOL selected = (NSInteger)idx == self.selectedSettingsIndex;
            control.layer.borderWidth = selected ? 2.0 : 0.0;
            control.layer.borderColor =
                selected ? [UIColor colorWithWhite:1.0 alpha:0.92].CGColor : UIColor.clearColor.CGColor;
            control.layer.shadowOpacity = selected ? 0.34 : 0.0;
            control.layer.shadowRadius = selected ? 12.0 : 0.0;
            control.layer.shadowColor = UIColor.whiteColor.CGColor;
            control.alpha = selected ? 1.0 : MAX(control.alpha, 0.72);
        }
    };

    if (animated) {
        [UIView animateWithDuration:0.14
                              delay:0.0
                            options:UIViewAnimationOptionAllowUserInteraction |
                                    UIViewAnimationOptionBeginFromCurrentState
                         animations:changes
                         completion:nil];
    } else {
        changes();
    }

    UIControl* focused = self.settingsFocusableControls[(NSUInteger)self.selectedSettingsIndex];
    if (![focused isKindOfClass:UIButton.class] || ![self.categoryButtons containsObject:(UIButton*)focused]) {
        CGRect rect = [self.settingsScrollView convertRect:focused.bounds fromView:focused];
        [self.settingsScrollView scrollRectToVisible:CGRectInset(rect, 0.0, -34.0) animated:animated];
    }
}

- (void)moveSettingsFocus:(NSInteger)delta {
    if (self.settingsFocusableControls.count == 0) {
        return;
    }
    self.selectedSettingsIndex =
        (self.selectedSettingsIndex + delta + (NSInteger)self.settingsFocusableControls.count) %
        (NSInteger)self.settingsFocusableControls.count;
    ShadPostUISound(@"move");
    [self updateSettingsFocusAnimated:YES];
}

- (void)categoryPressed:(UIButton*)sender {
    [self renderCategory:sender.tag];
    ShadPostUISound(@"move");
}

- (void)renderCategory:(NSInteger)category {
    self.selectedCategory = category;
    [self.valueLabels removeAllObjects];
    [self.settingsFocusableControls removeAllObjects];
    [self.settingsFocusableControls addObjectsFromArray:self.categoryButtons];
    for (UIButton* button in self.categoryButtons) {
        const BOOL selected = button.tag == category;
        void (^categoryChanges)(void) = ^{
            button.backgroundColor = selected ? [UIColor colorWithWhite:1.0 alpha:0.16] : UIColor.clearColor;
            button.titleLabel.font = [UIFont systemFontOfSize:19.0 weight:selected ? UIFontWeightSemibold : UIFontWeightRegular];
            button.alpha = selected ? 1.0 : 0.68;
            button.transform = selected ? CGAffineTransformMakeTranslation(8.0, 0.0) : CGAffineTransformIdentity;
        };
        [UIView animateWithDuration:0.18
                              delay:0.0
                            options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState |
                                    UIViewAnimationOptionCurveEaseOut
                         animations:categoryChanges
                         completion:nil];
    }

    for (UIView* view in self.settingsStack.arrangedSubviews) {
        [self.settingsStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }

    switch (category) {
    case 0:
        [self.settingsStack addArrangedSubview:[self settingsHeader:@"Orbit Console System"]];
        [self.settingsStack addArrangedSubview:[self switchRow:@"Enable Log" key:ShadSettingEnableLogKey defaultValue:YES]];
        [self.settingsStack addArrangedSubview:[self segmentedRow:@"Firmware Version"
                                                         options:@[ @"9.00", @"10.01", @"11.00" ]
                                                             key:ShadSettingFirmwareKey
                                                    defaultIndex:2]];
        [self.settingsStack addArrangedSubview:[self switchRow:@"Orbit Dashboard Sound Effects"
                                                           key:ShadSettingUISoundEffectsKey
                                                  defaultValue:YES]];
        [self.settingsStack addArrangedSubview:[self switchRow:@"Orbit Sound Theme"
                                                           key:ShadSettingConsoleSoundThemeKey
                                                  defaultValue:NO]];
        [self.settingsStack addArrangedSubview:[self settingsHeader:@"Device"]];
        [self.settingsStack addArrangedSubview:[self settingRow:@"Device Name" value:UIDevice.currentDevice.name]];
        [self.settingsStack addArrangedSubview:[self settingRow:@"Model" value:[self deviceModelIdentifier]]];
        [self.settingsStack addArrangedSubview:[self settingRow:@"System" value:[self systemVersionString]]];
        [self.settingsStack addArrangedSubview:[self settingRow:@"CPU Cores" value:[NSString stringWithFormat:@"%ld", (long)NSProcessInfo.processInfo.processorCount]]];
        [self.settingsStack addArrangedSubview:[self settingRow:@"Memory" value:[self physicalMemoryString]]];
        [self.settingsStack addArrangedSubview:[self settingRow:@"Free Storage" value:[self freeStorageString]]];
        [self.settingsStack addArrangedSubview:[self settingRow:@"Metal GPU" value:[self metalDeviceName]]];
        [self.settingsStack addArrangedSubview:[self settingRow:@"Thermal State" value:[self thermalStateString]]];
        break;
    case 1:
        [self.settingsStack addArrangedSubview:[self settingsHeader:@"Appearance"]];
        [self.settingsStack addArrangedSubview:[self segmentedRow:@"Background Source"
                                                         options:@[ @"Dynamic", @"Photo" ]
                                                             key:ShadDashboardBackgroundModeDefaultsKey
                                                    defaultIndex:0]];
        [self.settingsStack addArrangedSubview:[self segmentedRow:@"Dynamic Background"
                                                         options:@[ @"Classic", @"Midnight", @"Aurora", @"Crimson" ]
                                                             key:ShadDashboardDynamicStyleDefaultsKey
                                                    defaultIndex:0]];
        [self.settingsStack addArrangedSubview:[self actionRow:@"Choose Photo Background" action:@selector(changeBackgroundPressed)]];
        [self.settingsStack addArrangedSubview:[self actionRow:@"Use Dynamic Background" action:@selector(resetBackgroundPressed)]];
        [self.settingsStack addArrangedSubview:[self settingsHeader:@"Animation & Effects"]];
        [self.settingsStack addArrangedSubview:[self segmentedRow:@"Orbit Dashboard Motion"
                                                         options:@[ @"Off", @"Subtle", @"Normal", @"Cinematic" ]
                                                             key:ShadSettingAnimationEffectKey
                                                    defaultIndex:2]];
        [self.settingsStack addArrangedSubview:[self sliderRow:@"Effect Intensity"
                                                           key:ShadSettingAnimationIntensityKey
                                                  defaultValue:0.72
                                                           min:0.0
                                                           max:1.0
                                                        suffix:@"%"]];
        break;
    case 2:
        [self.settingsStack addArrangedSubview:[self settingsHeader:@"Graphics & Video"]];
        [self.settingsStack addArrangedSubview:[self segmentedRow:@"Internal Resolution"
                                                         options:@[ @"720p", @"900p", @"1080p" ]
                                                             key:ShadSettingInternalResolutionKey
                                                    defaultIndex:2]];
        [self.settingsStack addArrangedSubview:[self switchRow:@"V-Sync" key:ShadSettingVSyncKey defaultValue:YES]];
        [self.settingsStack addArrangedSubview:[self switchRow:@"Frame Generation"
                                                           key:ShadSettingFrameGenerationKey
                                                  defaultValue:NO]];
        [self.settingsStack addArrangedSubview:[self segmentedRow:@"Frame Limit"
                                                         options:@[ @"30 FPS", @"35 FPS", @"40 FPS" ]
                                                             key:ShadFrameLimitDefaultsKey
                                                    defaultIndex:0]];
        [self.settingsStack addArrangedSubview:[self segmentedRow:@"Aspect Mode"
                                                         options:@[ @"Fit", @"Fill", @"Integer" ]
                                                             key:ShadSettingAspectModeKey
                                                    defaultIndex:0]];
        [self.settingsStack addArrangedSubview:[self switchRow:@"Menu FPS Throttle"
                                                           key:ShadSettingMenuThrottleKey
                                                  defaultValue:YES]];
        [self.settingsStack addArrangedSubview:[self switchRow:@"Thermal Guard"
                                                           key:ShadSettingThermalGuardKey
                                                  defaultValue:YES]];
        [self.settingsStack addArrangedSubview:[self settingsHeader:@"MoltenVK"]];
        [self.settingsStack addArrangedSubview:[self switchRow:@"Validation Logging"
                                                           key:ShadSettingMoltenVKValidationKey
                                                  defaultValue:NO]];
        [self.settingsStack addArrangedSubview:[self switchRow:@"Fast Math"
                                                           key:ShadSettingMoltenVKFastMathKey
                                                  defaultValue:YES]];
        [self.settingsStack addArrangedSubview:[self segmentedRow:@"GPU Sync Mode"
                                                         options:@[ @"Balanced", @"Low Latency", @"Safe" ]
                                                             key:ShadSettingMoltenVKSyncModeKey
                                                    defaultIndex:0]];
        [self.settingsStack addArrangedSubview:[self segmentedRow:@"Present Mode"
                                                         options:@[ @"FIFO", @"Mailbox", @"Immediate" ]
                                                             key:ShadSettingMoltenVKPresentModeKey
                                                    defaultIndex:0]];
        [self.settingsStack addArrangedSubview:[self settingRow:@"Bridge Status" value:@"MoltenVK bridge pending"]];
        [self.settingsStack addArrangedSubview:[self settingsHeader:@"MetalFX"]];
        [self.settingsStack addArrangedSubview:[self switchRow:@"Enable MetalFX Upscaling"
                                                           key:ShadSettingMetalFXEnabledKey
                                                  defaultValue:NO]];
        [self.settingsStack addArrangedSubview:[self segmentedRow:@"MetalFX Mode"
                                                         options:@[ @"Spatial", @"Temporal" ]
                                                             key:ShadSettingMetalFXModeKey
                                                    defaultIndex:0]];
        [self.settingsStack addArrangedSubview:[self sliderRow:@"MetalFX Sharpness"
                                                           key:ShadSettingMetalFXSharpnessKey
                                                  defaultValue:0.55
                                                           min:0.0
                                                           max:1.0
                                                        suffix:@"%"]];
        [self.settingsStack addArrangedSubview:[self settingRow:@"MetalFX Status" value:@"Ready for renderer hook"]];
        [self.settingsStack addArrangedSubview:[self settingsHeader:@"Runtime Overlay"]];
        [self.settingsStack addArrangedSubview:[self switchRow:@"Show Runtime Stats"
                                                           key:ShadSettingRuntimeStatsOverlayKey
                                                  defaultValue:YES]];
        [self.settingsStack addArrangedSubview:[self switchRow:@"FPS" key:ShadSettingRuntimeStatsFPSKey defaultValue:YES]];
        [self.settingsStack addArrangedSubview:[self switchRow:@"CPU Use" key:ShadSettingRuntimeStatsCPUKey defaultValue:YES]];
        [self.settingsStack addArrangedSubview:[self switchRow:@"GPU Use" key:ShadSettingRuntimeStatsGPUKey defaultValue:YES]];
        [self.settingsStack addArrangedSubview:[self switchRow:@"RAM Use" key:ShadSettingRuntimeStatsRAMKey defaultValue:YES]];
        [self.settingsStack addArrangedSubview:[self sliderRow:@"Stats Opacity"
                                                           key:ShadSettingRuntimeStatsOpacityKey
                                                  defaultValue:0.82
                                                           min:0.35
                                                           max:1.0
                                                        suffix:@"%"]];
        [self.settingsStack addArrangedSubview:[self segmentedRow:@"Stats Position"
                                                         options:@[ @"Left", @"Center", @"Right" ]
                                                             key:ShadSettingRuntimeStatsPositionKey
                                                    defaultIndex:0]];
        break;
    case 3:
        [self.settingsStack addArrangedSubview:[self settingsHeader:@"Audio Settings"]];
        [self.settingsStack addArrangedSubview:[self sliderRow:@"Master Volume"
                                                           key:ShadSettingMasterVolumeKey
                                                  defaultValue:0.78
                                                           min:0.0
                                                           max:1.0
                                                        suffix:@"%"]];
        [self.settingsStack addArrangedSubview:[self switchRow:@"UI Sound Effects"
                                                           key:ShadSettingUISoundEffectsKey
                                                  defaultValue:YES]];
        [self.settingsStack addArrangedSubview:[self switchRow:@"Orbit Sound Theme"
                                                           key:ShadSettingConsoleSoundThemeKey
                                                  defaultValue:NO]];
        [self.settingsStack addArrangedSubview:[self sliderRow:@"Click Volume"
                                                           key:ShadSettingClickVolumeKey
                                                  defaultValue:0.82
                                                           min:0.0
                                                           max:1.0
                                                        suffix:@"%"]];
        [self.settingsStack addArrangedSubview:[self segmentedRow:@"Output Mode"
                                                         options:@[ @"System", @"Headphones", @"Bluetooth" ]
                                                             key:ShadSettingAudioOutputKey
                                                    defaultIndex:0]];
        [self.settingsStack addArrangedSubview:[self settingsHeader:@"SDL Frontend"]];
        [self.settingsStack addArrangedSubview:[self segmentedRow:@"Audio Driver"
                                                         options:@[ @"CoreAudio", @"SDL Audio" ]
                                                             key:ShadSettingAudioDriverBackendKey
                                                    defaultIndex:0]];
        [self.settingsStack addArrangedSubview:[self segmentedRow:@"SDL Buffer Mode"
                                                         options:@[ @"Low Latency", @"Balanced", @"Safe Buffer" ]
                                                             key:ShadSettingSDLBufferModeKey
                                                    defaultIndex:1]];
        break;
    case 4:
        [self.settingsStack addArrangedSubview:[self settingsHeader:@"Input Controls"]];
        [self.settingsStack addArrangedSubview:[self settingRow:@"Touch Overlay Map" value:@"DualShock 4"]];
        [self.settingsStack addArrangedSubview:[self segmentedRow:@"Touch Overlay Startup"
                                                         options:@[ @"Hidden", @"Visible" ]
                                                             key:ShadSettingTouchOverlayStartupKey
                                                    defaultIndex:1]];
        [self.settingsStack addArrangedSubview:[self sliderRow:@"Overlay Opacity"
                                                           key:ShadSettingTouchOverlayOpacityKey
                                                  defaultValue:0.42
                                                           min:0.18
                                                           max:0.70
                                                        suffix:@"%"]];
        [self.settingsStack addArrangedSubview:[self switchRow:@"Bluetooth Controller"
                                                           key:ShadSettingBluetoothControllerKey
                                                  defaultValue:YES]];
        [self.settingsStack addArrangedSubview:[self switchRow:@"Controller Rumble"
                                                           key:ShadSettingControllerRumbleKey
                                                  defaultValue:YES]];
        [self.settingsStack addArrangedSubview:[self segmentedRow:@"Menu Navigation"
                                                         options:@[ @"D-Pad", @"Stick", @"Both" ]
                                                             key:ShadSettingMenuNavigationKey
                                                    defaultIndex:2]];
        [self.settingsStack addArrangedSubview:[self actionRow:@"Test Connected Controller" action:@selector(controllerTestPressed)]];
        break;
    default:
        [self.settingsStack addArrangedSubview:[self settingsHeader:@"Debug"]];
        [self.settingsStack addArrangedSubview:[self switchRow:@"Enable Shader Cache"
                                                           key:ShadSettingShaderCacheEnabledKey
                                                  defaultValue:YES]];
        [self.settingsStack addArrangedSubview:[self switchRow:@"Enable Pipeline Cache"
                                                           key:ShadSettingPipelineCacheEnabledKey
                                                  defaultValue:YES]];
        [self.settingsStack addArrangedSubview:[self switchRow:@"Precompile Shaders"
                                                           key:ShadSettingShaderPrecompileKey
                                                  defaultValue:NO]];
        [self.settingsStack addArrangedSubview:[self switchRow:@"Log Shader Cache Misses"
                                                           key:ShadSettingShaderMissLoggingKey
                                                  defaultValue:NO]];
        [self.settingsStack addArrangedSubview:[self switchRow:@"Dump Translated Shaders"
                                                           key:ShadSettingShaderDumpKey
                                                  defaultValue:NO]];
        [self.settingsStack addArrangedSubview:[self settingRow:@"Shader Cache Path" value:[self shaderCachePathDisplayString]]];
        [self.settingsStack addArrangedSubview:[self actionRow:@"Clear Shader Cache" action:@selector(clearShaderCachePressed)]];
        break;
    }

    self.settingsStack.alpha = 0.0;
    self.settingsStack.transform = CGAffineTransformMakeTranslation(18.0, 0.0);
    [UIView animateWithDuration:0.22
                          delay:0.0
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState |
                                UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         self.settingsStack.alpha = 1.0;
                         self.settingsStack.transform = CGAffineTransformIdentity;
                     }
                     completion:^(BOOL finished) {
                         self.selectedSettingsIndex = MIN(MAX(self.selectedSettingsIndex, 0),
                                                          (NSInteger)self.settingsFocusableControls.count - 1);
                         [self updateSettingsFocusAnimated:NO];
                     }];
}

- (UIView*)settingRow:(NSString*)title value:(NSString*)value {
    UIStackView* row = [[UIStackView alloc] init];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentCenter;
    row.spacing = 18.0;

    UILabel* label = [[UILabel alloc] init];
    label.text = title;
    label.textColor = [UIColor colorWithWhite:1.0 alpha:0.78];
    label.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightRegular];
    [row addArrangedSubview:label];

    UIView* spacer = [[UIView alloc] init];
    [row addArrangedSubview:spacer];

    if (value.length > 0) {
        UILabel* valueLabel = [[UILabel alloc] init];
        valueLabel.text = value;
        valueLabel.textColor = [UIColor colorWithRed:0.45 green:0.78 blue:1.0 alpha:1.0];
        valueLabel.font = [UIFont monospacedDigitSystemFontOfSize:15.0 weight:UIFontWeightMedium];
        [row addArrangedSubview:valueLabel];
    }
    return row;
}

- (NSString*)deviceModelIdentifier {
    size_t size = 0;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    if (size == 0) {
        return UIDevice.currentDevice.model ?: @"iPad";
    }
    NSMutableData* data = [NSMutableData dataWithLength:size];
    sysctlbyname("hw.machine", data.mutableBytes, &size, NULL, 0);
    NSString* identifier = [NSString stringWithUTF8String:(const char*)data.bytes];
    return identifier.length > 0 ? identifier : (UIDevice.currentDevice.model ?: @"iPad");
}

- (NSString*)systemVersionString {
    UIDevice* device = UIDevice.currentDevice;
    return [NSString stringWithFormat:@"%@ %@", device.systemName ?: @"iPadOS", device.systemVersion ?: @""];
}

- (NSString*)physicalMemoryString {
    double gb = (double)NSProcessInfo.processInfo.physicalMemory / (1024.0 * 1024.0 * 1024.0);
    return [NSString stringWithFormat:@"%.1f GB", gb];
}

- (NSString*)freeStorageString {
    NSURL* docs = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    NSDictionary* values = [docs resourceValuesForKeys:@[ NSURLVolumeAvailableCapacityForImportantUsageKey ] error:nil];
    NSNumber* bytes = values[NSURLVolumeAvailableCapacityForImportantUsageKey];
    if (bytes == nil) {
        NSDictionary* attrs = [NSFileManager.defaultManager attributesOfFileSystemForPath:NSHomeDirectory() error:nil];
        bytes = attrs[NSFileSystemFreeSize];
    }
    double gb = bytes.doubleValue / (1024.0 * 1024.0 * 1024.0);
    return [NSString stringWithFormat:@"%.1f GB", gb];
}

- (NSString*)metalDeviceName {
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    return device.name.length > 0 ? device.name : @"Metal unavailable";
}

- (NSString*)thermalStateString {
    switch (NSProcessInfo.processInfo.thermalState) {
    case NSProcessInfoThermalStateNominal:
        return @"Nominal";
    case NSProcessInfoThermalStateFair:
        return @"Fair";
    case NSProcessInfoThermalStateSerious:
        return @"Serious";
    case NSProcessInfoThermalStateCritical:
        return @"Critical";
    }
    return @"Unknown";
}

- (NSURL*)shaderCacheDirectoryURL {
    NSURL* caches = [NSFileManager.defaultManager URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask].firstObject;
    return [caches URLByAppendingPathComponent:@"ShaderCache" isDirectory:YES];
}

- (NSString*)shaderCachePathDisplayString {
    return [self shaderCacheDirectoryURL].path ?: @"Caches/ShaderCache";
}

- (void)clearShaderCachePressed {
    NSURL* cacheURL = [self shaderCacheDirectoryURL];
    NSError* error = nil;
    [NSFileManager.defaultManager removeItemAtURL:cacheURL error:&error];
    [NSFileManager.defaultManager createDirectoryAtURL:cacheURL
                          withIntermediateDirectories:YES
                                           attributes:nil
                                                error:nil];
    ShadPostUISound(error == nil ? @"accept" : @"back");
    NSLog(@"shadPS4 iOS: shader cache cleared at %@ error=%@", cacheURL.path, error);
}

- (void)controllerTestPressed {
    ShadPostUISound(@"accept");
    ShadControllerTestViewController* controllerTest = [[ShadControllerTestViewController alloc] init];
    controllerTest.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:controllerTest animated:YES completion:nil];
}

- (UIView*)actionRow:(NSString*)title action:(SEL)action {
    UIButton* button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    button.tintColor = UIColor.whiteColor;
    button.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.09];
    button.layer.cornerRadius = 5.0;
    button.contentEdgeInsets = UIEdgeInsetsMake(0.0, 14.0, 0.0, 14.0);
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightMedium];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [button.heightAnchor constraintEqualToConstant:42.0].active = YES;
    [self registerSettingsControl:button];
    return button;
}

- (BOOL)boolForKey:(NSString*)key defaultValue:(BOOL)defaultValue {
    id stored = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    return stored == nil ? defaultValue : [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

- (NSInteger)integerForKey:(NSString*)key defaultValue:(NSInteger)defaultValue {
    id stored = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    return stored == nil ? defaultValue : [[NSUserDefaults standardUserDefaults] integerForKey:key];
}

- (float)floatForKey:(NSString*)key defaultValue:(float)defaultValue {
    id stored = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    return stored == nil ? defaultValue : [[NSUserDefaults standardUserDefaults] floatForKey:key];
}

- (UIView*)switchRow:(NSString*)title key:(NSString*)key defaultValue:(BOOL)defaultValue {
    UIStackView* row = (UIStackView*)[self settingRow:title value:@""];
    UISwitch* toggle = [[UISwitch alloc] init];
    toggle.on = [self boolForKey:key defaultValue:defaultValue];
    toggle.accessibilityIdentifier = key;
    [toggle addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    [row addArrangedSubview:toggle];
    [self registerSettingsControl:toggle];
    return row;
}

- (UIView*)segmentedRow:(NSString*)title
                options:(NSArray<NSString*>*)options
                    key:(NSString*)key
           defaultIndex:(NSInteger)defaultIndex {
    UIStackView* row = (UIStackView*)[self settingRow:title value:@""];
    UISegmentedControl* segmented = [[UISegmentedControl alloc] initWithItems:options];
    segmented.accessibilityIdentifier = key;
    NSInteger selectedIndex = [self integerForKey:key defaultValue:defaultIndex];
    if ([key isEqualToString:ShadFrameLimitDefaultsKey]) {
        NSInteger fps = ShadClampedFrameLimit([self integerForKey:key defaultValue:30]);
        selectedIndex = fps <= 30 ? 0 : (fps >= 40 ? 2 : 1);
    }
    segmented.selectedSegmentIndex = MIN(MAX(selectedIndex, 0), (NSInteger)options.count - 1);
    [segmented addTarget:self action:@selector(segmentedChanged:) forControlEvents:UIControlEventValueChanged];
    [segmented.widthAnchor constraintGreaterThanOrEqualToConstant:220.0].active = YES;
    [row addArrangedSubview:segmented];
    [self registerSettingsControl:segmented];
    return row;
}

- (UIView*)sliderRow:(NSString*)title
                 key:(NSString*)key
        defaultValue:(float)defaultValue
                 min:(float)min
                 max:(float)max
              suffix:(NSString*)suffix {
    UIStackView* row = (UIStackView*)[self settingRow:title value:@""];
    UILabel* valueLabel = [[UILabel alloc] init];
    valueLabel.textColor = [UIColor colorWithRed:0.45 green:0.78 blue:1.0 alpha:1.0];
    valueLabel.font = [UIFont monospacedDigitSystemFontOfSize:15.0 weight:UIFontWeightMedium];
    valueLabel.textAlignment = NSTextAlignmentRight;
    [valueLabel.widthAnchor constraintEqualToConstant:62.0].active = YES;
    self.valueLabels[key] = valueLabel;

    UISlider* slider = [[UISlider alloc] init];
    slider.minimumValue = min;
    slider.maximumValue = max;
    slider.value = [self floatForKey:key defaultValue:defaultValue];
    slider.accessibilityIdentifier = key;
    slider.accessibilityHint = suffix;
    [slider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
    [slider.widthAnchor constraintEqualToConstant:210.0].active = YES;
    [row addArrangedSubview:valueLabel];
    [row addArrangedSubview:slider];
    [self updateSliderValueLabel:slider];
    [self registerSettingsControl:slider];
    return row;
}

- (void)switchChanged:(UISwitch*)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:sender.accessibilityIdentifier];
    if ([sender.accessibilityIdentifier isEqualToString:ShadSettingConsoleSoundThemeKey] && sender.on) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:ShadSettingUISoundEffectsKey];
        NSError* error = nil;
        AVAudioSession* session = AVAudioSession.sharedInstance;
        if (![session setCategory:AVAudioSessionCategoryPlayback
                      withOptions:AVAudioSessionCategoryOptionMixWithOthers
                            error:&error]) {
            NSLog(@"shadPS4 iOS: failed to configure settings audio session: %@", error);
        }
        error = nil;
        if (![session setActive:YES error:&error]) {
            NSLog(@"shadPS4 iOS: failed to activate settings audio session: %@", error);
        }
    }
    if ([sender.accessibilityIdentifier hasPrefix:@"ShadIOSSettingRuntimeStats"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:ShadRuntimeOverlaySettingsChangedNotification
                                                            object:nil];
    } else if ([sender.accessibilityIdentifier isEqualToString:ShadSettingAnimationIntensityKey]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:ShadDashboardBackgroundChangedNotification object:nil];
    }
    [[ShadIOSCoreBridge sharedBridge] applyUserDefaultsToCore];
    ShadPostUISound(@"accept");
}

- (void)segmentedChanged:(UISegmentedControl*)sender {
    NSString* key = sender.accessibilityIdentifier;
    if ([key isEqualToString:ShadFrameLimitDefaultsKey]) {
        NSArray<NSNumber*>* values = @[ @30, @35, @40 ];
        NSInteger fps = values[(NSUInteger)sender.selectedSegmentIndex].integerValue;
        [[NSUserDefaults standardUserDefaults] setInteger:fps forKey:key];
        [[NSNotificationCenter defaultCenter] postNotificationName:ShadFrameLimitChangedNotification
                                                            object:nil
                                                          userInfo:@{ @"fps" : @(fps) }];
    } else {
        [[NSUserDefaults standardUserDefaults] setInteger:sender.selectedSegmentIndex forKey:key];
        if ([key hasPrefix:@"ShadIOSSettingRuntimeStats"]) {
            [[NSNotificationCenter defaultCenter] postNotificationName:ShadRuntimeOverlaySettingsChangedNotification
                                                                object:nil];
        } else if ([key isEqualToString:ShadDashboardBackgroundModeDefaultsKey] ||
                   [key isEqualToString:ShadDashboardDynamicStyleDefaultsKey] ||
                   [key isEqualToString:ShadSettingAnimationEffectKey]) {
            [[NSNotificationCenter defaultCenter] postNotificationName:ShadDashboardBackgroundChangedNotification
                                                                object:nil];
        }
    }
    [[ShadIOSCoreBridge sharedBridge] applyUserDefaultsToCore];
    ShadPostUISound(@"accept");
}

- (void)sliderChanged:(UISlider*)sender {
    [[NSUserDefaults standardUserDefaults] setFloat:sender.value forKey:sender.accessibilityIdentifier];
    [self updateSliderValueLabel:sender];
    if ([sender.accessibilityIdentifier hasPrefix:@"ShadIOSSettingRuntimeStats"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:ShadRuntimeOverlaySettingsChangedNotification
                                                            object:nil];
    } else if ([sender.accessibilityIdentifier isEqualToString:ShadSettingAnimationIntensityKey]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:ShadDashboardBackgroundChangedNotification
                                                            object:nil];
    }
    [[ShadIOSCoreBridge sharedBridge] applyUserDefaultsToCore];
    ShadPostUISound(@"move");
}

- (void)updateSliderValueLabel:(UISlider*)slider {
    UILabel* label = self.valueLabels[slider.accessibilityIdentifier];
    if (label == nil) {
        return;
    }
    if ([slider.accessibilityHint isEqualToString:@"%"]) {
        label.text = [NSString stringWithFormat:@"%d%%", (int)lroundf(slider.value * 100.0f)];
    } else {
        label.text = [NSString stringWithFormat:@"%.2f", slider.value];
    }
}

- (void)installSettingsControllerNavigation {
    [self.settingsControllerPollLink invalidate];
    self.settingsControllerPollLink =
        [CADisplayLink displayLinkWithTarget:self selector:@selector(pollSettingsController)];
    self.settingsControllerPollLink.preferredFramesPerSecond = 30;
    [self.settingsControllerPollLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    [self updateSettingsFocusAnimated:NO];
}

- (GCExtendedGamepad*)settingsGamepad {
    for (GCController* controller in GCController.controllers) {
        if (controller.extendedGamepad != nil) {
            return controller.extendedGamepad;
        }
    }
    return nil;
}

- (void)pollSettingsController {
    GCExtendedGamepad* gamepad = [self settingsGamepad];
    if (gamepad == nil) {
        return;
    }

    const BOOL aPressed = gamepad.buttonA.isPressed;
    const BOOL bPressed = gamepad.buttonB.isPressed;
    if (aPressed && !self.settingsControllerAWasPressed) {
        [self activateFocusedSettingsControl];
    }
    if (bPressed && !self.settingsControllerBWasPressed) {
        [self dismissSettingsPressed];
    }
    self.settingsControllerAWasPressed = aPressed;
    self.settingsControllerBWasPressed = bPressed;

    const CFTimeInterval now = CACurrentMediaTime();
    if (now - self.lastSettingsControllerMoveTime < 0.16) {
        return;
    }

    const float y = fabsf(gamepad.leftThumbstick.yAxis.value) > fabsf(gamepad.dpad.yAxis.value)
                        ? gamepad.leftThumbstick.yAxis.value
                        : gamepad.dpad.yAxis.value;
    const float x = fabsf(gamepad.leftThumbstick.xAxis.value) > fabsf(gamepad.dpad.xAxis.value)
                        ? gamepad.leftThumbstick.xAxis.value
                        : gamepad.dpad.xAxis.value;

    if (y > 0.55f) {
        [self moveSettingsFocus:-1];
        self.lastSettingsControllerMoveTime = now;
    } else if (y < -0.55f) {
        [self moveSettingsFocus:1];
        self.lastSettingsControllerMoveTime = now;
    } else if (x > 0.55f || x < -0.55f) {
        [self adjustFocusedSettingsControl:x > 0.0f ? 1 : -1];
        self.lastSettingsControllerMoveTime = now;
    }
}

- (UIControl*)focusedSettingsControl {
    if (self.settingsFocusableControls.count == 0) {
        return nil;
    }
    self.selectedSettingsIndex =
        MIN(MAX(self.selectedSettingsIndex, 0), (NSInteger)self.settingsFocusableControls.count - 1);
    return self.settingsFocusableControls[(NSUInteger)self.selectedSettingsIndex];
}

- (void)activateFocusedSettingsControl {
    UIControl* control = [self focusedSettingsControl];
    if (control == nil) {
        return;
    }

    if ([control isKindOfClass:UISwitch.class]) {
        UISwitch* toggle = (UISwitch*)control;
        [toggle setOn:!toggle.on animated:YES];
        [self switchChanged:toggle];
        return;
    }
    if ([control isKindOfClass:UISegmentedControl.class]) {
        [self adjustFocusedSettingsControl:1];
        return;
    }
    if ([control isKindOfClass:UISlider.class]) {
        [self adjustFocusedSettingsControl:1];
        return;
    }
    [control sendActionsForControlEvents:UIControlEventTouchUpInside];
}

- (void)adjustFocusedSettingsControl:(NSInteger)delta {
    UIControl* control = [self focusedSettingsControl];
    if ([control isKindOfClass:UISegmentedControl.class]) {
        UISegmentedControl* segmented = (UISegmentedControl*)control;
        NSInteger next = segmented.selectedSegmentIndex + delta;
        next = MIN(MAX(next, 0), (NSInteger)segmented.numberOfSegments - 1);
        if (next != segmented.selectedSegmentIndex) {
            segmented.selectedSegmentIndex = next;
            [self segmentedChanged:segmented];
        } else {
            ShadPostUISound(@"move");
        }
        return;
    }
    if ([control isKindOfClass:UISlider.class]) {
        UISlider* slider = (UISlider*)control;
        const float step = MAX((slider.maximumValue - slider.minimumValue) / 10.0f, 0.01f);
        slider.value = MIN(MAX(slider.value + (float)delta * step, slider.minimumValue), slider.maximumValue);
        [self sliderChanged:slider];
        return;
    }
}

- (void)dismissSettingsPressed {
    [self.settingsControllerPollLink invalidate];
    self.settingsControllerPollLink = nil;
    ShadPostUISound(@"back");
    [UIView animateWithDuration:0.20
                          delay:0.0
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState |
                                UIViewAnimationOptionCurveEaseIn
                     animations:^{
                         self.sidebarView.transform = CGAffineTransformMakeTranslation(-36.0, 0.0);
                         self.detailsView.transform = CGAffineTransformMakeTranslation(24.0, 0.0);
                         self.sidebarView.alpha = 0.0;
                         self.detailsView.alpha = 0.0;
                         self.view.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.0];
                     }
                     completion:^(BOOL finished) {
                         [self dismissViewControllerAnimated:NO completion:nil];
                     }];
}

- (void)changeBackgroundPressed {
    ShadPostUISound(@"accept");
    PHPickerConfiguration* config = [[PHPickerConfiguration alloc] init];
    config.selectionLimit = 1;
    config.filter = [PHPickerFilter imagesFilter];
    PHPickerViewController* picker = [[PHPickerViewController alloc] initWithConfiguration:config];
    picker.delegate = self;
    picker.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)resetBackgroundPressed {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:ShadDashboardBackgroundDefaultsKey];
    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:ShadDashboardBackgroundModeDefaultsKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:ShadDashboardBackgroundChangedNotification object:nil];
    ShadPostUISound(@"back");
}

- (void)picker:(PHPickerViewController*)picker didFinishPicking:(NSArray<PHPickerResult*>*)results {
    [picker dismissViewControllerAnimated:YES completion:nil];
    PHPickerResult* result = results.firstObject;
    if (result == nil) {
        return;
    }

    if (![result.itemProvider canLoadObjectOfClass:UIImage.class]) {
        NSLog(@"shadPS4 iOS: selected photo cannot be loaded as UIImage.");
        return;
    }

    [result.itemProvider loadObjectOfClass:UIImage.class
                         completionHandler:^(__kindof id<NSItemProviderReading> object, NSError* error) {
                             if (error != nil || ![object isKindOfClass:UIImage.class]) {
                                 NSLog(@"shadPS4 iOS: failed to load dashboard background from Photos: %@", error);
                                 return;
                             }

                             UIImage* image = (UIImage*)object;
                             NSData* data = UIImageJPEGRepresentation(image, 0.88);
                             if (data == nil) {
                                 data = UIImagePNGRepresentation(image);
                             }
                             if (data == nil) {
                                 NSLog(@"shadPS4 iOS: failed to encode dashboard background image.");
                                 return;
                             }

                             dispatch_async(dispatch_get_main_queue(), ^{
                                 NSFileManager* fm = NSFileManager.defaultManager;
                                 NSURL* docs = [fm URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
                                 NSURL* bgDir = [docs URLByAppendingPathComponent:@"Backgrounds" isDirectory:YES];
                                 NSError* writeError = nil;
                                 [fm createDirectoryAtURL:bgDir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:&writeError];
                                 NSURL* destination = [bgDir URLByAppendingPathComponent:@"dashboard-background.jpg"];
                                 if ([data writeToURL:destination options:NSDataWritingAtomic error:&writeError]) {
                                     [[NSUserDefaults standardUserDefaults] setObject:destination.path
                                                                               forKey:ShadDashboardBackgroundDefaultsKey];
                                     [[NSUserDefaults standardUserDefaults] setInteger:1
                                                                                forKey:ShadDashboardBackgroundModeDefaultsKey];
                                     [[NSNotificationCenter defaultCenter]
                                         postNotificationName:ShadDashboardBackgroundChangedNotification
                                                       object:nil];
                                     ShadPostUISound(@"accept");
                                 } else {
                                     NSLog(@"shadPS4 iOS: failed to save dashboard background: %@", writeError);
                                 }
                             });
                         }];
}

@end

@implementation ShadViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = UIColor.blackColor;
    self.frameLimit = [self savedFrameLimit];
    self.selectedGameIndex = 0;
    self.topMenuIndex = 0;
    self.topMenuFocused = NO;
    self.touchControlsVisible = YES;
    self.games = [NSMutableArray array];
    self.gameButtons = [NSMutableArray array];
    self.topMenuButtons = [NSMutableArray array];
    self.virtualControlButtons = [NSMutableDictionary dictionary];
    self.pressedVirtualControls = [NSMutableSet set];

    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (device == nil) {
        NSLog(@"shadPS4 iOS: failed to create Metal device.");
        [self installFallbackLabel:@"Metal device unavailable"];
        return;
    }

    [self installMetalViewWithDevice:device];
    [[ShadIOSCoreBridge sharedBridge] prepareRuntimeEnvironment];
    [[ShadIOSCoreBridge sharedBridge] attachMetalView:self.metalView];
    [self installAudioSessionAndSounds];
    [self loadGameLibrary];
    [self installDashboard];
    [self installTouchOverlay];
    [self refreshGameRow];
    [self updateClock];
    [self applySavedDashboardBackground];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(dashboardBackgroundChanged:)
                                                 name:ShadDashboardBackgroundChangedNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(frameLimitChanged:)
                                                 name:ShadFrameLimitChangedNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playUISoundNotification:)
                                                 name:ShadPlayUISoundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(runtimeOverlaySettingsChanged:)
                                                 name:ShadRuntimeOverlaySettingsChangedNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(profileChanged:)
                                                 name:ShadProfileChangedNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(thermalStateChanged:)
                                                 name:NSProcessInfoThermalStateDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(memoryWarning:)
                                                 name:UIApplicationDidReceiveMemoryWarningNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(screenDidConnect:)
                                                 name:UIScreenDidConnectNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(screenDidDisconnect:)
                                                 name:UIScreenDidDisconnectNotification
                                               object:nil];

    self.clockTimer = [NSTimer scheduledTimerWithTimeInterval:15.0
                                                       target:self
                                                     selector:@selector(updateClock)
                                                     userInfo:nil
                                                      repeats:YES];

    [self installControllerSupport];
    [self installExternalDisplaySupport];
    NSLog(@"shadPS4 iOS: PS4-style dashboard ready. CAMetalLayer=%@", self.metalView.layer);
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.clockTimer invalidate];
    [self.runtimeStatsTimer invalidate];
    [self.controllerPollLink invalidate];
    self.metalView.paused = NO;
    [self teardownExternalDisplayWindow];
    [super dealloc];
}

- (void)thermalStateChanged:(NSNotification*)notification {
    self.lastThermalState = NSProcessInfo.processInfo.thermalState;
    [[ShadIOSCoreBridge sharedBridge] applyThermalState:self.lastThermalState];
    self.frameLimit = [ShadIOSCoreBridge sharedBridge].activeFrameLimit;
    self.metalView.preferredFramesPerSecond = self.frameLimit;
    if (self.externalDisplayActive && self.dashboardView.hidden) {
        [self updateExternalRenderSurfaceSize];
    }
    NSLog(@"shadPS4 iOS: thermal state changed to %ld", (long)self.lastThermalState);
}

- (void)memoryWarning:(NSNotification*)notification {
    [[ShadIOSCoreBridge sharedBridge] releaseAllInputs];
    self.statusLabel.text = @"Memory pressure detected - trimming runtime pressure";
    NSLog(@"shadPS4 iOS: memory warning received; released transient input state.");
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!self.didShowBootIntro) {
        self.didShowBootIntro = YES;
        [self showStartupIntro];
    } else {
        [self presentFirstLaunchSetupIfNeeded];
    }
}

- (void)presentFirstLaunchSetupIfNeeded {
    if (self.presentedViewController != nil || self.dashboardView.hidden) {
        return;
    }
    if (ShadMutableProfiles().count == 0 || ShadCurrentUserID().length == 0) {
        [self presentUserSelectionAnimated:YES];
        return;
    }
    if ([[NSUserDefaults standardUserDefaults] boolForKey:ShadFirstLaunchCompleteDefaultsKey]) {
        return;
    }
    ShadOnboardingViewController* onboarding = [[ShadOnboardingViewController alloc] init];
    onboarding.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:onboarding animated:YES completion:nil];
}

- (void)presentUserSelectionAnimated:(BOOL)animated {
    ShadUserSelectionViewController* users = [[ShadUserSelectionViewController alloc] init];
    users.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:users animated:animated completion:nil];
}

- (void)profileChanged:(NSNotification*)notification {
    [self updateProfileButton];
    if (ShadCurrentUserID().length == 0 && self.presentedViewController == nil && !self.dashboardView.hidden) {
        [self presentUserSelectionAnimated:YES];
    }
}

- (NSInteger)savedFrameLimit {
    NSInteger stored = [[NSUserDefaults standardUserDefaults] integerForKey:ShadFrameLimitDefaultsKey];
    return ShadClampedFrameLimit(stored);
}

- (void)frameLimitChanged:(NSNotification*)notification {
    NSNumber* fps = notification.userInfo[@"fps"];
    self.frameLimit = ShadClampedFrameLimit(fps != nil ? fps.integerValue : [self savedFrameLimit]);
    self.metalView.preferredFramesPerSecond = self.frameLimit;
    self.controllerPollLink.preferredFramesPerSecond = MIN((NSInteger)30, self.frameLimit);
    [[ShadIOSCoreBridge sharedBridge] applyUserDefaultsToCore];
    if (self.externalDisplayActive && self.dashboardView.hidden) {
        [self updateExternalRenderSurfaceSize];
    }
    NSLog(@"shadPS4 iOS: frame limit changed to %ld FPS", (long)self.frameLimit);
}

- (void)playUISoundNotification:(NSNotification*)notification {
    NSString* kind = notification.userInfo[@"kind"];
    if ([kind isEqualToString:@"accept"]) {
        [self playAcceptSound];
    } else if ([kind isEqualToString:@"back"]) {
        [self playBackSound];
    } else {
        [self playMoveSound];
    }
}

- (void)runtimeOverlaySettingsChanged:(NSNotification*)notification {
    [self updatePerformanceOverlayStyle];
    [self updatePerformanceOverlayVisibility];
    [self updatePerformanceOverlayText];
}

- (BOOL)prefersHomeIndicatorAutoHidden {
    return YES;
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscape;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return UIInterfaceOrientationLandscapeRight;
}

- (NSInteger)dashboardMotionLevel {
    id stored = [[NSUserDefaults standardUserDefaults] objectForKey:ShadSettingAnimationEffectKey];
    return stored == nil ? 2 : [[NSUserDefaults standardUserDefaults] integerForKey:ShadSettingAnimationEffectKey];
}

- (CGFloat)dashboardEffectIntensity {
    id stored = [[NSUserDefaults standardUserDefaults] objectForKey:ShadSettingAnimationIntensityKey];
    CGFloat intensity = stored == nil ? 0.72 : [[NSUserDefaults standardUserDefaults] floatForKey:ShadSettingAnimationIntensityKey];
    return MIN(MAX(intensity, 0.0), 1.0);
}

- (NSTimeInterval)dashboardAnimationDuration:(NSTimeInterval)base {
    NSInteger motion = [self dashboardMotionLevel];
    if (motion == 0) {
        return 0.0;
    }
    CGFloat intensity = [self dashboardEffectIntensity];
    CGFloat multiplier = motion == 1 ? 0.82 : (motion == 3 ? 1.24 : 1.0);
    return base * multiplier * (0.82 + intensity * 0.34);
}

- (void)animateDashboardChanges:(BOOL)animated
                        baseTime:(NSTimeInterval)baseTime
                         damping:(CGFloat)damping
                         changes:(void (^)(void))changes
                      completion:(void (^)(BOOL finished))completion {
    if (!animated || [self dashboardMotionLevel] == 0) {
        changes();
        if (completion != nil) {
            completion(YES);
        }
        return;
    }

    [UIView animateWithDuration:[self dashboardAnimationDuration:baseTime]
                          delay:0.0
         usingSpringWithDamping:damping
          initialSpringVelocity:0.12
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState |
                                UIViewAnimationOptionCurveEaseInOut
                     animations:changes
                     completion:completion];
}

- (void)installMetalViewWithDevice:(id<MTLDevice>)device {
    self.metalView = [[MTKView alloc] initWithFrame:self.view.bounds device:device];
    self.metalView.translatesAutoresizingMaskIntoConstraints = NO;
    self.metalView.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    self.metalView.depthStencilPixelFormat = MTLPixelFormatDepth32Float;
    self.metalView.framebufferOnly = NO;
    self.metalView.enableSetNeedsDisplay = NO;
    self.metalView.paused = NO;
    self.metalView.preferredFramesPerSecond = self.frameLimit;
    self.metalView.delegate = self;
    [self.view addSubview:self.metalView];

    self.metalViewConstraints = @[
        [self.metalView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.metalView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.metalView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.metalView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ];
    [NSLayoutConstraint activateConstraints:self.metalViewConstraints];
}

- (void)installExternalDisplaySupport {
    for (UIScreen* screen in UIScreen.screens) {
        if (screen != UIScreen.mainScreen) {
            [self activateExternalDisplayOnScreen:screen];
            break;
        }
    }
}

- (void)screenDidConnect:(NSNotification*)notification {
    UIScreen* screen = notification.object;
    if (![screen isKindOfClass:UIScreen.class] || screen == UIScreen.mainScreen) {
        return;
    }
    [self activateExternalDisplayOnScreen:screen];
}

- (void)screenDidDisconnect:(NSNotification*)notification {
    UIScreen* screen = notification.object;
    if (screen == self.externalDisplayScreen) {
        [self teardownExternalDisplayWindow];
        [self attachMetalViewToPrimaryDisplay];
        [self updateExternalDisplayModeForGameState];
        self.statusLabel.text = @"External display disconnected";
        NSLog(@"shadPS4 iOS external display: disconnected");
    }
}

- (void)activateExternalDisplayOnScreen:(UIScreen*)screen {
    if (screen == nil || screen == UIScreen.mainScreen) {
        return;
    }
    if (self.externalDisplayWindow != nil && self.externalDisplayScreen == screen) {
        [self updateExternalDisplayModeForGameState];
        return;
    }

    [self teardownExternalDisplayWindow];

    self.externalDisplayScreen = screen;
    self.externalDisplayViewController = [[ShadExternalDisplayViewController alloc] init];
    UIWindow* window = [[UIWindow alloc] initWithFrame:screen.bounds];
    window.screen = screen;
    window.backgroundColor = UIColor.blackColor;
    window.rootViewController = self.externalDisplayViewController;
    window.hidden = NO;
    self.externalDisplayWindow = window;
    self.externalDisplayActive = YES;

    [self.externalDisplayViewController loadViewIfNeeded];
    [self.externalDisplayViewController updateForScreen:screen activeGame:self.dashboardView.hidden];
    [self updateExternalDisplayModeForGameState];
    NSLog(@"shadPS4 iOS external display: connected bounds=%@ scale=%.2f native=%@",
          NSStringFromCGRect(screen.bounds), screen.scale, NSStringFromCGRect(screen.nativeBounds));
}

- (void)teardownExternalDisplayWindow {
    self.externalDisplayWindow.hidden = YES;
    self.externalDisplayWindow.rootViewController = nil;
    self.externalDisplayWindow = nil;
    self.externalDisplayViewController = nil;
    self.externalDisplayScreen = nil;
    self.externalDisplayActive = NO;
}

- (CGSize)drawableSizeForScreen:(UIScreen*)screen {
    if (screen == nil) {
        screen = UIScreen.mainScreen;
    }
    CGSize size = CGSizeMake(CGRectGetWidth(screen.bounds) * screen.scale,
                             CGRectGetHeight(screen.bounds) * screen.scale);
    if (!CGSizeEqualToSize(screen.nativeBounds.size, CGSizeZero)) {
        size = screen.nativeBounds.size;
    }
    return CGSizeMake(MAX(size.width, 1.0), MAX(size.height, 1.0));
}

- (void)placeMetalViewInContainer:(UIView*)container screen:(UIScreen*)screen nativeMatch:(BOOL)nativeMatch {
    if (container == nil || self.metalView == nil) {
        return;
    }
    [NSLayoutConstraint deactivateConstraints:self.metalViewConstraints];
    [self.metalView removeFromSuperview];
    self.metalView.translatesAutoresizingMaskIntoConstraints = NO;
    [container insertSubview:self.metalView atIndex:0];
    self.metalViewConstraints = @[
        [self.metalView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [self.metalView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [self.metalView.topAnchor constraintEqualToAnchor:container.topAnchor],
        [self.metalView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
    ];
    [NSLayoutConstraint activateConstraints:self.metalViewConstraints];

    self.metalView.preferredFramesPerSecond = self.frameLimit;
    self.metalView.contentScaleFactor = screen.scale;
    self.metalView.paused = NO;
    [[ShadIOSCoreBridge sharedBridge] attachMetalView:self.metalView];
    if (nativeMatch) {
        CGSize drawableSize = [self drawableSizeForScreen:screen];
        self.metalView.drawableSize = drawableSize;
        [[ShadIOSCoreBridge sharedBridge] updateRenderSurfaceDrawableSize:drawableSize];
    } else {
        [[ShadIOSCoreBridge sharedBridge] applyUserDefaultsToCore];
    }
}

- (void)attachMetalViewToExternalDisplay {
    if (self.externalDisplayViewController.renderContainerView == nil || self.externalDisplayScreen == nil) {
        return;
    }
    [self.externalDisplayViewController updateForScreen:self.externalDisplayScreen activeGame:YES];
    [self placeMetalViewInContainer:self.externalDisplayViewController.renderContainerView
                             screen:self.externalDisplayScreen
                       nativeMatch:YES];
}

- (void)updateExternalRenderSurfaceSize {
    if (self.externalDisplayScreen == nil || self.metalView.superview != self.externalDisplayViewController.renderContainerView) {
        return;
    }
    CGSize drawableSize = [self drawableSizeForScreen:self.externalDisplayScreen];
    self.metalView.preferredFramesPerSecond = self.frameLimit;
    self.metalView.drawableSize = drawableSize;
    [[ShadIOSCoreBridge sharedBridge] updateRenderSurfaceDrawableSize:drawableSize];
}

- (void)attachMetalViewToPrimaryDisplay {
    [self placeMetalViewInContainer:self.view screen:UIScreen.mainScreen nativeMatch:NO];
    if (self.dashboardView != nil) {
        [self.view bringSubviewToFront:self.dashboardView];
    }
    if (self.touchOverlay != nil) {
        [self.view bringSubviewToFront:self.touchOverlay];
    }
    if (self.overlayMenuView != nil) {
        [self.view bringSubviewToFront:self.overlayMenuView];
    }
    if (self.runtimeMenuButton != nil) {
        [self.view bringSubviewToFront:self.runtimeMenuButton];
    }
    if (self.performanceOverlayView != nil) {
        [self.view bringSubviewToFront:self.performanceOverlayView];
    }
}

- (void)updateExternalDisplayModeForGameState {
    const BOOL inGame = self.dashboardView.hidden;
    if (self.externalDisplayWindow == nil) {
        self.externalDisplayActive = NO;
        return;
    }
    self.externalDisplayActive = YES;
    [self.externalDisplayViewController updateForScreen:self.externalDisplayScreen activeGame:inGame];
    if (inGame) {
        [self attachMetalViewToExternalDisplay];
        self.statusLabel.text = @"External display active - iPad is controller";
    } else {
        [self attachMetalViewToPrimaryDisplay];
        self.statusLabel.text = @"External display ready";
    }
}

- (void)installAudioSessionAndSounds {
    [self ensureUISoundAudioSessionActive];

    self.moveSoundPlayer = [self audioPlayerWithFrequency:880.0 duration:0.045 gain:0.42];
    self.acceptSoundPlayer = [self audioPlayerWithFrequency:1174.0 duration:0.070 gain:0.48];
    self.backSoundPlayer = [self audioPlayerWithFrequency:523.0 duration:0.055 gain:0.38];
    self.consoleMoveSoundPlayer = [self audioPlayerWithData:[self consoleStyleWavDataForKind:@"move"]];
    self.consoleAcceptSoundPlayer = [self audioPlayerWithData:[self consoleStyleWavDataForKind:@"accept"]];
    self.consoleBackSoundPlayer = [self audioPlayerWithData:[self consoleStyleWavDataForKind:@"back"]];
    self.consoleStartupSoundPlayer = [self audioPlayerWithData:[self consoleStyleWavDataForKind:@"startup"]];
}

- (void)ensureUISoundAudioSessionActive {
    NSError* error = nil;
    AVAudioSession* session = AVAudioSession.sharedInstance;
    if (![session setCategory:AVAudioSessionCategoryPlayback
                  withOptions:AVAudioSessionCategoryOptionMixWithOthers
                        error:&error]) {
        NSLog(@"shadPS4 iOS: failed to configure playback audio session: %@", error);
    }
    error = nil;
    if (![session setActive:YES error:&error]) {
        NSLog(@"shadPS4 iOS: failed to activate audio session: %@", error);
    }
}

- (AVAudioPlayer*)audioPlayerWithFrequency:(double)frequency duration:(double)duration gain:(double)gain {
    NSData* data = [self wavToneDataWithFrequency:frequency duration:duration gain:gain];
    return [self audioPlayerWithData:data];
}

- (AVAudioPlayer*)audioPlayerWithData:(NSData*)data {
    NSError* error = nil;
    AVAudioPlayer* player = [[AVAudioPlayer alloc] initWithData:data error:&error];
    if (player == nil) {
        NSLog(@"shadPS4 iOS: failed to create UI sound player: %@", error);
        return nil;
    }
    player.numberOfLoops = 0;
    player.volume = 1.0;
    [player prepareToPlay];
    return player;
}

- (BOOL)consoleSoundThemeEnabled {
    id stored = [[NSUserDefaults standardUserDefaults] objectForKey:ShadSettingConsoleSoundThemeKey];
    return stored != nil && [[NSUserDefaults standardUserDefaults] boolForKey:ShadSettingConsoleSoundThemeKey];
}

- (NSData*)wavToneDataWithFrequency:(double)frequency duration:(double)duration gain:(double)gain {
    const uint32_t sampleRate = 44100;
    const uint16_t channels = 1;
    const uint16_t bitsPerSample = 16;
    const uint32_t sampleCount = (uint32_t)(sampleRate * duration);
    const uint32_t byteRate = sampleRate * channels * bitsPerSample / 8;
    const uint16_t blockAlign = channels * bitsPerSample / 8;
    const uint32_t dataSize = sampleCount * blockAlign;

    NSMutableData* data = [NSMutableData dataWithCapacity:44 + dataSize];
    [data appendBytes:"RIFF" length:4];
    ShadAppendLE32(data, 36 + dataSize);
    [data appendBytes:"WAVE" length:4];
    [data appendBytes:"fmt " length:4];
    ShadAppendLE32(data, 16);
    ShadAppendLE16(data, 1);
    ShadAppendLE16(data, channels);
    ShadAppendLE32(data, sampleRate);
    ShadAppendLE32(data, byteRate);
    ShadAppendLE16(data, blockAlign);
    ShadAppendLE16(data, bitsPerSample);
    [data appendBytes:"data" length:4];
    ShadAppendLE32(data, dataSize);

    for (uint32_t i = 0; i < sampleCount; i++) {
        double t = (double)i / (double)sampleRate;
        double envelope = 1.0 - ((double)i / (double)sampleCount);
        int16_t sample = (int16_t)(sin(2.0 * M_PI * frequency * t) * gain * envelope * 32767.0);
        ShadAppendLE16(data, (uint16_t)sample);
    }
    return data;
}

- (NSData*)consoleStyleWavDataForKind:(NSString*)kind {
    const uint32_t sampleRate = 44100;
    const uint16_t channels = 1;
    const uint16_t bitsPerSample = 16;
    double duration = [kind isEqualToString:@"startup"] ? 1.24 : ([kind isEqualToString:@"accept"] ? 0.18 : 0.13);
    const uint32_t sampleCount = (uint32_t)(sampleRate * duration);
    const uint32_t byteRate = sampleRate * channels * bitsPerSample / 8;
    const uint16_t blockAlign = channels * bitsPerSample / 8;
    const uint32_t dataSize = sampleCount * blockAlign;

    NSMutableData* data = [NSMutableData dataWithCapacity:44 + dataSize];
    [data appendBytes:"RIFF" length:4];
    ShadAppendLE32(data, 36 + dataSize);
    [data appendBytes:"WAVE" length:4];
    [data appendBytes:"fmt " length:4];
    ShadAppendLE32(data, 16);
    ShadAppendLE16(data, 1);
    ShadAppendLE16(data, channels);
    ShadAppendLE32(data, sampleRate);
    ShadAppendLE32(data, byteRate);
    ShadAppendLE16(data, blockAlign);
    ShadAppendLE16(data, bitsPerSample);
    [data appendBytes:"data" length:4];
    ShadAppendLE32(data, dataSize);

    const BOOL startup = [kind isEqualToString:@"startup"];
    const BOOL accept = [kind isEqualToString:@"accept"];
    const BOOL back = [kind isEqualToString:@"back"];
    const double baseA = startup ? 196.0 : (accept ? 784.0 : (back ? 392.0 : 622.25));
    const double baseB = startup ? 293.66 : (accept ? 1174.66 : (back ? 329.63 : 987.77));
    const double baseC = startup ? 392.0 : (accept ? 1567.98 : (back ? 246.94 : 1318.51));
    const double gain = startup ? 0.24 : 0.34;

    for (uint32_t i = 0; i < sampleCount; i++) {
        double t = (double)i / (double)sampleRate;
        double progress = (double)i / MAX((double)sampleCount - 1.0, 1.0);
        double attack = MIN(progress / (startup ? 0.18 : 0.08), 1.0);
        double decay = pow(MAX(1.0 - progress, 0.0), startup ? 1.55 : 2.15);
        double envelope = attack * decay;
        double shimmer = sin(2.0 * M_PI * (startup ? 0.72 : 7.5) * t) * (startup ? 8.0 : 18.0);
        double sweep = startup ? (1.0 + progress * 0.028) : (1.0 + (accept ? progress * 0.08 : -progress * 0.05));
        double sampleValue =
            sin(2.0 * M_PI * (baseA * sweep + shimmer) * t) * 0.44 +
            sin(2.0 * M_PI * (baseB * sweep) * t) * 0.34 +
            sin(2.0 * M_PI * (baseC * sweep) * t) * 0.18;
        if (startup) {
            sampleValue += sin(2.0 * M_PI * 587.33 * t) * 0.10 * sin(M_PI * progress);
        }
        sampleValue = tanh(sampleValue * 1.18) * gain * envelope;
        int16_t sample = (int16_t)(MAX(MIN(sampleValue, 1.0), -1.0) * 32767.0);
        ShadAppendLE16(data, (uint16_t)sample);
    }
    return data;
}

- (void)showStartupIntro {
    UIView* intro = [[UIView alloc] initWithFrame:self.view.bounds];
    intro.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    intro.backgroundColor = [UIColor colorWithRed:0.0 green:0.02 blue:0.06 alpha:1.0];
    intro.userInteractionEnabled = YES;
    intro.alpha = 1.0;
    self.bootIntroView = intro;
    [self.view addSubview:intro];

    CAGradientLayer* background = [CAGradientLayer layer];
    background.frame = intro.bounds;
    background.colors = @[
        (__bridge id)[UIColor colorWithRed:0.00 green:0.02 blue:0.06 alpha:1.0].CGColor,
        (__bridge id)[UIColor colorWithRed:0.00 green:0.08 blue:0.20 alpha:1.0].CGColor,
        (__bridge id)[UIColor colorWithRed:0.00 green:0.16 blue:0.34 alpha:1.0].CGColor,
    ];
    background.startPoint = CGPointMake(0.0, 0.0);
    background.endPoint = CGPointMake(1.0, 1.0);
    background.name = @"StartupIntroGradient";
    [intro.layer addSublayer:background];

    ShadDashboardWavesView* waves = [[ShadDashboardWavesView alloc] initWithFrame:intro.bounds];
    waves.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    waves.alpha = 0.0;
    waves.amplitudeScale = 1.2;
    waves.speed = 0.58;
    [intro addSubview:waves];

    UIView* lightSweep = [[UIView alloc] init];
    lightSweep.translatesAutoresizingMaskIntoConstraints = NO;
    lightSweep.alpha = 0.0;
    lightSweep.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.16];
    lightSweep.transform = CGAffineTransformMakeRotation(-0.25);
    [intro addSubview:lightSweep];

    UIImageView* mark = [[UIImageView alloc] initWithImage:[OrbitIconRenderer orbitConsoleIconWithSize:CGSizeMake(180.0, 180.0)]];
    mark.translatesAutoresizingMaskIntoConstraints = NO;
    mark.contentMode = UIViewContentModeScaleAspectFit;
    mark.layer.shadowColor = [UIColor colorWithRed:0.46 green:0.76 blue:1.0 alpha:1.0].CGColor;
    mark.layer.shadowOpacity = 0.0;
    mark.layer.shadowRadius = 28.0;
    mark.layer.shadowOffset = CGSizeZero;
    mark.alpha = 0.0;
    mark.transform = CGAffineTransformMakeScale(0.84, 0.84);
    [intro addSubview:mark];

    UILabel* title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"Orbit Console";
    title.textColor = UIColor.whiteColor;
    title.font = [UIFont systemFontOfSize:34.0 weight:UIFontWeightLight];
    title.alpha = 0.0;
    [intro addSubview:title];

    UILabel* subtitle = [[UILabel alloc] init];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.text = @"Starting system";
    subtitle.textColor = [UIColor colorWithWhite:1.0 alpha:0.58];
    subtitle.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightRegular];
    subtitle.alpha = 0.0;
    [intro addSubview:subtitle];

    [NSLayoutConstraint activateConstraints:@[
        [lightSweep.widthAnchor constraintEqualToAnchor:intro.widthAnchor multiplier:0.16],
        [lightSweep.heightAnchor constraintEqualToAnchor:intro.heightAnchor multiplier:1.32],
        [lightSweep.centerYAnchor constraintEqualToAnchor:intro.centerYAnchor],
        [lightSweep.leadingAnchor constraintEqualToAnchor:intro.leadingAnchor constant:-180.0],

        [mark.centerXAnchor constraintEqualToAnchor:intro.centerXAnchor],
        [mark.centerYAnchor constraintEqualToAnchor:intro.centerYAnchor constant:-44.0],
        [mark.widthAnchor constraintEqualToConstant:120.0],
        [mark.heightAnchor constraintEqualToConstant:120.0],

        [title.centerXAnchor constraintEqualToAnchor:intro.centerXAnchor],
        [title.topAnchor constraintEqualToAnchor:mark.bottomAnchor constant:22.0],
        [subtitle.centerXAnchor constraintEqualToAnchor:intro.centerXAnchor],
        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:8.0],
    ]];

    self.startupSoundPlayer = [self audioPlayerWithFrequency:392.0 duration:0.62 gain:0.30];
    [self playSoundPlayer:([self consoleSoundThemeEnabled] ? self.consoleStartupSoundPlayer : self.startupSoundPlayer)
                 fallback:0];
    [waves startAnimating];

    [UIView animateWithDuration:1.85
                          delay:0.0
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         waves.alpha = 0.64;
                         mark.alpha = 1.0;
                         mark.transform = CGAffineTransformIdentity;
                         mark.layer.shadowOpacity = 0.72;
                     }
                     completion:nil];

    [UIView animateWithDuration:1.25
                          delay:0.42
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         title.alpha = 1.0;
                         subtitle.alpha = 1.0;
                     }
                     completion:nil];

    [UIView animateWithDuration:1.05
                          delay:0.30
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         lightSweep.alpha = 1.0;
                         lightSweep.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(CGRectGetWidth(intro.bounds) + 360.0, 0.0),
                                                                        CGAffineTransformMakeRotation(-0.25));
                     }
                     completion:^(BOOL finished) {
                         lightSweep.alpha = 0.0;
                     }];

    [UIView animateKeyframesWithDuration:3.15
                                   delay:0.0
                                 options:UIViewKeyframeAnimationOptionCalculationModeCubic
                              animations:^{
                                  [UIView addKeyframeWithRelativeStartTime:0.78 relativeDuration:0.22 animations:^{
                                      intro.alpha = 0.0;
                                      mark.transform = CGAffineTransformMakeScale(1.08, 1.08);
                                      title.transform = CGAffineTransformMakeTranslation(0.0, -8.0);
                                      subtitle.transform = CGAffineTransformMakeTranslation(0.0, -8.0);
                                  }];
                              }
                              completion:^(BOOL finished) {
                                  [waves stopAnimating];
                                  [intro removeFromSuperview];
                                  self.bootIntroView = nil;
                                  [self presentFirstLaunchSetupIfNeeded];
                              }];
}

- (void)installDashboard {
    self.dashboardView = [[UIView alloc] init];
    self.dashboardView.translatesAutoresizingMaskIntoConstraints = NO;
    self.dashboardView.backgroundColor = UIColor.clearColor;
    [self.view addSubview:self.dashboardView];

    self.backgroundImageView = [[UIImageView alloc] init];
    self.backgroundImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.backgroundImageView.alpha = 0.0;
    self.backgroundImageView.clipsToBounds = YES;
    [self.dashboardView addSubview:self.backgroundImageView];

    CAGradientLayer* gradient = [CAGradientLayer layer];
    gradient.colors = @[
        (__bridge id)[UIColor colorWithRed:0.00 green:0.10 blue:0.48 alpha:1.00].CGColor,
        (__bridge id)[UIColor colorWithRed:0.00 green:0.22 blue:0.72 alpha:0.98].CGColor,
        (__bridge id)[UIColor colorWithRed:0.00 green:0.38 blue:0.95 alpha:0.88].CGColor,
    ];
    gradient.startPoint = CGPointMake(0.0, 0.0);
    gradient.endPoint = CGPointMake(1.0, 1.0);
    [self.dashboardView.layer insertSublayer:gradient atIndex:0];
    gradient.name = @"DashboardGradient";

    [self addDashboardWaves];

    [NSLayoutConstraint activateConstraints:@[
        [self.dashboardView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.dashboardView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.dashboardView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.dashboardView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.backgroundImageView.leadingAnchor constraintEqualToAnchor:self.dashboardView.leadingAnchor],
        [self.backgroundImageView.trailingAnchor constraintEqualToAnchor:self.dashboardView.trailingAnchor],
        [self.backgroundImageView.topAnchor constraintEqualToAnchor:self.dashboardView.topAnchor],
        [self.backgroundImageView.bottomAnchor constraintEqualToAnchor:self.dashboardView.bottomAnchor],
    ]];

    [self installTopBar];
    [self installGameCarousel];
    [self installStatusArea];
}

- (void)applySavedDashboardBackground {
    NSString* path = [[NSUserDefaults standardUserDefaults] stringForKey:ShadDashboardBackgroundDefaultsKey];
    NSInteger mode = [[NSUserDefaults standardUserDefaults] integerForKey:ShadDashboardBackgroundModeDefaultsKey];
    UIImage* image = (mode == 1 && path.length > 0) ? [UIImage imageWithContentsOfFile:path] : nil;
    UIImage* previousImage = self.backgroundImageView.image;
    self.backgroundImageView.image = image;
    self.dashboardWavesView.hidden = image != nil;
    [self animateDashboardChanges:(previousImage != image)
                          baseTime:0.24
                           damping:0.92
                           changes:^{
                               self.backgroundImageView.alpha = image ? 1.0 : 0.0;
                           }
                        completion:nil];
    [self applyDashboardDynamicStyle];
}

- (void)dashboardBackgroundChanged:(NSNotification*)notification {
    [self applySavedDashboardBackground];
}

- (void)applyDashboardDynamicStyle {
    if (self.backgroundImageView.image != nil) {
        return;
    }

    NSInteger style = [[NSUserDefaults standardUserDefaults] integerForKey:ShadDashboardDynamicStyleDefaultsKey];
    NSArray* palettes = @[
        @[
            (__bridge id)[UIColor colorWithRed:0.00 green:0.10 blue:0.48 alpha:1.00].CGColor,
            (__bridge id)[UIColor colorWithRed:0.00 green:0.22 blue:0.72 alpha:0.98].CGColor,
            (__bridge id)[UIColor colorWithRed:0.00 green:0.38 blue:0.95 alpha:0.88].CGColor,
        ],
        @[
            (__bridge id)[UIColor colorWithRed:0.01 green:0.03 blue:0.12 alpha:1.00].CGColor,
            (__bridge id)[UIColor colorWithRed:0.02 green:0.10 blue:0.34 alpha:0.98].CGColor,
            (__bridge id)[UIColor colorWithRed:0.00 green:0.19 blue:0.50 alpha:0.90].CGColor,
        ],
        @[
            (__bridge id)[UIColor colorWithRed:0.00 green:0.17 blue:0.34 alpha:1.00].CGColor,
            (__bridge id)[UIColor colorWithRed:0.05 green:0.38 blue:0.50 alpha:0.96].CGColor,
            (__bridge id)[UIColor colorWithRed:0.35 green:0.27 blue:0.72 alpha:0.88].CGColor,
        ],
        @[
            (__bridge id)[UIColor colorWithRed:0.20 green:0.02 blue:0.15 alpha:1.00].CGColor,
            (__bridge id)[UIColor colorWithRed:0.46 green:0.04 blue:0.22 alpha:0.96].CGColor,
            (__bridge id)[UIColor colorWithRed:0.10 green:0.05 blue:0.42 alpha:0.88].CGColor,
        ],
    ];
    style = MIN(MAX(style, 0), (NSInteger)palettes.count - 1);

    for (CALayer* layer in self.dashboardView.layer.sublayers) {
        if ([layer.name isEqualToString:@"DashboardGradient"] && [layer isKindOfClass:CAGradientLayer.class]) {
            ((CAGradientLayer*)layer).colors = palettes[(NSUInteger)style];
            break;
        }
    }

    NSInteger motion = [self dashboardMotionLevel];
    CGFloat intensity = [self dashboardEffectIntensity];
    self.dashboardWavesView.hidden = motion == 0;
    self.dashboardWavesView.amplitudeScale = 0.62 + intensity * 0.74;
    [self animateDashboardChanges:YES
                          baseTime:0.26
                           damping:0.92
                           changes:^{
                               self.dashboardWavesView.alpha = motion == 0 ? 0.0 : (0.28 + intensity * 0.62);
                           }
                        completion:nil];
    [self updateDashboardWaveAnimation];
}

- (void)addDashboardWaves {
    ShadDashboardWavesView* waves = [[ShadDashboardWavesView alloc] init];
    waves.translatesAutoresizingMaskIntoConstraints = NO;
    waves.alpha = 0.82;
    self.dashboardWavesView = waves;
    [self.dashboardView addSubview:waves];

    [NSLayoutConstraint activateConstraints:@[
        [waves.leadingAnchor constraintEqualToAnchor:self.dashboardView.leadingAnchor],
        [waves.trailingAnchor constraintEqualToAnchor:self.dashboardView.trailingAnchor],
        [waves.topAnchor constraintEqualToAnchor:self.dashboardView.topAnchor],
        [waves.bottomAnchor constraintEqualToAnchor:self.dashboardView.bottomAnchor],
    ]];

    [self updateDashboardWaveAnimation];
}

- (void)updateDashboardWaveAnimation {
    [self.dashboardWavesView.layer removeAnimationForKey:@"dashboardWaveDrift"];
    [self.dashboardWavesView stopAnimating];
    if (self.dashboardWavesView.hidden) {
        return;
    }

    NSInteger motion = [self dashboardMotionLevel];
    if (motion == 0) {
        return;
    }
    CGFloat intensity = [self dashboardEffectIntensity];
    CGFloat distance = (motion == 1 ? 8.0 : (motion == 2 ? 18.0 : 34.0)) * MAX(intensity, 0.12);
    self.dashboardWavesView.speed = (motion == 1 ? 0.38 : (motion == 2 ? 0.62 : 0.95)) * (0.65 + intensity * 0.75);
    [self.dashboardWavesView startAnimating];

    CABasicAnimation* drift = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
    drift.fromValue = @(-distance);
    drift.toValue = @(distance);
    drift.duration = motion == 3 ? 5.8 : (motion == 1 ? 11.0 : 8.0);
    drift.autoreverses = YES;
    drift.repeatCount = HUGE_VALF;
    drift.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.dashboardWavesView.layer addAnimation:drift forKey:@"dashboardWaveDrift"];
}

- (void)installTopBar {
    self.topBar = [[UIView alloc] init];
    self.topBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.dashboardView addSubview:self.topBar];

    UIStackView* iconStack = [[UIStackView alloc] init];
    iconStack.translatesAutoresizingMaskIntoConstraints = NO;
    iconStack.axis = UILayoutConstraintAxisHorizontal;
    iconStack.spacing = 22.0;
    iconStack.alignment = UIStackViewAlignmentCenter;
    [self.topBar addSubview:iconStack];

    UIButton* trophies = [self topButtonWithSymbol:@"trophy.fill" title:@"Trophies" action:@selector(trophiesPressed)];
    UIButton* settings = [self topButtonWithSymbol:@"gearshape.fill" title:@"Settings" action:@selector(settingsPressed)];
    [iconStack addArrangedSubview:trophies];
    [iconStack addArrangedSubview:settings];
    [self.topMenuButtons addObjectsFromArray:@[ trophies, settings ]];

    self.profileButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.profileButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.profileButton.tintColor = UIColor.whiteColor;
    self.profileButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.10];
    self.profileButton.layer.cornerRadius = 16.0;
    self.profileButton.clipsToBounds = YES;
    [self.profileButton addTarget:self action:@selector(profilePressed) forControlEvents:UIControlEventTouchUpInside];
    [self.topBar addSubview:self.profileButton];

    self.profileNameLabel = [[UILabel alloc] init];
    self.profileNameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.profileNameLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.82];
    self.profileNameLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium];
    [self.topBar addSubview:self.profileNameLabel];
    [self.topMenuButtons addObject:self.profileButton];

    self.clockLabel = [[UILabel alloc] init];
    self.clockLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.clockLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.90];
    self.clockLabel.font = [UIFont monospacedDigitSystemFontOfSize:18.0 weight:UIFontWeightMedium];
    [self.topBar addSubview:self.clockLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.topBar.leadingAnchor constraintEqualToAnchor:self.dashboardView.leadingAnchor constant:34.0],
        [self.topBar.trailingAnchor constraintEqualToAnchor:self.dashboardView.trailingAnchor constant:-34.0],
        [self.topBar.topAnchor constraintEqualToAnchor:self.dashboardView.topAnchor constant:10.0],
        [self.topBar.heightAnchor constraintEqualToConstant:54.0],

        [iconStack.leadingAnchor constraintEqualToAnchor:self.topBar.leadingAnchor],
        [iconStack.centerYAnchor constraintEqualToAnchor:self.topBar.centerYAnchor],

        [self.profileButton.centerYAnchor constraintEqualToAnchor:self.topBar.centerYAnchor],
        [self.profileButton.widthAnchor constraintEqualToConstant:32.0],
        [self.profileButton.heightAnchor constraintEqualToConstant:32.0],
        [self.profileNameLabel.leadingAnchor constraintEqualToAnchor:self.profileButton.trailingAnchor constant:8.0],
        [self.profileNameLabel.centerYAnchor constraintEqualToAnchor:self.topBar.centerYAnchor],
        [self.profileNameLabel.widthAnchor constraintLessThanOrEqualToConstant:150.0],
        [self.profileNameLabel.trailingAnchor constraintEqualToAnchor:self.clockLabel.leadingAnchor constant:-28.0],

        [self.clockLabel.trailingAnchor constraintEqualToAnchor:self.topBar.trailingAnchor],
        [self.clockLabel.centerYAnchor constraintEqualToAnchor:self.topBar.centerYAnchor],
    ]];
    [self updateProfileButton];
}

- (UIButton*)topButtonWithSymbol:(NSString*)symbol title:(NSString*)title action:(SEL)action {
    UIButton* button = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImage* image = [UIImage systemImageNamed:symbol];
    [button setImage:image forState:UIControlStateNormal];
    button.tintColor = [UIColor colorWithWhite:1.0 alpha:0.92];
    button.accessibilityLabel = title;
    button.showsMenuAsPrimaryAction = NO;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [button.widthAnchor constraintEqualToConstant:40.0].active = YES;
    [button.heightAnchor constraintEqualToConstant:40.0].active = YES;
    return button;
}

- (void)updateProfileButton {
    NSDictionary* profile = ShadCurrentProfile();
    NSString* name = profile[@"name"] ?: @"User";
    self.profileNameLabel.text = name;
    NSString* path = profile[@"avatarPath"];
    UIImage* avatar = path.length > 0 ? [UIImage imageWithContentsOfFile:path] : nil;
    if (avatar != nil) {
        [self.profileButton setImage:nil forState:UIControlStateNormal];
        [self.profileButton setBackgroundImage:avatar forState:UIControlStateNormal];
        self.profileButton.contentMode = UIViewContentModeScaleAspectFill;
        self.profileButton.imageView.contentMode = UIViewContentModeScaleAspectFill;
    } else {
        [self.profileButton setBackgroundImage:nil forState:UIControlStateNormal];
        UIImage* image = [[UIImage systemImageNamed:@"person.crop.circle.fill"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        [self.profileButton setImage:image forState:UIControlStateNormal];
        self.profileButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
    }
    self.profileButton.backgroundColor = ShadProfileColor(profile[@"id"] ?: name);
    self.profileButton.accessibilityLabel = [NSString stringWithFormat:@"Profile %@", name];
}

- (void)profilePressed {
    if (ShadCurrentUserID().length == 0) {
        [self presentUserSelectionAnimated:YES];
        return;
    }
    self.topMenuFocused = YES;
    self.topMenuIndex = 2;
    [self updateSelectedGameAnimated:YES];
    [self playAcceptSound];
    ShadProfileViewController* profile = [[ShadProfileViewController alloc] init];
    profile.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:profile animated:YES completion:nil];
}

- (void)installGameCarousel {
    self.gameScrollView = [[UIScrollView alloc] init];
    self.gameScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.gameScrollView.showsHorizontalScrollIndicator = NO;
    self.gameScrollView.decelerationRate = UIScrollViewDecelerationRateFast;
    self.gameScrollView.delegate = self;
    [self.dashboardView addSubview:self.gameScrollView];

    self.gameStack = [[UIStackView alloc] init];
    self.gameStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.gameStack.axis = UILayoutConstraintAxisHorizontal;
    self.gameStack.alignment = UIStackViewAlignmentCenter;
    self.gameStack.spacing = 18.0;
    [self.gameScrollView addSubview:self.gameStack];

    [NSLayoutConstraint activateConstraints:@[
        [self.gameScrollView.leadingAnchor constraintEqualToAnchor:self.dashboardView.leadingAnchor],
        [self.gameScrollView.trailingAnchor constraintEqualToAnchor:self.dashboardView.trailingAnchor],
        [self.gameScrollView.topAnchor constraintEqualToAnchor:self.dashboardView.topAnchor constant:86.0],
        [self.gameScrollView.heightAnchor constraintEqualToConstant:250.0],

        [self.gameStack.leadingAnchor constraintEqualToAnchor:self.gameScrollView.contentLayoutGuide.leadingAnchor constant:46.0],
        [self.gameStack.trailingAnchor constraintEqualToAnchor:self.gameScrollView.contentLayoutGuide.trailingAnchor constant:-46.0],
        [self.gameStack.topAnchor constraintEqualToAnchor:self.gameScrollView.contentLayoutGuide.topAnchor],
        [self.gameStack.bottomAnchor constraintEqualToAnchor:self.gameScrollView.contentLayoutGuide.bottomAnchor],
        [self.gameStack.heightAnchor constraintEqualToAnchor:self.gameScrollView.frameLayoutGuide.heightAnchor],
    ]];
}

- (void)installStatusArea {
    self.gameDetailPanel =
        [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark]];
    self.gameDetailPanel.translatesAutoresizingMaskIntoConstraints = NO;
    self.gameDetailPanel.backgroundColor = [UIColor colorWithRed:0.02 green:0.16 blue:0.48 alpha:0.18];
    self.gameDetailPanel.layer.cornerRadius = 0.0;
    self.gameDetailPanel.clipsToBounds = YES;
    [self.dashboardView addSubview:self.gameDetailPanel];

    self.selectedTitleLabel = [[UILabel alloc] init];
    self.selectedTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.selectedTitleLabel.textColor = UIColor.whiteColor;
    self.selectedTitleLabel.font = [UIFont systemFontOfSize:31.0 weight:UIFontWeightLight];
    [self.gameDetailPanel.contentView addSubview:self.selectedTitleLabel];

    self.selectedDetailLabel = [[UILabel alloc] init];
    self.selectedDetailLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.selectedDetailLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.70];
    self.selectedDetailLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightRegular];
    [self.gameDetailPanel.contentView addSubview:self.selectedDetailLabel];

    self.selectedCompatibilityLabel = [self metadataLabel];
    self.selectedCompatibilityLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    [self.gameDetailPanel.contentView addSubview:self.selectedCompatibilityLabel];

    self.selectedCompatibilityDot = [[UIView alloc] init];
    self.selectedCompatibilityDot.translatesAutoresizingMaskIntoConstraints = NO;
    self.selectedCompatibilityDot.layer.cornerRadius = 6.0;
    self.selectedCompatibilityDot.layer.borderWidth = 1.0;
    self.selectedCompatibilityDot.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.42].CGColor;
    [self.gameDetailPanel.contentView addSubview:self.selectedCompatibilityDot];

    self.selectedPathLabel = [self metadataLabel];
    self.selectedTypeLabel = [self metadataLabel];
    self.selectedLastPlayedLabel = [self metadataLabel];
    [self.gameDetailPanel.contentView addSubview:self.selectedPathLabel];
    [self.gameDetailPanel.contentView addSubview:self.selectedTypeLabel];
    [self.gameDetailPanel.contentView addSubview:self.selectedLastPlayedLabel];

    self.deleteGameButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.deleteGameButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.deleteGameButton.tintColor = UIColor.whiteColor;
    self.deleteGameButton.backgroundColor = [UIColor colorWithRed:0.75 green:0.08 blue:0.10 alpha:0.42];
    self.deleteGameButton.layer.cornerRadius = 5.0;
    [self.deleteGameButton setTitle:@"Delete Game" forState:UIControlStateNormal];
    [self.deleteGameButton addTarget:self action:@selector(deleteSelectedGamePressed) forControlEvents:UIControlEventTouchUpInside];
    [self.gameDetailPanel.contentView addSubview:self.deleteGameButton];

    self.startGameButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.startGameButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.startGameButton.tintColor = UIColor.whiteColor;
    self.startGameButton.backgroundColor = [UIColor colorWithRed:0.05 green:0.34 blue:0.86 alpha:0.72];
    self.startGameButton.layer.cornerRadius = 5.0;
    [self.startGameButton setTitle:@"Start Game" forState:UIControlStateNormal];
    [self.startGameButton addTarget:self action:@selector(startGameButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    [self.gameDetailPanel.contentView addSubview:self.startGameButton];

    self.editGameButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.editGameButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.editGameButton.tintColor = UIColor.whiteColor;
    self.editGameButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.14];
    self.editGameButton.layer.cornerRadius = 5.0;
    [self.editGameButton setTitle:@"Edit Game" forState:UIControlStateNormal];
    [self.editGameButton addTarget:self action:@selector(editSelectedGamePressed) forControlEvents:UIControlEventTouchUpInside];
    [self.gameDetailPanel.contentView addSubview:self.editGameButton];

    self.emptyStateView =
        [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark]];
    self.emptyStateView.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyStateView.layer.cornerRadius = 6.0;
    self.emptyStateView.clipsToBounds = YES;
    [self.dashboardView addSubview:self.emptyStateView];

    UIImageView* emptyIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"plus.square.dashed"]];
    emptyIcon.translatesAutoresizingMaskIntoConstraints = NO;
    emptyIcon.tintColor = [UIColor colorWithWhite:1.0 alpha:0.72];
    [self.emptyStateView.contentView addSubview:emptyIcon];

    UILabel* emptyTitle = [[UILabel alloc] init];
    emptyTitle.translatesAutoresizingMaskIntoConstraints = NO;
    emptyTitle.text = @"Your library is empty";
    emptyTitle.textColor = UIColor.whiteColor;
    emptyTitle.font = [UIFont systemFontOfSize:24.0 weight:UIFontWeightLight];
    [self.emptyStateView.contentView addSubview:emptyTitle];

    UILabel* emptyDetail = [[UILabel alloc] init];
    emptyDetail.translatesAutoresizingMaskIntoConstraints = NO;
    emptyDetail.text = @"Press +, choose a PS4 game folder, then keep the app open while it imports.";
    emptyDetail.textColor = [UIColor colorWithWhite:1.0 alpha:0.68];
    emptyDetail.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightRegular];
    [self.emptyStateView.contentView addSubview:emptyDetail];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.text = @"Connect a controller or press + to add a game";
    self.statusLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.62];
    self.statusLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
    [self.dashboardView addSubview:self.statusLabel];

    self.importOverlayView =
        [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterialDark]];
    self.importOverlayView.translatesAutoresizingMaskIntoConstraints = NO;
    self.importOverlayView.layer.cornerRadius = 8.0;
    self.importOverlayView.clipsToBounds = YES;
    self.importOverlayView.hidden = YES;
    self.importOverlayView.alpha = 0.0;
    [self.dashboardView addSubview:self.importOverlayView];

    self.importProgressLabel = [[UILabel alloc] init];
    self.importProgressLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.importProgressLabel.text = @"Preparing import...";
    self.importProgressLabel.textColor = UIColor.whiteColor;
    self.importProgressLabel.font = [UIFont systemFontOfSize:18.0 weight:UIFontWeightSemibold];
    [self.importOverlayView.contentView addSubview:self.importProgressLabel];

    self.importProgressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.importProgressView.translatesAutoresizingMaskIntoConstraints = NO;
    self.importProgressView.progressTintColor = [UIColor colorWithRed:0.18 green:0.58 blue:1.0 alpha:1.0];
    self.importProgressView.trackTintColor = [UIColor colorWithWhite:1.0 alpha:0.18];
    self.importProgressView.progress = 0.0f;
    [self.importOverlayView.contentView addSubview:self.importProgressView];

    [NSLayoutConstraint activateConstraints:@[
        [self.gameDetailPanel.leadingAnchor constraintEqualToAnchor:self.dashboardView.leadingAnchor constant:72.0],
        [self.gameDetailPanel.trailingAnchor constraintLessThanOrEqualToAnchor:self.dashboardView.trailingAnchor constant:-72.0],
        [self.gameDetailPanel.topAnchor constraintEqualToAnchor:self.gameScrollView.bottomAnchor constant:4.0],
        [self.gameDetailPanel.widthAnchor constraintGreaterThanOrEqualToConstant:540.0],

        [self.selectedTitleLabel.leadingAnchor constraintEqualToAnchor:self.gameDetailPanel.contentView.leadingAnchor constant:22.0],
        [self.selectedTitleLabel.topAnchor constraintEqualToAnchor:self.gameDetailPanel.contentView.topAnchor constant:16.0],
        [self.selectedTitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.gameDetailPanel.contentView.trailingAnchor constant:-22.0],

        [self.selectedDetailLabel.leadingAnchor constraintEqualToAnchor:self.selectedTitleLabel.leadingAnchor],
        [self.selectedDetailLabel.topAnchor constraintEqualToAnchor:self.selectedTitleLabel.bottomAnchor constant:6.0],
        [self.selectedDetailLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.gameDetailPanel.contentView.trailingAnchor constant:-22.0],

        [self.selectedCompatibilityDot.leadingAnchor constraintEqualToAnchor:self.selectedTitleLabel.leadingAnchor],
        [self.selectedCompatibilityDot.centerYAnchor constraintEqualToAnchor:self.selectedCompatibilityLabel.centerYAnchor],
        [self.selectedCompatibilityDot.widthAnchor constraintEqualToConstant:12.0],
        [self.selectedCompatibilityDot.heightAnchor constraintEqualToConstant:12.0],

        [self.selectedCompatibilityLabel.leadingAnchor constraintEqualToAnchor:self.selectedCompatibilityDot.trailingAnchor constant:8.0],
        [self.selectedCompatibilityLabel.topAnchor constraintEqualToAnchor:self.selectedDetailLabel.bottomAnchor constant:10.0],
        [self.selectedCompatibilityLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.gameDetailPanel.contentView.trailingAnchor constant:-22.0],

        [self.selectedPathLabel.leadingAnchor constraintEqualToAnchor:self.selectedTitleLabel.leadingAnchor],
        [self.selectedPathLabel.topAnchor constraintEqualToAnchor:self.selectedCompatibilityLabel.bottomAnchor constant:10.0],
        [self.selectedPathLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.gameDetailPanel.contentView.trailingAnchor constant:-22.0],

        [self.selectedTypeLabel.leadingAnchor constraintEqualToAnchor:self.selectedTitleLabel.leadingAnchor],
        [self.selectedTypeLabel.topAnchor constraintEqualToAnchor:self.selectedPathLabel.bottomAnchor constant:5.0],
        [self.selectedTypeLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.gameDetailPanel.contentView.trailingAnchor constant:-22.0],

        [self.selectedLastPlayedLabel.leadingAnchor constraintEqualToAnchor:self.selectedTitleLabel.leadingAnchor],
        [self.selectedLastPlayedLabel.topAnchor constraintEqualToAnchor:self.selectedTypeLabel.bottomAnchor constant:5.0],
        [self.selectedLastPlayedLabel.bottomAnchor constraintEqualToAnchor:self.gameDetailPanel.contentView.bottomAnchor constant:-18.0],
        [self.selectedLastPlayedLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.gameDetailPanel.contentView.trailingAnchor constant:-22.0],

        [self.editGameButton.trailingAnchor constraintEqualToAnchor:self.gameDetailPanel.contentView.trailingAnchor constant:-18.0],
        [self.editGameButton.bottomAnchor constraintEqualToAnchor:self.gameDetailPanel.contentView.bottomAnchor constant:-18.0],
        [self.editGameButton.widthAnchor constraintEqualToConstant:118.0],
        [self.editGameButton.heightAnchor constraintEqualToConstant:36.0],

        [self.startGameButton.trailingAnchor constraintEqualToAnchor:self.editGameButton.leadingAnchor constant:-10.0],
        [self.startGameButton.bottomAnchor constraintEqualToAnchor:self.editGameButton.bottomAnchor],
        [self.startGameButton.widthAnchor constraintEqualToConstant:124.0],
        [self.startGameButton.heightAnchor constraintEqualToConstant:36.0],

        [self.deleteGameButton.trailingAnchor constraintEqualToAnchor:self.startGameButton.leadingAnchor constant:-10.0],
        [self.deleteGameButton.bottomAnchor constraintEqualToAnchor:self.gameDetailPanel.contentView.bottomAnchor constant:-18.0],
        [self.deleteGameButton.widthAnchor constraintEqualToConstant:132.0],
        [self.deleteGameButton.heightAnchor constraintEqualToConstant:36.0],

        [self.emptyStateView.leadingAnchor constraintEqualToAnchor:self.dashboardView.leadingAnchor constant:72.0],
        [self.emptyStateView.topAnchor constraintEqualToAnchor:self.gameScrollView.bottomAnchor constant:18.0],
        [self.emptyStateView.widthAnchor constraintEqualToConstant:460.0],
        [self.emptyStateView.heightAnchor constraintEqualToConstant:118.0],

        [emptyIcon.leadingAnchor constraintEqualToAnchor:self.emptyStateView.contentView.leadingAnchor constant:24.0],
        [emptyIcon.centerYAnchor constraintEqualToAnchor:self.emptyStateView.contentView.centerYAnchor],
        [emptyIcon.widthAnchor constraintEqualToConstant:42.0],
        [emptyIcon.heightAnchor constraintEqualToConstant:42.0],

        [emptyTitle.leadingAnchor constraintEqualToAnchor:emptyIcon.trailingAnchor constant:18.0],
        [emptyTitle.topAnchor constraintEqualToAnchor:self.emptyStateView.contentView.topAnchor constant:26.0],
        [emptyTitle.trailingAnchor constraintLessThanOrEqualToAnchor:self.emptyStateView.contentView.trailingAnchor constant:-18.0],

        [emptyDetail.leadingAnchor constraintEqualToAnchor:emptyTitle.leadingAnchor],
        [emptyDetail.topAnchor constraintEqualToAnchor:emptyTitle.bottomAnchor constant:8.0],
        [emptyDetail.trailingAnchor constraintLessThanOrEqualToAnchor:self.emptyStateView.contentView.trailingAnchor constant:-18.0],

        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.dashboardView.leadingAnchor constant:28.0],
        [self.statusLabel.bottomAnchor constraintEqualToAnchor:self.dashboardView.bottomAnchor constant:-14.0],

        [self.importOverlayView.centerXAnchor constraintEqualToAnchor:self.dashboardView.centerXAnchor],
        [self.importOverlayView.bottomAnchor constraintEqualToAnchor:self.dashboardView.bottomAnchor constant:-46.0],
        [self.importOverlayView.widthAnchor constraintEqualToConstant:440.0],
        [self.importOverlayView.heightAnchor constraintEqualToConstant:96.0],
        [self.importProgressLabel.leadingAnchor constraintEqualToAnchor:self.importOverlayView.contentView.leadingAnchor constant:24.0],
        [self.importProgressLabel.trailingAnchor constraintEqualToAnchor:self.importOverlayView.contentView.trailingAnchor constant:-24.0],
        [self.importProgressLabel.topAnchor constraintEqualToAnchor:self.importOverlayView.contentView.topAnchor constant:22.0],
        [self.importProgressView.leadingAnchor constraintEqualToAnchor:self.importProgressLabel.leadingAnchor],
        [self.importProgressView.trailingAnchor constraintEqualToAnchor:self.importProgressLabel.trailingAnchor],
        [self.importProgressView.topAnchor constraintEqualToAnchor:self.importProgressLabel.bottomAnchor constant:18.0],
    ]];
}

- (UILabel*)metadataLabel {
    UILabel* label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.textColor = [UIColor colorWithWhite:1.0 alpha:0.58];
    label.font = [UIFont monospacedSystemFontOfSize:13.0 weight:UIFontWeightRegular];
    label.lineBreakMode = NSLineBreakByTruncatingMiddle;
    return label;
}

- (void)showImportProgressWithText:(NSString*)text progress:(float)progress {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.importingGame = YES;
        self.addGameTile.enabled = NO;
        self.importProgressLabel.text = text ?: @"Importing...";
        [self.importProgressView setProgress:MIN(MAX(progress, 0.0f), 1.0f) animated:YES];
        if (self.importOverlayView.hidden) {
            self.importOverlayView.hidden = NO;
            self.importOverlayView.transform = CGAffineTransformMakeTranslation(0.0, 12.0);
            [UIView animateWithDuration:0.18
                             animations:^{
                                 self.importOverlayView.alpha = 1.0;
                                 self.importOverlayView.transform = CGAffineTransformIdentity;
                             }];
        }
    });
}

- (void)hideImportProgressWithStatus:(NSString*)status success:(BOOL)success {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.importingGame = NO;
        self.addGameTile.enabled = YES;
        self.statusLabel.text = status ?: (success ? @"Import complete" : @"Import failed");
        [self.importProgressView setProgress:(success ? 1.0f : 0.0f) animated:YES];
        [UIView animateWithDuration:0.18
                         animations:^{
                             self.importOverlayView.alpha = 0.0;
                             self.importOverlayView.transform = CGAffineTransformMakeTranslation(0.0, 12.0);
                         }
                         completion:^(BOOL finished) {
                             self.importOverlayView.hidden = YES;
                             self.importOverlayView.transform = CGAffineTransformIdentity;
                         }];
    });
}

- (void)installFallbackLabel:(NSString*)message {
    UILabel* label = [[UILabel alloc] initWithFrame:self.view.bounds];
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    label.text = message;
    label.textColor = UIColor.whiteColor;
    label.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:label];
}

- (void)installTouchOverlay {
    self.touchOverlay = [[UIView alloc] init];
    self.touchOverlay.translatesAutoresizingMaskIntoConstraints = NO;
    self.touchOverlay.userInteractionEnabled = YES;
    self.touchOverlay.alpha = 0.0;
    self.touchOverlay.hidden = YES;
    [self.view addSubview:self.touchOverlay];

    NSArray<NSDictionary*>* controls = @[
        @{ @"id" : @"dpad", @"title" : @"" },
        @{ @"id" : @"l2", @"title" : @"L2" },
        @{ @"id" : @"l1", @"title" : @"L1" },
        @{ @"id" : @"r1", @"title" : @"R1" },
        @{ @"id" : @"r2", @"title" : @"R2" },
        @{ @"id" : @"square", @"title" : @"□" },
        @{ @"id" : @"triangle", @"title" : @"△" },
        @{ @"id" : @"cross", @"title" : @"×" },
        @{ @"id" : @"circle", @"title" : @"○" },
        @{ @"id" : @"share", @"title" : @"SHARE" },
        @{ @"id" : @"options", @"title" : @"OPTIONS" },
        @{ @"id" : @"leftStick", @"title" : @"L3" },
        @{ @"id" : @"rightStick", @"title" : @"R3" },
    ];
    for (NSDictionary* control in controls) {
        UIButton* button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.accessibilityIdentifier = control[@"id"];
        [button setTitle:control[@"title"] forState:UIControlStateNormal];
        BOOL systemButton = [@[@"share", @"options"] containsObject:control[@"id"]];
        button.titleLabel.font = [UIFont systemFontOfSize:systemButton ? 11.0 : ([control[@"id"] hasSuffix:@"Stick"] ? 14.0 : 25.0)
                                                   weight:systemButton ? UIFontWeightSemibold : UIFontWeightMedium];
        [button setTitleColor:UIColor.whiteColor forState:UIControlStateHighlighted];
        button.layer.shadowColor = UIColor.blackColor.CGColor;
        button.layer.shadowOffset = CGSizeMake(0.0, 7.0);
        button.layer.shadowOpacity = 0.30;
        button.layer.shadowRadius = 12.0;
        button.clipsToBounds = NO;
        [self styleVirtualControlButton:button pressed:NO editing:NO];
        [button addTarget:self action:@selector(virtualControlTouchDown:event:) forControlEvents:UIControlEventTouchDown];
        [button addTarget:self
                   action:@selector(virtualControlTouchUp:event:)
         forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
        UIPanGestureRecognizer* pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(virtualControlDragged:)];
        pan.maximumNumberOfTouches = 1;
        pan.cancelsTouchesInView = NO;
        [button addGestureRecognizer:pan];
        UIPinchGestureRecognizer* pinch =
            [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(virtualControlPinched:)];
        pinch.cancelsTouchesInView = NO;
        [button addGestureRecognizer:pinch];
        [self.touchOverlay addSubview:button];
        self.virtualControlButtons[control[@"id"]] = button;
    }

    [NSLayoutConstraint activateConstraints:@[
        [self.touchOverlay.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.touchOverlay.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.touchOverlay.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.touchOverlay.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    [self installVirtualLayoutEditPanel];

    self.overlayMenuView =
        [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterialDark]];
    self.overlayMenuView.translatesAutoresizingMaskIntoConstraints = NO;
    self.overlayMenuView.layer.cornerRadius = 10.0;
    self.overlayMenuView.clipsToBounds = YES;
    self.overlayMenuView.hidden = YES;
    self.overlayMenuView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.18].CGColor;
    self.overlayMenuView.layer.borderWidth = 1.0;
    self.overlayMenuView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.overlayMenuView.layer.shadowOpacity = 0.38;
    self.overlayMenuView.layer.shadowRadius = 24.0;
    self.overlayMenuView.layer.shadowOffset = CGSizeMake(0.0, 12.0);
    [self.view addSubview:self.overlayMenuView];

    UILabel* overlayTitle = [[UILabel alloc] init];
    overlayTitle.translatesAutoresizingMaskIntoConstraints = NO;
    overlayTitle.text = @"Quick Menu";
    overlayTitle.textColor = UIColor.whiteColor;
    overlayTitle.font = [UIFont systemFontOfSize:29.0 weight:UIFontWeightLight];
    [self.overlayMenuView.contentView addSubview:overlayTitle];

    UILabel* overlaySubtitle = [[UILabel alloc] init];
    overlaySubtitle.translatesAutoresizingMaskIntoConstraints = NO;
    overlaySubtitle.text = @"Game overlay";
    overlaySubtitle.textColor = [UIColor colorWithWhite:1.0 alpha:0.58];
    overlaySubtitle.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    [self.overlayMenuView.contentView addSubview:overlaySubtitle];

    UIView* separator = [[UIView alloc] init];
    separator.translatesAutoresizingMaskIntoConstraints = NO;
    separator.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.16];
    [self.overlayMenuView.contentView addSubview:separator];

    UIStackView* stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 9.0;
    stack.alignment = UIStackViewAlignmentFill;
    [self.overlayMenuView.contentView addSubview:stack];

    [stack addArrangedSubview:[self overlayButtonWithTitle:@"Resume"
                                                    symbol:@"play.fill"
                                                    action:@selector(hideRuntimeOverlayMenu)]];
    [stack addArrangedSubview:[self overlayButtonWithTitle:@"Settings"
                                                    symbol:@"gearshape.fill"
                                                    action:@selector(runtimeSettingsPressed)]];
    [stack addArrangedSubview:[self overlayButtonWithTitle:@"Edit Controller Layout"
                                                    symbol:@"gamecontroller.fill"
                                                    action:@selector(editVirtualControllerLayout)]];
    [stack addArrangedSubview:[self overlayButtonWithTitle:@"Save State"
                                                    symbol:@"tray.and.arrow.down.fill"
                                                    action:@selector(saveStatePressed)]];
    [stack addArrangedSubview:[self overlayButtonWithTitle:@"Show / Hide Touch Controls"
                                                    symbol:@"eye.slash.fill"
                                                    action:@selector(toggleTouchControls)]];
    [stack addArrangedSubview:[self overlayButtonWithTitle:@"Quit Game"
                                                    symbol:@"xmark.circle.fill"
                                                    action:@selector(quitGamePressed)]];

    UILabel* overlayHint = [[UILabel alloc] init];
    overlayHint.translatesAutoresizingMaskIntoConstraints = NO;
    overlayHint.text = @"Swipe right or tap Resume to close";
    overlayHint.textColor = [UIColor colorWithWhite:1.0 alpha:0.48];
    overlayHint.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightRegular];
    [self.overlayMenuView.contentView addSubview:overlayHint];

    UISwipeGestureRecognizer* openRuntimeMenuSwipe =
        [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(showRuntimeOverlayMenu)];
    openRuntimeMenuSwipe.direction = UISwipeGestureRecognizerDirectionLeft;
    [self.view addGestureRecognizer:openRuntimeMenuSwipe];

    UISwipeGestureRecognizer* closeRuntimeMenuSwipe =
        [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(hideRuntimeOverlayMenu)];
    closeRuntimeMenuSwipe.direction = UISwipeGestureRecognizerDirectionRight;
    [self.overlayMenuView.contentView addGestureRecognizer:closeRuntimeMenuSwipe];

    self.runtimeMenuButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.runtimeMenuButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.runtimeMenuButton.tintColor = UIColor.whiteColor;
    self.runtimeMenuButton.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.34];
    self.runtimeMenuButton.layer.cornerRadius = 22.0;
    self.runtimeMenuButton.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.34].CGColor;
    self.runtimeMenuButton.layer.borderWidth = 1.0;
    self.runtimeMenuButton.hidden = YES;
    UIImage* gearImage = [UIImage systemImageNamed:@"gearshape.fill"];
    if (gearImage != nil) {
        [self.runtimeMenuButton setImage:gearImage forState:UIControlStateNormal];
    } else {
        [self.runtimeMenuButton setTitle:@"⚙" forState:UIControlStateNormal];
    }
    self.runtimeMenuButton.accessibilityLabel = @"Game Overlay Menu";
    [self.runtimeMenuButton addTarget:self action:@selector(runtimeMenuButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.runtimeMenuButton];

    self.performanceOverlayView =
        [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark]];
    self.performanceOverlayView.translatesAutoresizingMaskIntoConstraints = NO;
    self.performanceOverlayView.layer.cornerRadius = 6.0;
    self.performanceOverlayView.clipsToBounds = YES;
    self.performanceOverlayView.hidden = YES;
    [self.view addSubview:self.performanceOverlayView];

    self.performanceOverlayLabel = [[UILabel alloc] init];
    self.performanceOverlayLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.performanceOverlayLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.88];
    self.performanceOverlayLabel.font = [UIFont monospacedDigitSystemFontOfSize:12.0 weight:UIFontWeightSemibold];
    self.performanceOverlayLabel.numberOfLines = 0;
    [self.performanceOverlayView.contentView addSubview:self.performanceOverlayLabel];

    UILayoutGuide* safe = self.view.safeAreaLayoutGuide;
    self.performanceOverlayLeadingConstraint =
        [self.performanceOverlayView.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:18.0];
    self.performanceOverlayCenterConstraint =
        [self.performanceOverlayView.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor];
    self.performanceOverlayTrailingConstraint =
        [self.performanceOverlayView.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-18.0];
    self.performanceOverlayTopConstraint =
        [self.performanceOverlayView.topAnchor constraintEqualToAnchor:safe.topAnchor constant:66.0];

    [NSLayoutConstraint activateConstraints:@[
        [self.overlayMenuView.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:18.0],
        [self.overlayMenuView.topAnchor constraintEqualToAnchor:safe.topAnchor constant:72.0],
        [self.overlayMenuView.bottomAnchor constraintLessThanOrEqualToAnchor:safe.bottomAnchor constant:-28.0],
        [self.overlayMenuView.widthAnchor constraintEqualToConstant:374.0],

        [overlayTitle.leadingAnchor constraintEqualToAnchor:self.overlayMenuView.contentView.leadingAnchor constant:24.0],
        [overlayTitle.trailingAnchor constraintEqualToAnchor:self.overlayMenuView.contentView.trailingAnchor constant:-24.0],
        [overlayTitle.topAnchor constraintEqualToAnchor:self.overlayMenuView.contentView.topAnchor constant:22.0],

        [overlaySubtitle.leadingAnchor constraintEqualToAnchor:overlayTitle.leadingAnchor],
        [overlaySubtitle.trailingAnchor constraintEqualToAnchor:overlayTitle.trailingAnchor],
        [overlaySubtitle.topAnchor constraintEqualToAnchor:overlayTitle.bottomAnchor constant:2.0],

        [separator.leadingAnchor constraintEqualToAnchor:self.overlayMenuView.contentView.leadingAnchor constant:24.0],
        [separator.trailingAnchor constraintEqualToAnchor:self.overlayMenuView.contentView.trailingAnchor constant:-24.0],
        [separator.topAnchor constraintEqualToAnchor:overlaySubtitle.bottomAnchor constant:18.0],
        [separator.heightAnchor constraintEqualToConstant:1.0],

        [stack.leadingAnchor constraintEqualToAnchor:self.overlayMenuView.contentView.leadingAnchor constant:18.0],
        [stack.trailingAnchor constraintEqualToAnchor:self.overlayMenuView.contentView.trailingAnchor constant:-18.0],
        [stack.topAnchor constraintEqualToAnchor:separator.bottomAnchor constant:18.0],

        [overlayHint.leadingAnchor constraintEqualToAnchor:self.overlayMenuView.contentView.leadingAnchor constant:24.0],
        [overlayHint.trailingAnchor constraintEqualToAnchor:self.overlayMenuView.contentView.trailingAnchor constant:-24.0],
        [overlayHint.topAnchor constraintEqualToAnchor:stack.bottomAnchor constant:18.0],
        [overlayHint.bottomAnchor constraintEqualToAnchor:self.overlayMenuView.contentView.bottomAnchor constant:-18.0],

        [self.runtimeMenuButton.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16.0],
        [self.runtimeMenuButton.topAnchor constraintEqualToAnchor:safe.topAnchor constant:14.0],
        [self.runtimeMenuButton.widthAnchor constraintEqualToConstant:44.0],
        [self.runtimeMenuButton.heightAnchor constraintEqualToConstant:44.0],

        self.performanceOverlayLeadingConstraint,
        self.performanceOverlayTopConstraint,
        [self.performanceOverlayView.widthAnchor constraintGreaterThanOrEqualToConstant:150.0],

        [self.performanceOverlayLabel.leadingAnchor constraintEqualToAnchor:self.performanceOverlayView.contentView.leadingAnchor constant:12.0],
        [self.performanceOverlayLabel.trailingAnchor constraintEqualToAnchor:self.performanceOverlayView.contentView.trailingAnchor constant:-12.0],
        [self.performanceOverlayLabel.topAnchor constraintEqualToAnchor:self.performanceOverlayView.contentView.topAnchor constant:8.0],
        [self.performanceOverlayLabel.bottomAnchor constraintEqualToAnchor:self.performanceOverlayView.contentView.bottomAnchor constant:-8.0],
    ]];
}

- (void)installVirtualLayoutEditPanel {
    self.virtualLayoutEditPanel =
        [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterialDark]];
    self.virtualLayoutEditPanel.translatesAutoresizingMaskIntoConstraints = NO;
    self.virtualLayoutEditPanel.layer.cornerRadius = 9.0;
    self.virtualLayoutEditPanel.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.20].CGColor;
    self.virtualLayoutEditPanel.layer.borderWidth = 1.0;
    self.virtualLayoutEditPanel.clipsToBounds = YES;
    self.virtualLayoutEditPanel.hidden = YES;
    self.virtualLayoutEditPanel.alpha = 0.0;
    [self.view addSubview:self.virtualLayoutEditPanel];

    UILabel* title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"Edit Touch Controller Layout";
    title.textColor = UIColor.whiteColor;
    title.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
    [self.virtualLayoutEditPanel.contentView addSubview:title];

    self.virtualLayoutEditHintLabel = [[UILabel alloc] init];
    self.virtualLayoutEditHintLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.virtualLayoutEditHintLabel.text = @"Drag any control. Tap Save Layout when finished.";
    self.virtualLayoutEditHintLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.62];
    self.virtualLayoutEditHintLabel.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
    [self.virtualLayoutEditPanel.contentView addSubview:self.virtualLayoutEditHintLabel];

    UIStackView* actions = [[UIStackView alloc] init];
    actions.translatesAutoresizingMaskIntoConstraints = NO;
    actions.axis = UILayoutConstraintAxisHorizontal;
    actions.spacing = 8.0;
    actions.alignment = UIStackViewAlignmentCenter;
    [self.virtualLayoutEditPanel.contentView addSubview:actions];

    [actions addArrangedSubview:[self layoutEditButtonWithTitle:@"Save Layout"
                                                         symbol:@"checkmark.circle.fill"
                                                         action:@selector(saveVirtualLayoutEditPressed)
                                                         accent:[UIColor colorWithRed:0.25 green:0.70 blue:1.0 alpha:0.82]]];
    [actions addArrangedSubview:[self layoutEditButtonWithTitle:@"Bigger"
                                                         symbol:@"plus.magnifyingglass"
                                                         action:@selector(makeSelectedVirtualControlBigger)
                                                         accent:[UIColor colorWithWhite:1.0 alpha:0.10]]];
    [actions addArrangedSubview:[self layoutEditButtonWithTitle:@"Smaller"
                                                         symbol:@"minus.magnifyingglass"
                                                         action:@selector(makeSelectedVirtualControlSmaller)
                                                         accent:[UIColor colorWithWhite:1.0 alpha:0.10]]];
    [actions addArrangedSubview:[self layoutEditButtonWithTitle:@"Reset"
                                                         symbol:@"arrow.counterclockwise"
                                                         action:@selector(resetVirtualLayoutEditPressed)
                                                         accent:[UIColor colorWithWhite:1.0 alpha:0.10]]];
    [actions addArrangedSubview:[self layoutEditButtonWithTitle:@"Cancel"
                                                         symbol:@"xmark"
                                                         action:@selector(cancelVirtualLayoutEditPressed)
                                                         accent:[UIColor colorWithWhite:1.0 alpha:0.10]]];

    UILayoutGuide* safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.virtualLayoutEditPanel.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor],
        [self.virtualLayoutEditPanel.topAnchor constraintEqualToAnchor:safe.topAnchor constant:14.0],
        [self.virtualLayoutEditPanel.widthAnchor constraintLessThanOrEqualToConstant:820.0],
        [self.virtualLayoutEditPanel.leadingAnchor constraintGreaterThanOrEqualToAnchor:safe.leadingAnchor constant:36.0],
        [self.virtualLayoutEditPanel.trailingAnchor constraintLessThanOrEqualToAnchor:safe.trailingAnchor constant:-36.0],

        [title.leadingAnchor constraintEqualToAnchor:self.virtualLayoutEditPanel.contentView.leadingAnchor constant:18.0],
        [title.topAnchor constraintEqualToAnchor:self.virtualLayoutEditPanel.contentView.topAnchor constant:12.0],
        [title.trailingAnchor constraintLessThanOrEqualToAnchor:actions.leadingAnchor constant:-18.0],

        [self.virtualLayoutEditHintLabel.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [self.virtualLayoutEditHintLabel.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:2.0],
        [self.virtualLayoutEditHintLabel.trailingAnchor constraintLessThanOrEqualToAnchor:actions.leadingAnchor constant:-18.0],
        [self.virtualLayoutEditHintLabel.bottomAnchor constraintEqualToAnchor:self.virtualLayoutEditPanel.contentView.bottomAnchor constant:-12.0],

        [actions.trailingAnchor constraintEqualToAnchor:self.virtualLayoutEditPanel.contentView.trailingAnchor constant:-12.0],
        [actions.centerYAnchor constraintEqualToAnchor:self.virtualLayoutEditPanel.contentView.centerYAnchor],
    ]];
}

- (UIButton*)layoutEditButtonWithTitle:(NSString*)title symbol:(NSString*)symbol action:(SEL)action accent:(UIColor*)accent {
    UIButton* button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.tintColor = UIColor.whiteColor;
    button.backgroundColor = accent;
    button.layer.cornerRadius = 7.0;
    button.titleLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    UIImage* image = [UIImage systemImageNamed:symbol];
    if (image != nil) {
        [button setImage:image forState:UIControlStateNormal];
    }
    [button setTitle:title forState:UIControlStateNormal];
    button.contentEdgeInsets = UIEdgeInsetsMake(0.0, 10.0, 0.0, 10.0);
    button.imageEdgeInsets = UIEdgeInsetsMake(0.0, -2.0, 0.0, 6.0);
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [button.heightAnchor constraintEqualToConstant:34.0].active = YES;
    [button.widthAnchor constraintGreaterThanOrEqualToConstant:96.0].active = YES;
    return button;
}

- (UIButton*)overlayButtonWithTitle:(NSString*)title symbol:(NSString*)symbol action:(SEL)action {
    UIButton* button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    button.tintColor = UIColor.whiteColor;
    button.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
    button.layer.cornerRadius = 7.0;
    button.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.11].CGColor;
    button.layer.borderWidth = 1.0;
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    button.titleLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold];
    button.contentEdgeInsets = UIEdgeInsetsMake(0.0, 16.0, 0.0, 14.0);
    UIImage* image = [UIImage systemImageNamed:symbol];
    if (image != nil) {
        [button setImage:image forState:UIControlStateNormal];
        button.imageView.contentMode = UIViewContentModeScaleAspectFit;
        button.imageEdgeInsets = UIEdgeInsetsMake(0.0, 0.0, 0.0, 12.0);
        button.titleEdgeInsets = UIEdgeInsetsMake(0.0, 12.0, 0.0, 0.0);
    }
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [button.heightAnchor constraintEqualToConstant:48.0].active = YES;
    return button;
}

- (NSDictionary<NSString*, NSValue*>*)defaultVirtualControllerFrames {
    const CGFloat w = self.view.bounds.size.width;
    const CGFloat h = self.view.bounds.size.height;
    const CGFloat s = 58.0;
    return @{
        @"dpad" : [NSValue valueWithCGRect:CGRectMake(58, h - 184, s * 1.62, s * 1.62)],
        @"l2" : [NSValue valueWithCGRect:CGRectMake(28, 64, s * 1.08, s * 0.92)],
        @"l1" : [NSValue valueWithCGRect:CGRectMake(104, 64, s * 1.08, s * 0.92)],
        @"r1" : [NSValue valueWithCGRect:CGRectMake(w - 186, 64, s * 1.08, s * 0.92)],
        @"r2" : [NSValue valueWithCGRect:CGRectMake(w - 110, 64, s * 1.08, s * 0.92)],
        @"square" : [NSValue valueWithCGRect:CGRectMake(w - 208, h - 184, s, s)],
        @"triangle" : [NSValue valueWithCGRect:CGRectMake(w - 140, h - 248, s, s)],
        @"cross" : [NSValue valueWithCGRect:CGRectMake(w - 140, h - 120, s, s)],
        @"circle" : [NSValue valueWithCGRect:CGRectMake(w - 72, h - 184, s, s)],
        @"share" : [NSValue valueWithCGRect:CGRectMake((w * 0.5) - 132, h - 128, s * 1.55, s * 0.62)],
        @"options" : [NSValue valueWithCGRect:CGRectMake((w * 0.5) + 42, h - 128, s * 1.72, s * 0.62)],
        @"leftStick" : [NSValue valueWithCGRect:CGRectMake(188, h - 132, s * 1.28, s * 1.28)],
        @"rightStick" : [NSValue valueWithCGRect:CGRectMake(w - 294, h - 132, s * 1.28, s * 1.28)],
    };
}

- (void)applyVirtualControllerLayoutIfNeeded {
    if (self.touchOverlay.bounds.size.width <= 0 || self.touchOverlay.bounds.size.height <= 0) {
        return;
    }
    if (self.virtualLayoutEditing) {
        return;
    }

    NSDictionary* saved = [[NSUserDefaults standardUserDefaults] dictionaryForKey:ShadVirtualControllerLayoutDefaultsKey];
    NSDictionary<NSString*, NSValue*>* defaults = [self defaultVirtualControllerFrames];
    [self.virtualControlButtons enumerateKeysAndObjectsUsingBlock:^(NSString* key, UIButton* button, BOOL* stop) {
        CGRect frame = defaults[key].CGRectValue;
        NSDictionary* normalized = saved[key];
        if ([normalized isKindOfClass:NSDictionary.class]) {
            CGFloat w = self.touchOverlay.bounds.size.width;
            CGFloat h = self.touchOverlay.bounds.size.height;
            frame = CGRectMake([normalized[@"x"] doubleValue] * w,
                               [normalized[@"y"] doubleValue] * h,
                               [normalized[@"w"] doubleValue] * w,
                               [normalized[@"h"] doubleValue] * h);
        }
        button.frame = CGRectIntegral(frame);
        [self styleVirtualControlButton:button
                                pressed:[self.pressedVirtualControls containsObject:key]
                                editing:self.virtualLayoutEditing];
    }];
}

- (void)saveVirtualControllerLayout {
    [[NSUserDefaults standardUserDefaults] setObject:[self currentVirtualControllerLayoutDictionary]
                                              forKey:ShadVirtualControllerLayoutDefaultsKey];
}

- (NSDictionary*)currentVirtualControllerLayoutDictionary {
    const CGFloat w = MAX(self.touchOverlay.bounds.size.width, 1.0);
    const CGFloat h = MAX(self.touchOverlay.bounds.size.height, 1.0);
    NSMutableDictionary* saved = [NSMutableDictionary dictionary];
    [self.virtualControlButtons enumerateKeysAndObjectsUsingBlock:^(NSString* key, UIButton* button, BOOL* stop) {
        CGRect frame = button.frame;
        saved[key] = @{
            @"x" : @(CGRectGetMinX(frame) / w),
            @"y" : @(CGRectGetMinY(frame) / h),
            @"w" : @(CGRectGetWidth(frame) / w),
            @"h" : @(CGRectGetHeight(frame) / h),
        };
    }];
    return saved;
}

- (void)applyVirtualControllerLayoutDictionary:(NSDictionary*)layout {
    const CGFloat w = MAX(self.touchOverlay.bounds.size.width, 1.0);
    const CGFloat h = MAX(self.touchOverlay.bounds.size.height, 1.0);
    NSDictionary<NSString*, NSValue*>* defaults = [self defaultVirtualControllerFrames];
    [self.virtualControlButtons enumerateKeysAndObjectsUsingBlock:^(NSString* key, UIButton* button, BOOL* stop) {
        CGRect frame = defaults[key].CGRectValue;
        NSDictionary* normalized = layout[key];
        if ([normalized isKindOfClass:NSDictionary.class]) {
            frame = CGRectMake([normalized[@"x"] doubleValue] * w,
                               [normalized[@"y"] doubleValue] * h,
                               [normalized[@"w"] doubleValue] * w,
                               [normalized[@"h"] doubleValue] * h);
        }
        [UIView animateWithDuration:0.18
                         animations:^{
                             button.frame = CGRectIntegral(frame);
                             [self styleVirtualControlButton:button
                                                     pressed:[self.pressedVirtualControls containsObject:key]
                                                     editing:self.virtualLayoutEditing];
                         }];
    }];
}

- (void)applyDefaultVirtualControllerLayoutAnimated:(BOOL)animated {
    NSDictionary<NSString*, NSValue*>* defaults = [self defaultVirtualControllerFrames];
    [self.virtualControlButtons enumerateKeysAndObjectsUsingBlock:^(NSString* key, UIButton* button, BOOL* stop) {
        CGRect frame = defaults[key].CGRectValue;
        void (^changes)(void) = ^{
            button.frame = CGRectIntegral(frame);
            [self styleVirtualControlButton:button
                                    pressed:[self.pressedVirtualControls containsObject:key]
                                    editing:self.virtualLayoutEditing];
        };
        if (animated) {
            [UIView animateWithDuration:0.18 animations:changes];
        } else {
            changes();
        }
    }];
}

- (UIColor*)virtualControlAccentColorForKey:(NSString*)key {
    if ([key isEqualToString:@"triangle"]) {
        return [UIColor colorWithRed:0.40 green:0.92 blue:0.62 alpha:1.0];
    }
    if ([key isEqualToString:@"circle"]) {
        return [UIColor colorWithRed:1.0 green:0.36 blue:0.44 alpha:1.0];
    }
    if ([key isEqualToString:@"cross"]) {
        return [UIColor colorWithRed:0.35 green:0.68 blue:1.0 alpha:1.0];
    }
    if ([key isEqualToString:@"square"]) {
        return [UIColor colorWithRed:1.0 green:0.46 blue:0.78 alpha:1.0];
    }
    return [UIColor colorWithWhite:1.0 alpha:0.78];
}

- (void)removeVirtualControlDecorationLayers:(UIButton*)button {
    NSMutableArray<CALayer*>* layersToRemove = [NSMutableArray array];
    for (CALayer* layer in button.layer.sublayers) {
        if ([layer.name hasPrefix:@"ShadVirtualDecoration"]) {
            [layersToRemove addObject:layer];
        }
    }
    for (CALayer* layer in layersToRemove) {
        [layer removeFromSuperlayer];
    }
}

- (CALayer*)virtualDecorationLayerWithFrame:(CGRect)frame
                                cornerRadius:(CGFloat)radius
                                       color:(UIColor*)color
                                      border:(UIColor*)border {
    CALayer* layer = [CALayer layer];
    layer.name = @"ShadVirtualDecoration";
    layer.frame = CGRectIntegral(frame);
    layer.cornerRadius = radius;
    layer.backgroundColor = color.CGColor;
    layer.borderColor = border.CGColor;
    layer.borderWidth = 1.0;
    return layer;
}

- (void)styleVirtualControlButton:(UIButton*)button pressed:(BOOL)pressed editing:(BOOL)editing {
    NSString* key = button.accessibilityIdentifier ?: @"";
    UIColor* accent = [self virtualControlAccentColorForKey:key];
    const BOOL faceButton = [@[@"square", @"triangle", @"cross", @"circle"] containsObject:key];
    const BOOL shoulder = [@[@"l1", @"l2", @"r1", @"r2"] containsObject:key];
    const BOOL systemButton = [@[@"share", @"options"] containsObject:key];
    const BOOL stick = [key hasSuffix:@"Stick"];
    const BOOL dpad = [key isEqualToString:@"dpad"];
    const BOOL selectedForEdit = editing && [self.selectedVirtualControlKey isEqualToString:key];
    const CGFloat alpha = pressed ? 0.58 : 0.28;

    [self removeVirtualControlDecorationLayers:button];
    button.layer.masksToBounds = NO;
    button.layer.borderWidth = selectedForEdit ? 3.0 : (editing ? 2.0 : 1.15);
    button.layer.borderColor = (selectedForEdit ? [UIColor colorWithRed:0.35 green:0.78 blue:1.0 alpha:1.0]
                                        : editing ? [UIColor colorWithRed:0.55 green:0.88 blue:1.0 alpha:1.0]
                                        : [UIColor colorWithWhite:1.0 alpha:0.34])
                                   .CGColor;
    button.layer.shadowColor = selectedForEdit ? [UIColor colorWithRed:0.35 green:0.78 blue:1.0 alpha:1.0].CGColor
                                               : UIColor.blackColor.CGColor;
    button.layer.shadowOpacity = selectedForEdit ? 0.62 : 0.30;
    button.layer.shadowRadius = selectedForEdit ? 18.0 : 12.0;
    button.backgroundColor = [UIColor colorWithWhite:0.02 alpha:alpha];
    [button setTitleColor:faceButton ? accent : [UIColor colorWithWhite:1.0 alpha:0.88] forState:UIControlStateNormal];

    if (shoulder || systemButton) {
        button.layer.cornerRadius = 18.0;
        button.titleLabel.font = [UIFont systemFontOfSize:systemButton ? 11.0 : 15.0
                                                   weight:UIFontWeightSemibold];
        button.backgroundColor = [UIColor colorWithWhite:0.02 alpha:pressed ? 0.52 : (systemButton ? 0.24 : 0.32)];
    } else if (dpad) {
        button.layer.cornerRadius = 16.0;
        button.backgroundColor = UIColor.clearColor;
        CGFloat w = CGRectGetWidth(button.bounds);
        CGFloat h = CGRectGetHeight(button.bounds);
        CGFloat arm = MIN(w, h) * 0.34;
        UIColor* fill = [UIColor colorWithWhite:0.02 alpha:pressed ? 0.66 : 0.42];
        UIColor* stroke = [UIColor colorWithWhite:1.0 alpha:pressed ? 0.68 : 0.34];
        CALayer* vertical = [self virtualDecorationLayerWithFrame:CGRectMake((w - arm) * 0.5, 4.0, arm, h - 8.0)
                                                    cornerRadius:10.0
                                                           color:fill
                                                          border:stroke];
        CALayer* horizontal = [self virtualDecorationLayerWithFrame:CGRectMake(4.0, (h - arm) * 0.5, w - 8.0, arm)
                                                      cornerRadius:10.0
                                                             color:fill
                                                            border:stroke];
        [button.layer insertSublayer:vertical atIndex:0];
        [button.layer insertSublayer:horizontal atIndex:1];
    } else if (stick) {
        button.layer.cornerRadius = MIN(button.bounds.size.width, button.bounds.size.height) * 0.5;
        button.backgroundColor = [UIColor colorWithWhite:0.02 alpha:pressed ? 0.54 : 0.32];
        button.titleLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
        CGFloat inset = MIN(button.bounds.size.width, button.bounds.size.height) * 0.20;
        CALayer* inner = [self virtualDecorationLayerWithFrame:CGRectInset(button.bounds, inset, inset)
                                                  cornerRadius:MIN(button.bounds.size.width, button.bounds.size.height) * 0.30
                                                         color:[UIColor colorWithWhite:1.0 alpha:pressed ? 0.18 : 0.10]
                                                        border:[UIColor colorWithWhite:1.0 alpha:0.26]];
        [button.layer insertSublayer:inner atIndex:0];
    } else {
        button.layer.cornerRadius = MIN(button.bounds.size.width, button.bounds.size.height) * 0.5;
        button.titleLabel.font = [UIFont systemFontOfSize:25.0 weight:UIFontWeightMedium];
        button.backgroundColor = [UIColor colorWithWhite:0.02 alpha:pressed ? 0.54 : 0.30];
        CGFloat inset = MIN(button.bounds.size.width, button.bounds.size.height) * 0.16;
        CALayer* ring = [self virtualDecorationLayerWithFrame:CGRectInset(button.bounds, inset, inset)
                                                 cornerRadius:MIN(button.bounds.size.width, button.bounds.size.height) * 0.34
                                                        color:UIColor.clearColor
                                                       border:[accent colorWithAlphaComponent:pressed ? 0.78 : 0.46]];
        [button.layer insertSublayer:ring atIndex:0];
    }

    button.transform = pressed ? CGAffineTransformMakeScale(0.94, 0.94) : CGAffineTransformIdentity;
}

- (void)updateVirtualControlAppearance:(UIButton*)button pressed:(BOOL)pressed {
    [UIView animateWithDuration:0.08
                          delay:0.0
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState |
                                UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         [self styleVirtualControlButton:button pressed:pressed editing:self.virtualLayoutEditing];
                     }
                     completion:nil];
}

- (void)setVirtualControl:(NSString*)control pressed:(BOOL)pressed {
    if (control.length == 0) {
        return;
    }
    if (pressed) {
        [self.pressedVirtualControls addObject:control];
    } else {
        [self.pressedVirtualControls removeObject:control];
    }

    ShadVirtualPadState state = {};
    state.dpad = [self.pressedVirtualControls containsObject:@"dpad"];
    state.l1 = [self.pressedVirtualControls containsObject:@"l1"];
    state.l2 = [self.pressedVirtualControls containsObject:@"l2"];
    state.r1 = [self.pressedVirtualControls containsObject:@"r1"];
    state.r2 = [self.pressedVirtualControls containsObject:@"r2"];
    state.square = [self.pressedVirtualControls containsObject:@"square"];
    state.triangle = [self.pressedVirtualControls containsObject:@"triangle"];
    state.cross = [self.pressedVirtualControls containsObject:@"cross"];
    state.circle = [self.pressedVirtualControls containsObject:@"circle"];
    state.share = [self.pressedVirtualControls containsObject:@"share"];
    state.options = [self.pressedVirtualControls containsObject:@"options"];
    state.leftStick = [self.pressedVirtualControls containsObject:@"leftStick"];
    state.rightStick = [self.pressedVirtualControls containsObject:@"rightStick"];
    self.virtualPadState = state;

    UIButton* button = self.virtualControlButtons[control];
    if (button != nil) {
        [self updateVirtualControlAppearance:button pressed:pressed];
    }

    [self forwardVirtualControl:control pressed:pressed];
    NSLog(@"shadPS4 iOS: virtual control %@ %@", control, pressed ? @"pressed" : @"released");
}

- (void)forwardVirtualControl:(NSString*)control pressed:(BOOL)pressed {
    ShadIOSCoreBridge* bridge = [ShadIOSCoreBridge sharedBridge];
    if ([control isEqualToString:@"l2"]) {
        [bridge setLeftTrigger:pressed ? 1.0f : 0.0f];
    } else if ([control isEqualToString:@"r2"]) {
        [bridge setRightTrigger:pressed ? 1.0f : 0.0f];
    } else if ([control isEqualToString:@"dpad"]) {
        if (!pressed) {
            [bridge setDpadX:0.0f y:0.0f];
        }
    } else if ([control isEqualToString:@"leftStick"]) {
        if (!pressed) {
            [bridge setLeftStickX:0.0f y:0.0f];
        }
    } else if ([control isEqualToString:@"rightStick"]) {
        if (!pressed) {
            [bridge setRightStickX:0.0f y:0.0f];
        }
    } else {
        [bridge setButton:control pressed:pressed];
    }
}

- (CGPoint)normalizedPointForTouchEvent:(UIEvent*)event inControl:(UIView*)control {
    UITouch* touch = event.allTouches.anyObject;
    CGPoint location = touch != nil ? [touch locationInView:control]
                                    : CGPointMake(CGRectGetMidX(control.bounds), CGRectGetMidY(control.bounds));
    CGFloat halfW = MAX(CGRectGetWidth(control.bounds) * 0.5, 1.0);
    CGFloat halfH = MAX(CGRectGetHeight(control.bounds) * 0.5, 1.0);
    CGFloat x = MIN(MAX((location.x - halfW) / halfW, -1.0), 1.0);
    CGFloat y = MIN(MAX((halfH - location.y) / halfH, -1.0), 1.0);
    return CGPointMake(x, y);
}

- (void)forwardDirectionalControl:(UIButton*)sender event:(UIEvent*)event pressed:(BOOL)pressed {
    NSString* key = sender.accessibilityIdentifier;
    ShadIOSCoreBridge* bridge = [ShadIOSCoreBridge sharedBridge];
    if (!pressed) {
        if ([key isEqualToString:@"dpad"]) {
            [bridge setDpadX:0.0f y:0.0f];
        } else if ([key isEqualToString:@"leftStick"]) {
            [bridge setLeftStickX:0.0f y:0.0f];
        } else if ([key isEqualToString:@"rightStick"]) {
            [bridge setRightStickX:0.0f y:0.0f];
        }
        return;
    }

    CGPoint vector = [self normalizedPointForTouchEvent:event inControl:sender];
    if ([key isEqualToString:@"dpad"]) {
        if (fabs(vector.x) > fabs(vector.y)) {
            [bridge setDpadX:(vector.x >= 0.0 ? 1.0f : -1.0f) y:0.0f];
        } else {
            [bridge setDpadX:0.0f y:(vector.y >= 0.0 ? 1.0f : -1.0f)];
        }
    } else if ([key isEqualToString:@"leftStick"]) {
        [bridge setLeftStickX:vector.x y:vector.y];
    } else if ([key isEqualToString:@"rightStick"]) {
        [bridge setRightStickX:vector.x y:vector.y];
    }
}

- (void)virtualControlTouchDown:(UIButton*)sender event:(UIEvent*)event {
    if (self.virtualLayoutEditing) {
        [self selectVirtualControlForLayout:sender];
        return;
    }
    [self setVirtualControl:sender.accessibilityIdentifier pressed:YES];
    [self forwardDirectionalControl:sender event:event pressed:YES];
}

- (void)virtualControlTouchUp:(UIButton*)sender event:(UIEvent*)event {
    if (self.virtualLayoutEditing) {
        return;
    }
    [self forwardDirectionalControl:sender event:event pressed:NO];
    [self setVirtualControl:sender.accessibilityIdentifier pressed:NO];
}

- (void)virtualControlDragged:(UIPanGestureRecognizer*)recognizer {
    if (!self.virtualLayoutEditing) {
        UIButton* control = (UIButton*)recognizer.view;
        NSString* key = control.accessibilityIdentifier;
        if ([key isEqualToString:@"dpad"] || [key isEqualToString:@"leftStick"] || [key isEqualToString:@"rightStick"]) {
            CGPoint translation = [recognizer translationInView:control];
            CGFloat radius = MAX(MIN(control.bounds.size.width, control.bounds.size.height) * 0.42, 1.0);
            CGPoint vector = CGPointMake(MIN(MAX(translation.x / radius, -1.0), 1.0),
                                         MIN(MAX(-translation.y / radius, -1.0), 1.0));
            ShadIOSCoreBridge* bridge = [ShadIOSCoreBridge sharedBridge];
            if (recognizer.state == UIGestureRecognizerStateEnded ||
                recognizer.state == UIGestureRecognizerStateCancelled ||
                recognizer.state == UIGestureRecognizerStateFailed) {
                vector = CGPointZero;
            }
            if ([key isEqualToString:@"dpad"]) {
                [bridge setDpadX:vector.x y:vector.y];
            } else if ([key isEqualToString:@"leftStick"]) {
                [bridge setLeftStickX:vector.x y:vector.y];
            } else {
                [bridge setRightStickX:vector.x y:vector.y];
            }
        }
        return;
    }
    UIButton* control = (UIButton*)recognizer.view;
    [self selectVirtualControlForLayout:control];
    CGPoint translation = [recognizer translationInView:self.touchOverlay];
    CGPoint center = CGPointMake(control.center.x + translation.x, control.center.y + translation.y);
    const CGFloat halfW = control.bounds.size.width * 0.5;
    const CGFloat halfH = control.bounds.size.height * 0.5;
    center.x = MIN(MAX(center.x, halfW), self.touchOverlay.bounds.size.width - halfW);
    center.y = MIN(MAX(center.y, halfH), self.touchOverlay.bounds.size.height - halfH);
    control.center = center;
    [recognizer setTranslation:CGPointZero inView:self.touchOverlay];

    if (recognizer.state == UIGestureRecognizerStateBegan || recognizer.state == UIGestureRecognizerStateChanged) {
        self.virtualLayoutEditHintLabel.text = @"Layout changed. Tap Save Layout to keep it.";
    }
}

- (void)virtualControlPinched:(UIPinchGestureRecognizer*)recognizer {
    if (!self.virtualLayoutEditing) {
        return;
    }
    UIButton* control = (UIButton*)recognizer.view;
    [self selectVirtualControlForLayout:control];
    [self resizeVirtualControl:control byScale:recognizer.scale animated:NO];
    recognizer.scale = 1.0;
    self.virtualLayoutEditHintLabel.text = @"Size changed. Tap Save Layout to keep it.";
}

- (void)selectVirtualControlForLayout:(UIButton*)button {
    NSString* key = button.accessibilityIdentifier;
    if (key.length == 0) {
        return;
    }
    self.selectedVirtualControlKey = key;
    [self.virtualControlButtons enumerateKeysAndObjectsUsingBlock:^(NSString* controlKey, UIButton* controlButton, BOOL* stop) {
        [self styleVirtualControlButton:controlButton
                                pressed:[self.pressedVirtualControls containsObject:controlKey]
                                editing:self.virtualLayoutEditing];
    }];
    self.virtualLayoutEditHintLabel.text = [NSString stringWithFormat:@"%@ selected. Drag, pinch, or use Bigger/Smaller.", key];
}

- (void)resizeVirtualControl:(UIButton*)button byScale:(CGFloat)scale animated:(BOOL)animated {
    if (button == nil) {
        return;
    }
    const CGFloat overlayW = MAX(CGRectGetWidth(self.touchOverlay.bounds), 1.0);
    const CGFloat overlayH = MAX(CGRectGetHeight(self.touchOverlay.bounds), 1.0);
    CGRect frame = button.frame;
    CGPoint center = CGPointMake(CGRectGetMidX(frame), CGRectGetMidY(frame));
    CGFloat minSide = 42.0;
    CGFloat maxSide = MIN(overlayW, overlayH) * 0.26;
    CGFloat newW = MIN(MAX(CGRectGetWidth(frame) * scale, minSide), maxSide);
    CGFloat newH = MIN(MAX(CGRectGetHeight(frame) * scale, minSide), maxSide);
    const BOOL dpad = [button.accessibilityIdentifier isEqualToString:@"dpad"];
    const BOOL shoulder = [@[@"l1", @"l2", @"r1", @"r2"] containsObject:button.accessibilityIdentifier ?: @""];
    const BOOL systemButton = [@[@"share", @"options"] containsObject:button.accessibilityIdentifier ?: @""];
    if (dpad) {
        newH = newW;
    } else if (shoulder || systemButton) {
        newH = MIN(MAX(newW * 0.85, 38.0), 86.0);
        if (systemButton) {
            newH = MIN(MAX(newW * 0.40, 34.0), 58.0);
        }
    } else {
        CGFloat side = MIN(MAX(MAX(newW, newH), minSide), maxSide);
        newW = side;
        newH = side;
    }
    CGFloat originX = MIN(MAX(center.x - newW * 0.5, 0.0), overlayW - newW);
    CGFloat originY = MIN(MAX(center.y - newH * 0.5, 0.0), overlayH - newH);
    CGRect resized = CGRectIntegral(CGRectMake(originX, originY, newW, newH));
    void (^changes)(void) = ^{
        button.frame = resized;
        [self styleVirtualControlButton:button
                                pressed:[self.pressedVirtualControls containsObject:button.accessibilityIdentifier ?: @""]
                                editing:self.virtualLayoutEditing];
    };
    if (animated) {
        [UIView animateWithDuration:0.12 animations:changes];
    } else {
        changes();
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    for (CALayer* layer in self.dashboardView.layer.sublayers) {
        if ([layer.name isEqualToString:@"DashboardGradient"]) {
            layer.frame = self.dashboardView.bounds;
            break;
        }
    }

    [self applyVirtualControllerLayoutIfNeeded];
}

- (void)loadGameLibrary {
    NSArray* stored = [[NSUserDefaults standardUserDefaults] arrayForKey:ShadGameLibraryDefaultsKey];
    NSMutableSet<NSString*>* seenKeys = [NSMutableSet set];
    for (NSDictionary* item in stored) {
        NSString* path = item[@"path"];
        if (path.length == 0) {
            continue;
        }
        NSString* key = [self duplicateKeyForPath:path title:item[@"title"] sourceName:item[@"sourceName"]];
        if ([seenKeys containsObject:key]) {
            continue;
        }
        [seenKeys addObject:key];
        [self.games addObject:[item mutableCopy]];
    }

    [self scanSandboxGameLibrary];

    self.selectedGameIndex = self.games.count > 0 ? 0 : 0;
    [self refreshMissingCompatibilityRecords];
}

- (void)scanSandboxGameLibrary {
    NSFileManager* fm = NSFileManager.defaultManager;
    NSURL* gamesDir = [self gamesDirectoryCreatingIfNeeded:NO error:nil];
    NSArray<NSURL*>* urls = [fm contentsOfDirectoryAtURL:gamesDir
                              includingPropertiesForKeys:@[ NSURLIsDirectoryKey ]
                                                 options:NSDirectoryEnumerationSkipsHiddenFiles
                                                   error:nil];

    NSMutableSet<NSString*>* knownPaths = [NSMutableSet set];
    NSMutableSet<NSString*>* knownKeys = [NSMutableSet set];
    for (NSDictionary* game in self.games) {
        NSString* path = game[@"path"];
        if (path.length > 0) {
            [knownPaths addObject:path];
        }
        [knownKeys addObject:[self duplicateKeyForPath:path title:game[@"title"] sourceName:game[@"sourceName"]]];
    }

    for (NSURL* url in urls) {
        if ([knownPaths containsObject:url.path]) {
            continue;
        }

        NSNumber* isDirectory = nil;
        [url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
        NSDictionary* psf = [self psfMetadataForGamePath:url.path];
        NSString* title = psf[@"title"] ?: url.lastPathComponent.stringByDeletingPathExtension;
        NSString* key = [self duplicateKeyForPath:url.path title:title sourceName:url.lastPathComponent];
        if ([knownKeys containsObject:key]) {
            continue;
        }
        NSString* detail = isDirectory.boolValue ? @"Imported game folder" : @"Imported game file";
        [self.games addObject:[@{
            @"title" : title.length > 0 ? title : @"Imported Game",
            @"detail" : detail,
        @"path" : url.path ?: @"",
        @"serial" : psf[@"serial"] ?: @"",
        @"version" : psf[@"version"] ?: @"1.00",
        @"sourceName" : url.lastPathComponent ?: @"",
            @"compatibilityStatus" : psf[@"serial"] ? @"Checking compatibility..." : @"Compatibility unknown",
            @"compatibilitySummary" : psf[@"serial"] ? @"Reading shadPS4 compatibility report" : @"No TITLE_ID found in param.sfo",
            @"lastPlayed" : @"Last played: never",
        } mutableCopy]];
        [knownKeys addObject:key];
    }
}

- (NSString*)duplicateKeyForPath:(NSString*)path title:(NSString*)title sourceName:(NSString*)sourceName {
    NSString* base = sourceName.length > 0 ? sourceName : path.lastPathComponent;
    if (base.length == 0) {
        base = title.length > 0 ? title : path;
    }
    return base.lowercaseString ?: @"";
}

- (NSInteger)existingGameIndexForURL:(NSURL*)sourceURL {
    NSString* key = [self duplicateKeyForPath:sourceURL.path
                                        title:sourceURL.lastPathComponent.stringByDeletingPathExtension
                                   sourceName:sourceURL.lastPathComponent];
    for (NSUInteger i = 0; i < self.games.count; i++) {
        NSDictionary* game = self.games[i];
        NSString* gameKey = [self duplicateKeyForPath:game[@"path"] title:game[@"title"] sourceName:game[@"sourceName"]];
        if ([gameKey isEqualToString:key]) {
            return (NSInteger)i;
        }
    }
    return NSNotFound;
}

- (void)refreshMissingCompatibilityRecords {
    for (NSUInteger i = 0; i < self.games.count; i++) {
        NSMutableDictionary* game = self.games[i];
        if (((NSString*)game[@"serial"]).length == 0) {
            NSDictionary* psf = [self psfMetadataForGamePath:game[@"path"]];
            if (((NSString*)psf[@"title"]).length > 0) {
                game[@"title"] = psf[@"title"];
            }
            if (((NSString*)psf[@"serial"]).length > 0) {
                game[@"serial"] = psf[@"serial"];
            }
            if (((NSString*)psf[@"version"]).length > 0) {
                game[@"version"] = psf[@"version"];
            }
        }

        NSString* serial = game[@"serial"];
        NSString* status = game[@"compatibilityStatus"];
        if (serial.length > 0 && (status.length == 0 || [status hasPrefix:@"Checking"])) {
            game[@"compatibilityStatus"] = @"Checking compatibility...";
            game[@"compatibilitySummary"] = @"Reading shadPS4 compatibility report";
            [self fetchCompatibilityForGameAtIndex:(NSInteger)i];
        } else if (serial.length == 0 && status.length == 0) {
            game[@"compatibilityStatus"] = @"Compatibility unknown";
            game[@"compatibilitySummary"] = @"No TITLE_ID found in param.sfo";
        }
    }
    [self saveGameLibrary];
}

- (NSDictionary*)psfMetadataForGamePath:(NSString*)path {
    NSString* psfPath = [self paramSFOPathForGamePath:path];
    if (psfPath.length == 0) {
        return @{};
    }

    NSData* data = [NSData dataWithContentsOfFile:psfPath options:0 error:nil];
    if (data.length < 20) {
        return @{};
    }

    const uint8_t* bytes = (const uint8_t*)data.bytes;
    uint32_t (^read32)(NSUInteger) = ^uint32_t(NSUInteger offset) {
        if (offset + 4 > data.length) {
            return 0;
        }
        return (uint32_t)bytes[offset] | ((uint32_t)bytes[offset + 1] << 8) |
               ((uint32_t)bytes[offset + 2] << 16) | ((uint32_t)bytes[offset + 3] << 24);
    };
    uint16_t (^read16)(NSUInteger) = ^uint16_t(NSUInteger offset) {
        if (offset + 2 > data.length) {
            return 0;
        }
        return (uint16_t)bytes[offset] | ((uint16_t)bytes[offset + 1] << 8);
    };

    if (read32(0) != 0x46535000) {
        return @{};
    }

    const uint32_t keyTableOffset = read32(8);
    const uint32_t dataTableOffset = read32(12);
    const uint32_t entryCount = read32(16);
    NSMutableDictionary* metadata = [NSMutableDictionary dictionary];

    for (uint32_t i = 0; i < entryCount; i++) {
        const NSUInteger entryOffset = 20 + (NSUInteger)i * 16;
        if (entryOffset + 16 > data.length) {
            break;
        }

        const uint16_t keyOffset = read16(entryOffset);
        const uint32_t dataLength = read32(entryOffset + 4);
        const uint32_t valueOffset = read32(entryOffset + 12);
        NSUInteger keyStart = keyTableOffset + keyOffset;
        NSUInteger keyEnd = keyStart;
        while (keyEnd < data.length && bytes[keyEnd] != 0) {
            keyEnd++;
        }
        if (keyEnd <= keyStart || keyEnd >= data.length) {
            continue;
        }

        NSString* key = [[NSString alloc] initWithBytes:bytes + keyStart
                                                 length:keyEnd - keyStart
                                               encoding:NSUTF8StringEncoding];
        if (![key isEqualToString:@"TITLE"] && ![key isEqualToString:@"TITLE_ID"] &&
            ![key isEqualToString:@"APP_VER"] && ![key isEqualToString:@"VERSION"]) {
            continue;
        }

        NSUInteger valueStart = dataTableOffset + valueOffset;
        NSUInteger valueLength = MIN((NSUInteger)dataLength, data.length > valueStart ? data.length - valueStart : 0);
        while (valueLength > 0 && bytes[valueStart + valueLength - 1] == 0) {
            valueLength--;
        }
        if (valueLength == 0) {
            continue;
        }

        NSString* value = [[NSString alloc] initWithBytes:bytes + valueStart
                                                   length:valueLength
                                                 encoding:NSUTF8StringEncoding];
        if (value.length == 0) {
            continue;
        }
        if ([key isEqualToString:@"TITLE"]) {
            metadata[@"title"] = value;
        } else if ([key isEqualToString:@"TITLE_ID"]) {
            metadata[@"serial"] = value.uppercaseString;
        } else if ([key isEqualToString:@"APP_VER"] || [key isEqualToString:@"VERSION"]) {
            metadata[@"version"] = value;
        }
    }

    return metadata;
}

- (void)fetchCompatibilityForGameAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)self.games.count) {
        return;
    }

    NSMutableDictionary* game = self.games[(NSUInteger)index];
    NSString* serial = game[@"serial"];
    if (serial.length == 0) {
        return;
    }

    NSString* encodedSerial =
        [serial stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet];
    NSURL* url = [NSURL URLWithString:[ShadCompatibilityBaseURL stringByAppendingFormat:@"%@&per_page=5", encodedSerial]];
    if (url == nil) {
        return;
    }

    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = 12.0;
    [request setValue:@"application/vnd.github+json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"shadPS4-iOS-dashboard" forHTTPHeaderField:@"User-Agent"];

    NSURLSessionDataTask* task =
        [NSURLSession.sharedSession dataTaskWithRequest:request
                                      completionHandler:^(NSData* data, NSURLResponse* response, NSError* error) {
                                          dispatch_async(dispatch_get_main_queue(), ^{
                                              if (index < 0 || index >= (NSInteger)self.games.count) {
                                                  return;
                                              }

                                              NSMutableDictionary* target = self.games[(NSUInteger)index];
                                              NSDictionary* parsed =
                                                  [self compatibilityResultFromData:data serial:serial error:error];
                                              target[@"compatibilityStatus"] = parsed[@"status"];
                                              target[@"compatibilitySummary"] = parsed[@"summary"];
                                              target[@"compatibilityURL"] = parsed[@"url"] ?: @"";
                                              target[@"compatibilityUpdated"] = [self shortDateString];
                                              [self saveGameLibrary];
                                              [self refreshGameRow];
                                              [self updateSelectedGameAnimated:NO];
                                              NSLog(@"shadPS4 iOS: compatibility %@ -> %@",
                                                    serial,
                                                    target[@"compatibilityStatus"]);
                                          });
                                      }];
    [task resume];
}

- (NSDictionary*)compatibilityResultFromData:(NSData*)data serial:(NSString*)serial error:(NSError*)error {
    if (error != nil || data.length == 0) {
        return @{
            @"status" : @"Compatibility unavailable",
            @"summary" : @"Could not reach shadPS4 compatibility service",
            @"url" : @"",
        };
    }

    NSError* jsonError = nil;
    NSDictionary* root = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    NSArray* items = [root isKindOfClass:NSDictionary.class] ? root[@"items"] : nil;
    if (jsonError != nil || ![items isKindOfClass:NSArray.class] || items.count == 0) {
        return @{
            @"status" : @"Compatibility unknown",
            @"summary" : [NSString stringWithFormat:@"No shadPS4 report found for %@", serial],
            @"url" : @"",
        };
    }

    NSDictionary* bestIssue = nil;
    for (NSDictionary* issue in items) {
        NSString* title = issue[@"title"];
        if ([title.uppercaseString containsString:serial.uppercaseString]) {
            bestIssue = issue;
            break;
        }
    }
    if (bestIssue == nil) {
        bestIssue = items.firstObject;
    }

    NSString* status = @"Compatibility unknown";
    NSString* summary = @"Report exists, status label not found";
    UIColor* unusedColor = nil;
    NSArray* labels = bestIssue[@"labels"];
    for (NSDictionary* label in labels) {
        NSString* name = [label[@"name"] lowercaseString];
        NSDictionary* mapped = [self compatibilityDisplayForLabel:name color:&unusedColor];
        if (mapped != nil) {
            status = mapped[@"status"];
            summary = mapped[@"summary"];
            break;
        }
    }

    NSString* title = bestIssue[@"title"] ?: serial;
    NSString* htmlURL = bestIssue[@"html_url"] ?: @"";
    return @{
        @"status" : status,
        @"summary" : [NSString stringWithFormat:@"%@ - %@", summary, title],
        @"url" : htmlURL,
    };
}

- (NSDictionary*)compatibilityDisplayForLabel:(NSString*)label color:(UIColor**)color {
    if ([label containsString:@"playable"]) {
        if (color != nil) {
            *color = [UIColor colorWithRed:0.42 green:1.0 blue:0.55 alpha:1.0];
        }
        return @{ @"status" : @"Playable", @"summary" : @"Runs well in shadPS4" };
    }
    if ([label containsString:@"ingame"] || [label containsString:@"in-game"]) {
        if (color != nil) {
            *color = [UIColor colorWithRed:0.72 green:0.88 blue:1.0 alpha:1.0];
        }
        return @{ @"status" : @"In Game", @"summary" : @"Boots and reaches gameplay, issues may remain" };
    }
    if ([label containsString:@"menus"]) {
        if (color != nil) {
            *color = [UIColor colorWithRed:1.0 green:0.83 blue:0.32 alpha:1.0];
        }
        return @{ @"status" : @"Menus", @"summary" : @"Reaches menus only" };
    }
    if ([label containsString:@"boots"]) {
        if (color != nil) {
            *color = [UIColor colorWithRed:1.0 green:0.58 blue:0.25 alpha:1.0];
        }
        return @{ @"status" : @"Boots", @"summary" : @"Boots but does not reach stable gameplay" };
    }
    if ([label containsString:@"nothing"]) {
        if (color != nil) {
            *color = [UIColor colorWithRed:1.0 green:0.32 blue:0.34 alpha:1.0];
        }
        return @{ @"status" : @"Nothing", @"summary" : @"Not currently playable in shadPS4" };
    }
    return nil;
}

- (NSString*)paramSFOPathForGamePath:(NSString*)path {
    if (path.length == 0) {
        return nil;
    }

    NSFileManager* fm = NSFileManager.defaultManager;
    BOOL isDirectory = NO;
    if (![fm fileExistsAtPath:path isDirectory:&isDirectory]) {
        return nil;
    }

    NSString* root = isDirectory ? path : path.stringByDeletingLastPathComponent;
    NSArray<NSString*>* candidates = @[
        [root stringByAppendingPathComponent:@"sce_sys/param.sfo"],
        [root stringByAppendingPathComponent:@"sce_sys/PARAM.SFO"],
        [root stringByAppendingPathComponent:@"param.sfo"],
        [root stringByAppendingPathComponent:@"PARAM.SFO"],
    ];
    for (NSString* candidate in candidates) {
        if ([fm fileExistsAtPath:candidate]) {
            return candidate;
        }
    }

    NSDirectoryEnumerator<NSString*>* enumerator = [fm enumeratorAtPath:root];
    NSUInteger inspected = 0;
    for (NSString* relativePath in enumerator) {
        inspected++;
        if (inspected > 500) {
            break;
        }
        if ([relativePath.lastPathComponent.lowercaseString isEqualToString:@"param.sfo"]) {
            return [root stringByAppendingPathComponent:relativePath];
        }
    }
    return nil;
}

- (void)saveGameLibrary {
    [[NSUserDefaults standardUserDefaults] setObject:self.games forKey:ShadGameLibraryDefaultsKey];
}

- (void)refreshGameRow {
    for (UIView* view in self.gameStack.arrangedSubviews) {
        [self.gameStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }
    [self.gameButtons removeAllObjects];

    for (NSUInteger i = 0; i < self.games.count; i++) {
        UIButton* button = [self gameButtonForIndex:i];
        [self.gameButtons addObject:button];
        [self.gameStack addArrangedSubview:button];
    }

    UIButton* addButton = [self addGameButton];
    self.addGameTile = addButton;
    [self.gameStack addArrangedSubview:addButton];
    [self updateSelectedGameAnimated:NO];
}

- (UIImage*)coverImageForGame:(NSDictionary*)game {
    NSString* coverPath = [self coverPathForGamePath:game[@"path"]];
    return coverPath.length > 0 ? [UIImage imageWithContentsOfFile:coverPath] : nil;
}

- (NSString*)coverPathForGamePath:(NSString*)path {
    if (path.length == 0) {
        return nil;
    }

    NSFileManager* fileManager = NSFileManager.defaultManager;
    BOOL isDirectory = NO;
    if (![fileManager fileExistsAtPath:path isDirectory:&isDirectory]) {
        return nil;
    }

    NSString* root = isDirectory ? path : path.stringByDeletingLastPathComponent;
    NSArray<NSString*>* priorityRelativePaths = @[
        @"sce_sys/icon0.png",
        @"sce_sys/pic1.png",
        @"sce_sys/pic0.png",
        @"sce_sys/livearea/contents/bg.png",
        @"icon0.png",
        @"pic1.png",
        @"pic0.png",
        @"cover.png",
        @"cover.jpg",
        @"cover.jpeg",
        @"icon.png",
        @"icon.jpg",
        @"poster.png",
        @"poster.jpg",
    ];

    for (NSString* relativePath in priorityRelativePaths) {
        NSString* candidate = [root stringByAppendingPathComponent:relativePath];
        if ([fileManager fileExistsAtPath:candidate]) {
            return candidate;
        }
    }

    NSSet<NSString*>* acceptedNames = [NSSet setWithArray:@[
        @"icon0.png", @"pic1.png", @"pic0.png", @"cover.png", @"cover.jpg", @"cover.jpeg", @"icon.png",
        @"icon.jpg", @"poster.png", @"poster.jpg", @"bg.png",
    ]];
    NSDirectoryEnumerator<NSString*>* enumerator = [fileManager enumeratorAtPath:root];
    NSUInteger inspected = 0;
    for (NSString* relativePath in enumerator) {
        inspected++;
        if (inspected > 700) {
            break;
        }
        NSString* fileName = relativePath.lastPathComponent.lowercaseString;
        if ([acceptedNames containsObject:fileName]) {
            NSString* candidate = [root stringByAppendingPathComponent:relativePath];
            BOOL candidateIsDirectory = NO;
            if ([fileManager fileExistsAtPath:candidate isDirectory:&candidateIsDirectory] && !candidateIsDirectory) {
                return candidate;
            }
        }
    }

    return nil;
}

- (UIButton*)gameButtonForIndex:(NSUInteger)index {
    NSDictionary* game = self.games[index];
    UIButton* button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.tag = (NSInteger)index;
    button.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.18];
    button.layer.cornerRadius = 1.0;
    button.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.26].CGColor;
    button.layer.borderWidth = 1.0;
    button.clipsToBounds = NO;
    [button.widthAnchor constraintEqualToConstant:184.0].active = YES;
    [button.heightAnchor constraintEqualToConstant:198.0].active = YES;
    [button addTarget:self action:@selector(gamePressed:) forControlEvents:UIControlEventTouchUpInside];

    UIImage* cover = [self coverImageForGame:game];
    UIImageView* image = [[UIImageView alloc] initWithImage:cover ?: [UIImage systemImageNamed:@"gamecontroller.fill"]];
    image.tag = 9001;
    image.translatesAutoresizingMaskIntoConstraints = NO;
    image.tintColor = [UIColor colorWithWhite:1.0 alpha:0.72];
    image.contentMode = cover ? UIViewContentModeScaleAspectFill : UIViewContentModeCenter;
    image.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
    image.clipsToBounds = YES;
    image.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.18].CGColor;
    image.layer.borderWidth = 1.0;
    [button addSubview:image];

    UILabel* startStrip = [[UILabel alloc] init];
    startStrip.tag = 9002;
    startStrip.translatesAutoresizingMaskIntoConstraints = NO;
    startStrip.text = @"Start";
    startStrip.textAlignment = NSTextAlignmentCenter;
    startStrip.textColor = [UIColor colorWithWhite:1.0 alpha:0.82];
    startStrip.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightRegular];
    startStrip.backgroundColor = [UIColor colorWithRed:0.05 green:0.28 blue:0.72 alpha:0.88];
    startStrip.hidden = YES;
    [button addSubview:startStrip];

    UILabel* compatibilityBadge = [[UILabel alloc] init];
    compatibilityBadge.tag = 9003;
    compatibilityBadge.translatesAutoresizingMaskIntoConstraints = NO;
    compatibilityBadge.text = [self shortCompatibilityStatusForGame:game];
    compatibilityBadge.textAlignment = NSTextAlignmentCenter;
    compatibilityBadge.textColor = UIColor.whiteColor;
    compatibilityBadge.font = [UIFont systemFontOfSize:10.0 weight:UIFontWeightSemibold];
    compatibilityBadge.backgroundColor = [self compatibilityTintForStatus:game[@"compatibilityStatus"]];
    compatibilityBadge.layer.cornerRadius = 4.0;
    compatibilityBadge.clipsToBounds = YES;
    compatibilityBadge.hidden = ((NSString*)game[@"compatibilityStatus"]).length == 0;
    [button addSubview:compatibilityBadge];

    [NSLayoutConstraint activateConstraints:@[
        [image.leadingAnchor constraintEqualToAnchor:button.leadingAnchor],
        [image.trailingAnchor constraintEqualToAnchor:button.trailingAnchor],
        [image.topAnchor constraintEqualToAnchor:button.topAnchor],
        [image.bottomAnchor constraintEqualToAnchor:button.bottomAnchor],

        [startStrip.leadingAnchor constraintEqualToAnchor:image.leadingAnchor],
        [startStrip.trailingAnchor constraintEqualToAnchor:image.trailingAnchor],
        [startStrip.bottomAnchor constraintEqualToAnchor:image.bottomAnchor],
        [startStrip.heightAnchor constraintEqualToConstant:30.0],

        [compatibilityBadge.leadingAnchor constraintEqualToAnchor:image.leadingAnchor constant:6.0],
        [compatibilityBadge.topAnchor constraintEqualToAnchor:image.topAnchor constant:6.0],
        [compatibilityBadge.widthAnchor constraintGreaterThanOrEqualToConstant:62.0],
        [compatibilityBadge.heightAnchor constraintEqualToConstant:22.0],
    ]];

    return button;
}

- (NSString*)shortTitleForGame:(NSString*)title {
    if (title.length <= 22) {
        return title;
    }
    return [[title substringToIndex:21] stringByAppendingString:@"…"];
}

- (NSString*)shortCompatibilityStatusForGame:(NSDictionary*)game {
    NSString* status = game[@"compatibilityStatus"];
    if (status.length == 0) {
        return @"Unknown";
    }
    if ([status hasPrefix:@"Checking"]) {
        return @"Checking";
    }
    return status.length > 11 ? [status substringToIndex:11] : status;
}

- (NSString*)compatibilityLineForGame:(NSDictionary*)game {
    NSString* serial = game[@"serial"];
    NSString* status = game[@"compatibilityStatus"];
    NSString* summary = game[@"compatibilitySummary"];
    if (status.length == 0) {
        status = serial.length > 0 ? @"Checking compatibility..." : @"Compatibility unknown";
    }
    if (summary.length == 0) {
        summary = serial.length > 0 ? @"Waiting for shadPS4 report" : @"No TITLE_ID found in param.sfo";
    }
    NSString* prefix = serial.length > 0 ? [NSString stringWithFormat:@"%@  ", serial] : @"";
    return [NSString stringWithFormat:@"Compatibility: %@%@ - %@", prefix, status, summary];
}

- (NSString*)gameVersionForGame:(NSDictionary*)game {
    NSString* version = game[@"version"];
    if (version.length > 0) {
        return version;
    }
    NSDictionary* psf = [self psfMetadataForGamePath:game[@"path"]];
    version = psf[@"version"];
    return version.length > 0 ? version : @"1.00";
}

- (UIColor*)compatibilityTextColorForStatus:(NSString*)status {
    if ([status hasPrefix:@"Checking"]) {
        return [UIColor colorWithRed:0.64 green:0.84 blue:1.0 alpha:1.0];
    }
    return [self compatibilityTintForStatus:status];
}

- (UIColor*)compatibilityTintForStatus:(NSString*)status {
    NSString* lower = status.lowercaseString ?: @"";
    if ([lower containsString:@"playable"]) {
        return [UIColor colorWithRed:0.24 green:0.76 blue:0.34 alpha:0.92];
    }
    if ([lower containsString:@"in game"]) {
        return [UIColor colorWithRed:0.24 green:0.57 blue:0.95 alpha:0.92];
    }
    if ([lower containsString:@"menus"]) {
        return [UIColor colorWithRed:0.88 green:0.62 blue:0.10 alpha:0.92];
    }
    if ([lower containsString:@"boots"]) {
        return [UIColor colorWithRed:0.90 green:0.42 blue:0.14 alpha:0.92];
    }
    if ([lower containsString:@"nothing"] || [lower containsString:@"unavailable"]) {
        return [UIColor colorWithRed:0.82 green:0.16 blue:0.18 alpha:0.92];
    }
    return [UIColor colorWithWhite:1.0 alpha:0.22];
}

- (UIButton*)addGameButton {
    UIButton* button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.10];
    button.tintColor = UIColor.whiteColor;
    button.layer.cornerRadius = 5.0;
    button.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.30].CGColor;
    button.layer.borderWidth = 1.0;
    [button setImage:[UIImage systemImageNamed:@"plus"] forState:UIControlStateNormal];
    button.accessibilityLabel = @"Add Game";
    [button.widthAnchor constraintEqualToConstant:184.0].active = YES;
    [button.heightAnchor constraintEqualToConstant:198.0].active = YES;
    [button addTarget:self action:@selector(addGamePressed) forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)gamePressed:(UIButton*)button {
    self.selectedGameIndex = button.tag;
    [self playMoveSound];
    [self updateSelectedGameAnimated:YES];
    [self scrollSelectedTileIntoView];
}

- (void)updateSelectedGameAnimated:(BOOL)animated {
    if (self.games.count == 0) {
        self.selectedGameIndex = 0;
        self.selectedTitleLabel.text = @"Library";
        self.selectedDetailLabel.text = @"Press + to add a game";
        self.selectedCompatibilityLabel.text = @"Compatibility: none";
        self.selectedCompatibilityLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.58];
        self.selectedCompatibilityDot.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.22];
        self.selectedPathLabel.text = @"Path: none";
        self.selectedTypeLabel.text = @"Type: waiting for import";
        self.selectedLastPlayedLabel.text = @"Last played: never";
    }

    const BOOL selectingAdd = self.selectedGameIndex >= (NSInteger)self.games.count;
    if (self.games.count > 0 && !selectingAdd) {
        self.selectedGameIndex = MIN(MAX(self.selectedGameIndex, 0), (NSInteger)self.games.count - 1);
        NSDictionary* game = self.games[(NSUInteger)self.selectedGameIndex];
        self.selectedTitleLabel.text = game[@"title"];
        NSString* version = [self gameVersionForGame:game];
        self.selectedDetailLabel.text =
            [NSString stringWithFormat:@"Version %@      Trophies   Progress 57%%      Platinum 0   Gold 1   Silver 9   Bronze 40",
                                       version];
        self.selectedCompatibilityLabel.text = [self compatibilityLineForGame:game];
        self.selectedCompatibilityLabel.textColor = [self compatibilityTextColorForStatus:game[@"compatibilityStatus"]];
        self.selectedCompatibilityDot.backgroundColor = [self compatibilityTintForStatus:game[@"compatibilityStatus"]];
        NSString* path = game[@"path"] ?: @"";
        self.selectedPathLabel.text = [NSString stringWithFormat:@"Path: %@", path.length > 0 ? path : @"unknown"];
        self.selectedTypeLabel.text = [self metadataTypeForPath:path];
        self.selectedLastPlayedLabel.text = game[@"lastPlayed"] ?: @"Last played: never";
    } else if (selectingAdd) {
        self.selectedTitleLabel.text = @"Add Game";
        self.selectedDetailLabel.text = @"Import a game folder or file into the app sandbox";
        self.selectedCompatibilityLabel.text = @"Compatibility: read from shadPS4 after import";
        self.selectedCompatibilityLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.58];
        self.selectedCompatibilityDot.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.22];
        self.selectedPathLabel.text = @"Path: Documents/Games";
        self.selectedTypeLabel.text = @"Type: folder or file";
        self.selectedLastPlayedLabel.text = @"Last played: never";
    }

    const BOOL hasGames = self.games.count > 0;
    self.emptyStateView.hidden = hasGames;
    self.gameDetailPanel.hidden = !hasGames;
    self.deleteGameButton.hidden = YES;
    self.startGameButton.hidden = !hasGames || selectingAdd;
    self.editGameButton.hidden = !hasGames || selectingAdd;

    [self.gameButtons enumerateObjectsUsingBlock:^(UIButton* button, NSUInteger idx, BOOL* stop) {
        const BOOL selected = !self.topMenuFocused && !selectingAdd && idx == (NSUInteger)self.selectedGameIndex;
        void (^changes)(void) = ^{
            UILabel* startStrip = (UILabel*)[button viewWithTag:9002];
            UIImageView* image = (UIImageView*)[button viewWithTag:9001];
            startStrip.hidden = YES;
            button.transform = selected ? CGAffineTransformMakeScale(1.06, 1.06) : CGAffineTransformIdentity;
            image.transform = CGAffineTransformIdentity;
            button.layer.borderColor =
                (selected ? [UIColor colorWithWhite:1.0 alpha:0.00]
                          : [UIColor colorWithWhite:1.0 alpha:0.26])
                    .CGColor;
            button.layer.borderWidth = selected ? 0.0 : 1.0;
            image.layer.borderColor =
                (selected ? [UIColor colorWithWhite:1.0 alpha:0.98]
                          : [UIColor colorWithWhite:1.0 alpha:0.18])
                    .CGColor;
            image.layer.borderWidth = selected ? 2.6 : 1.0;
            button.layer.shadowOpacity = selected ? 0.35 : 0.0;
            button.layer.shadowRadius = selected ? 12.0 : 0.0;
            button.layer.shadowColor = UIColor.whiteColor.CGColor;
        };
        [self animateDashboardChanges:animated baseTime:0.22 damping:0.78 changes:changes completion:nil];
    }];

    [self updateAddTileFocusAnimated:animated];
    [self updateTopMenuFocusAnimated:animated];

    if (animated && !self.gameDetailPanel.hidden) {
        self.gameDetailPanel.contentView.alpha = 0.86;
        self.gameDetailPanel.contentView.transform = CGAffineTransformMakeTranslation(12.0, 0.0);
        [self animateDashboardChanges:YES
                              baseTime:0.24
                               damping:0.86
                               changes:^{
                                   self.gameDetailPanel.contentView.alpha = 1.0;
                                   self.gameDetailPanel.contentView.transform = CGAffineTransformIdentity;
                               }
                            completion:nil];
    }
}

- (void)startGameButtonPressed {
    [self playAcceptSound];
    [self startSelectedGame];
}

- (void)editSelectedGamePressed {
    if (self.selectedGameIndex < 0 || self.selectedGameIndex >= (NSInteger)self.games.count) {
        return;
    }

    NSMutableDictionary* game = self.games[(NSUInteger)self.selectedGameIndex];
    UIAlertController* alert =
        [UIAlertController alertControllerWithTitle:@"Edit Game"
                                            message:game[@"title"]
                                     preferredStyle:UIAlertControllerStyleActionSheet];
    [alert addAction:[UIAlertAction actionWithTitle:@"Update Game..."
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction* action) {
                                                [self presentGamePackagePickerWithMode:@"Update"];
                                            }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Add DLC..."
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction* action) {
                                                [self presentGamePackagePickerWithMode:@"DLC"];
                                            }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Game Settings"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction* action) {
                                                [self showPerGameSettingsForGame:game];
                                            }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Delete Game"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction* action) {
                                                [self deleteSelectedGamePressed];
                                            }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    alert.popoverPresentationController.sourceView = self.editGameButton;
    alert.popoverPresentationController.sourceRect = self.editGameButton.bounds;
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)presentGamePackagePickerWithMode:(NSString*)mode {
    self.pendingGameImportMode = mode;
    NSArray<UTType*>* types = @[ UTTypeItem, UTTypeData, UTTypeContent, UTTypeFolder ];
    UIDocumentPickerViewController* picker =
        [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:types asCopy:NO];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    picker.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)showPerGameSettingsForGame:(NSDictionary*)game {
    NSString* message = [NSString stringWithFormat:@"Version: %@\nCompatibility: %@\n\nPer-game CPU/GPU/input overrides will be wired here.",
                                                   [self gameVersionForGame:game],
                                                   game[@"compatibilityStatus"] ?: @"Unknown"];
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Game Settings"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)deleteSelectedGamePressed {
    if (self.selectedGameIndex < 0 || self.selectedGameIndex >= (NSInteger)self.games.count) {
        return;
    }

    NSMutableDictionary* game = self.games[(NSUInteger)self.selectedGameIndex];
    UIAlertController* alert =
        [UIAlertController alertControllerWithTitle:@"Delete Game"
                                            message:game[@"title"]
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Delete"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction* action) {
                                                NSString* path = game[@"path"];
                                                if (path.length > 0) {
                                                    [NSFileManager.defaultManager removeItemAtPath:path error:nil];
                                                }
                                                [self.games removeObjectAtIndex:(NSUInteger)self.selectedGameIndex];
                                                self.selectedGameIndex = MIN(self.selectedGameIndex, (NSInteger)self.games.count);
                                                [self saveGameLibrary];
                                                [self refreshGameRow];
                                                [self playMoveSound];
                                            }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (NSString*)metadataTypeForPath:(NSString*)path {
    if (path.length == 0) {
        return @"Type: unknown";
    }
    BOOL isDirectory = NO;
    BOOL exists = [NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&isDirectory];
    if (!exists) {
        return @"Type: missing file";
    }
    return isDirectory ? @"Type: imported game folder" : @"Type: imported game file";
}

- (void)startSelectedGame {
    if (self.selectedGameIndex < 0 || self.selectedGameIndex >= (NSInteger)self.games.count) {
        [self addGamePressed];
        return;
    }

    NSMutableDictionary* game = self.games[(NSUInteger)self.selectedGameIndex];
    self.statusLabel.text = [NSString stringWithFormat:@"Starting %@...", game[@"title"]];
    [[ShadIOSCoreBridge sharedBridge] applyUserDefaultsToCore];
    NSError* startError = nil;
    if (![[ShadIOSCoreBridge sharedBridge] startGameAtPath:game[@"path"] error:&startError]) {
        NSString* message = startError.localizedDescription ?: @"Unable to start emulator core.";
        self.statusLabel.text = message;
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Core Start Blocked"
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        NSLog(@"shadPS4 iOS: failed to start core for %@: %@", game[@"path"], message);
        return;
    }
    game[@"lastPlayed"] = [NSString stringWithFormat:@"Last played: %@", [self shortDateString]];
    [self saveGameLibrary];
    [self updateSelectedGameAnimated:NO];
    [self playAcceptSound];

    self.dashboardView.userInteractionEnabled = NO;
    self.touchOverlay.hidden = NO;
    self.overlayMenuView.hidden = YES;
    self.runtimeMenuButton.hidden = NO;
    self.runtimeMenuButton.alpha = 0.0;
    self.virtualLayoutEditing = NO;
    self.virtualLayoutEditPanel.hidden = YES;
    self.virtualLayoutEditPanel.alpha = 0.0;
    self.virtualLayoutEditSnapshot = nil;
    self.selectedVirtualControlKey = nil;
    [self.pressedVirtualControls removeAllObjects];
    [[ShadIOSCoreBridge sharedBridge] releaseAllInputs];
    ShadVirtualPadState emptyPadState = {};
    self.virtualPadState = emptyPadState;
    [self.virtualControlButtons enumerateKeysAndObjectsUsingBlock:^(NSString* key, UIButton* button, BOOL* stop) {
        [self updateVirtualControlAppearance:button pressed:NO];
    }];
    self.framesSinceStatsUpdate = 0;
    self.lastStatsUpdateTime = 0;
    self.previousStatsFrameTime = 0;
    self.lastPresenterPresentCount = ShadIOSGetPresenterPresentCount();
    [self.runtimeStatsTimer invalidate];
    self.runtimeStatsTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                              target:self
                                                            selector:@selector(runtimeStatsTimerFired:)
                                                            userInfo:nil
                                                             repeats:YES];
    [NSRunLoop.mainRunLoop addTimer:self.runtimeStatsTimer forMode:NSRunLoopCommonModes];
    self.metalView.paused = YES;
    self.metalView.enableSetNeedsDisplay = NO;
    NSLog(@"shadPS4 iOS: MTKView draw loop paused; MoltenVK owns CAMetalLayer presentation.");
    id overlayStartupStored = [[NSUserDefaults standardUserDefaults] objectForKey:ShadSettingTouchOverlayStartupKey];
    NSInteger overlayStartup = overlayStartupStored == nil ? 1 : [[NSUserDefaults standardUserDefaults] integerForKey:ShadSettingTouchOverlayStartupKey];
    self.touchControlsVisible = overlayStartup != 0;
    float overlayOpacity = [[NSUserDefaults standardUserDefaults] objectForKey:ShadSettingTouchOverlayOpacityKey] == nil
                               ? 0.42f
                               : [[NSUserDefaults standardUserDefaults] floatForKey:ShadSettingTouchOverlayOpacityKey];
    overlayOpacity = MIN(MAX(overlayOpacity, 0.18f), 0.70f);
    self.touchOverlay.alpha = 0.0;
    self.touchOverlay.transform = CGAffineTransformMakeScale(1.02, 1.02);
    [self animateDashboardChanges:YES
                          baseTime:0.34
                           damping:0.88
                           changes:^{
                               self.dashboardView.alpha = 0.0;
                               self.dashboardView.transform = CGAffineTransformMakeScale(1.018, 1.018);
                               self.touchOverlay.alpha = self.touchControlsVisible ? overlayOpacity : 0.0;
                               self.touchOverlay.transform = CGAffineTransformIdentity;
                               self.runtimeMenuButton.alpha = 1.0;
                           }
                        completion:^(BOOL finished) {
                            self.dashboardView.hidden = YES;
                            self.dashboardView.alpha = 1.0;
                            self.dashboardView.transform = CGAffineTransformIdentity;
                            self.dashboardView.userInteractionEnabled = YES;
                            [self updateExternalDisplayModeForGameState];
                            [self updatePerformanceOverlayStyle];
                            [self updatePerformanceOverlayVisibility];
                            [self updatePerformanceOverlayText];
                        }];
    NSLog(@"shadPS4 iOS: selected game '%@' at path '%@'", game[@"title"], game[@"path"]);
}

- (void)addGamePressed {
    if (self.importingGame) {
        self.statusLabel.text = @"Import already in progress";
        [self playBackSound];
        return;
    }
    [self playMoveSound];
    self.pendingGameImportMode = nil;
    NSArray<UTType*>* types = @[ UTTypeFolder, UTTypeItem, UTTypeData, UTTypeContent ];
    UIDocumentPickerViewController* picker =
        [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:types asCopy:NO];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    picker.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController*)controller didPickDocumentsAtURLs:(NSArray<NSURL*>*)urls {
    NSURL* url = urls.firstObject;
    if (url == nil) {
        return;
    }

    if (self.pendingGameImportMode.length > 0) {
        [self importPackageURL:url mode:self.pendingGameImportMode];
        self.pendingGameImportMode = nil;
        return;
    }

    NSInteger existingIndex = [self existingGameIndexForURL:url];
    if (existingIndex != NSNotFound) {
        self.selectedGameIndex = existingIndex;
        [self scrollSelectedTileIntoView];
        [self updateSelectedGameAnimated:YES];
        self.statusLabel.text = @"Game already exists";
        [self playMoveSound];
        return;
    }

    [self showImportProgressWithText:@"Importing game..." progress:0.12f];
    NSURL* sourceURL = [url copy];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        const BOOL scoped = [sourceURL startAccessingSecurityScopedResource];
        NSError* error = nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showImportProgressWithText:@"Copying into app sandbox..." progress:0.36f];
        });
        NSURL* importedURL = [self importGameURL:sourceURL error:&error];
        if (scoped) {
            [sourceURL stopAccessingSecurityScopedResource];
        }

        if (importedURL == nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self hideImportProgressWithStatus:@"Import failed" success:NO];
                [self playBackSound];
            });
            NSLog(@"shadPS4 iOS: failed to import game %@ error=%@", sourceURL, error);
            [sourceURL release];
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self showImportProgressWithText:@"Reading game metadata..." progress:0.72f];
        });
        NSDictionary* psf = [self psfMetadataForGamePath:importedURL.path];
        NSString* title = psf[@"title"] ?: importedURL.lastPathComponent.stringByDeletingPathExtension;
        NSString* serial = psf[@"serial"] ?: @"";
        NSMutableDictionary* game = [@{
            @"title" : title.length > 0 ? title : @"Imported Game",
            @"detail" : @"Imported to app sandbox",
            @"path" : importedURL.path ?: @"",
            @"serial" : serial,
            @"version" : psf[@"version"] ?: @"1.00",
            @"sourceName" : sourceURL.lastPathComponent ?: @"",
            @"compatibilityStatus" : serial.length > 0 ? @"Checking compatibility..." : @"Compatibility unknown",
            @"compatibilitySummary" : serial.length > 0 ? @"Reading shadPS4 compatibility report" : @"No TITLE_ID found in param.sfo",
            @"lastPlayed" : @"Last played: never",
        } mutableCopy];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.games addObject:game];
            [game release];
            self.selectedGameIndex = (NSInteger)self.games.count - 1;
            [self saveGameLibrary];
            [self refreshGameRow];
            NSString* status = serial.length > 0 ? [NSString stringWithFormat:@"Game added: %@", serial] : @"Game added";
            [self hideImportProgressWithStatus:status success:YES];
            [self playAcceptSound];
            if (serial.length > 0) {
                [self fetchCompatibilityForGameAtIndex:self.selectedGameIndex];
            }
            [sourceURL release];
        });
    });
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController*)controller {
    self.pendingGameImportMode = nil;
}

- (void)importPackageURL:(NSURL*)sourceURL mode:(NSString*)mode {
    if (self.selectedGameIndex < 0 || self.selectedGameIndex >= (NSInteger)self.games.count) {
        return;
    }

    NSMutableDictionary* game = self.games[(NSUInteger)self.selectedGameIndex];
    const BOOL scoped = [sourceURL startAccessingSecurityScopedResource];
    NSError* error = nil;
    NSFileManager* fm = NSFileManager.defaultManager;
    NSString* gamePath = game[@"path"];
    NSString* folderName = [mode isEqualToString:@"DLC"] ? @"DLC" : @"Updates";
    NSURL* gameURL = [NSURL fileURLWithPath:gamePath.length > 0 ? gamePath : NSTemporaryDirectory()];
    NSURL* packageDir = [[gameURL URLByDeletingLastPathComponent] URLByAppendingPathComponent:folderName isDirectory:YES];
    [fm createDirectoryAtURL:packageDir withIntermediateDirectories:YES attributes:nil error:&error];
    NSURL* destination = [packageDir URLByAppendingPathComponent:sourceURL.lastPathComponent ?: mode];
    if ([fm fileExistsAtPath:destination.path]) {
        [fm removeItemAtURL:destination error:nil];
    }
    BOOL copied = [fm copyItemAtURL:sourceURL toURL:destination error:&error];
    if (scoped) {
        [sourceURL stopAccessingSecurityScopedResource];
    }

    if (!copied) {
        self.statusLabel.text = [NSString stringWithFormat:@"%@ import failed", mode];
        NSLog(@"shadPS4 iOS: %@ import failed: %@", mode, error);
        return;
    }

    if ([mode isEqualToString:@"DLC"]) {
        game[@"dlcPath"] = destination.path ?: @"";
        self.statusLabel.text = @"DLC added";
    } else {
        game[@"updatePath"] = destination.path ?: @"";
        game[@"version"] = @"Updated";
        self.statusLabel.text = @"Game update added";
    }
    [self saveGameLibrary];
    [self updateSelectedGameAnimated:YES];
    [self playAcceptSound];
}

- (NSString*)shortDateString {
    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm";
    return [formatter stringFromDate:NSDate.date];
}

- (NSURL*)importGameURL:(NSURL*)sourceURL error:(NSError**)error {
    NSFileManager* fm = NSFileManager.defaultManager;
    NSURL* gamesDir = [self gamesDirectoryCreatingIfNeeded:YES error:error];
    if (gamesDir == nil) {
        return nil;
    }

    NSURL* destination = [gamesDir URLByAppendingPathComponent:sourceURL.lastPathComponent];
    if ([fm fileExistsAtPath:destination.path]) {
        return destination;
    }

    if (![fm copyItemAtURL:sourceURL toURL:destination error:error]) {
        return nil;
    }
    return destination;
}

- (NSURL*)gamesDirectoryCreatingIfNeeded:(BOOL)create error:(NSError**)error {
    NSFileManager* fm = NSFileManager.defaultManager;
    NSURL* docs = [fm URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    NSURL* gamesDir = [docs URLByAppendingPathComponent:@"Games" isDirectory:YES];
    if (create) {
        if (![fm createDirectoryAtURL:gamesDir withIntermediateDirectories:YES attributes:nil error:error]) {
            return nil;
        }
    }
    return gamesDir;
}

- (void)settingsPressed {
    if (self.presentedViewController != nil) {
        return;
    }
    self.topMenuFocused = YES;
    self.topMenuIndex = 1;
    [self updateTopMenuFocusAnimated:YES];
    [self playMoveSound];
    ShadSettingsViewController* settings = [[ShadSettingsViewController alloc] init];
    settings.modalPresentationStyle = UIModalPresentationOverFullScreen;
    [self presentViewController:settings animated:NO completion:nil];
}

- (void)trophiesPressed {
    if (self.presentedViewController != nil) {
        return;
    }
    self.topMenuFocused = YES;
    self.topMenuIndex = 0;
    [self updateTopMenuFocusAnimated:YES];
    NSDictionary* selectedGame = nil;
    if (self.selectedGameIndex >= 0 && self.selectedGameIndex < (NSInteger)self.games.count) {
        selectedGame = self.games[(NSUInteger)self.selectedGameIndex];
    }
    ShadTrophiesViewController* trophies = [[ShadTrophiesViewController alloc] initWithGame:selectedGame];
    trophies.modalPresentationStyle = UIModalPresentationOverFullScreen;
    trophies.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [self playAcceptSound];
    [self presentViewController:trophies animated:YES completion:nil];
}

- (void)powerPressed {
    const BOOL returningFromGame = self.dashboardView.hidden;
    self.topMenuFocused = NO;
    self.topMenuIndex = MIN(self.topMenuIndex, (NSInteger)self.topMenuButtons.count - 1);
    [self updateTopMenuFocusAnimated:YES];
    if (returningFromGame) {
        self.dashboardView.alpha = 0.0;
        self.dashboardView.transform = CGAffineTransformMakeScale(1.018, 1.018);
    }
    self.dashboardView.hidden = NO;
    [self.runtimeStatsTimer invalidate];
    self.runtimeStatsTimer = nil;
    self.metalView.paused = NO;
    self.metalView.enableSetNeedsDisplay = NO;
    self.overlayMenuView.hidden = YES;
    self.performanceOverlayView.hidden = YES;
    self.virtualLayoutEditing = NO;
    self.virtualLayoutEditPanel.hidden = YES;
    self.virtualLayoutEditPanel.alpha = 0.0;
    self.virtualLayoutEditSnapshot = nil;
    self.selectedVirtualControlKey = nil;
    [self.pressedVirtualControls removeAllObjects];
    ShadVirtualPadState emptyPadState = {};
    self.virtualPadState = emptyPadState;
    [self.virtualControlButtons enumerateKeysAndObjectsUsingBlock:^(NSString* key, UIButton* button, BOOL* stop) {
        [self updateVirtualControlAppearance:button pressed:NO];
    }];
    self.statusLabel.text = @"Returned to dashboard";
    [self playMoveSound];
    [self animateDashboardChanges:returningFromGame
                          baseTime:0.30
                           damping:0.88
                           changes:^{
                               self.dashboardView.alpha = 1.0;
                               self.dashboardView.transform = CGAffineTransformIdentity;
                               self.touchOverlay.alpha = 0.0;
                               self.runtimeMenuButton.alpha = 0.0;
                           }
                        completion:^(BOOL finished) {
                            self.touchOverlay.hidden = YES;
                            self.runtimeMenuButton.hidden = YES;
                            self.runtimeMenuButton.alpha = 1.0;
                            [self updateExternalDisplayModeForGameState];
                        }];
}

- (void)returnToDashboardFromOverlay {
    [self powerPressed];
}

- (void)quitGamePressed {
    [self powerPressed];
}

- (void)runtimeSettingsPressed {
    [self hideRuntimeOverlayMenu];
    [self settingsPressed];
}

- (void)editVirtualControllerLayout {
    if (self.virtualLayoutEditing) {
        [self hideRuntimeOverlayMenu];
        return;
    }
    self.virtualLayoutEditing = YES;
    self.virtualLayoutEditSnapshot = [self currentVirtualControllerLayoutDictionary];
    self.selectedVirtualControlKey = nil;
    self.statusLabel.text = @"Editing controller layout";
    self.virtualLayoutEditHintLabel.text = @"Tap a control, then drag, pinch, or use Bigger/Smaller.";
    self.touchControlsVisible = YES;
    self.touchOverlay.hidden = NO;
    self.touchOverlay.alpha = 0.70;
    [self hideRuntimeOverlayMenu];
    [self playAcceptSound];
    [self.virtualControlButtons enumerateKeysAndObjectsUsingBlock:^(NSString* key, UIButton* button, BOOL* stop) {
        [self styleVirtualControlButton:button
                                pressed:[self.pressedVirtualControls containsObject:key]
                                editing:YES];
    }];
    [self showVirtualLayoutEditPanel];
    NSLog(@"shadPS4 iOS: virtual controller layout edit mode enabled");
}

- (void)showVirtualLayoutEditPanel {
    self.virtualLayoutEditPanel.hidden = NO;
    self.virtualLayoutEditPanel.alpha = 0.0;
    self.virtualLayoutEditPanel.transform = CGAffineTransformMakeTranslation(0.0, -18.0);
    [UIView animateWithDuration:0.22
                          delay:0.0
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.10
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
                         self.virtualLayoutEditPanel.alpha = 1.0;
                         self.virtualLayoutEditPanel.transform = CGAffineTransformIdentity;
                     }
                     completion:nil];
}

- (void)finishVirtualLayoutEditSaving:(BOOL)save {
    if (!self.virtualLayoutEditing) {
        return;
    }
    if (save) {
        [self saveVirtualControllerLayout];
        self.statusLabel.text = @"Controller layout saved";
        self.virtualLayoutEditHintLabel.text = @"Saved";
        [self playAcceptSound];
    } else if (self.virtualLayoutEditSnapshot != nil) {
        [self applyVirtualControllerLayoutDictionary:self.virtualLayoutEditSnapshot];
        self.statusLabel.text = @"Controller layout unchanged";
        [self playBackSound];
    }

    self.virtualLayoutEditing = NO;
    self.virtualLayoutEditSnapshot = nil;
    self.selectedVirtualControlKey = nil;
    [self.virtualControlButtons enumerateKeysAndObjectsUsingBlock:^(NSString* key, UIButton* button, BOOL* stop) {
        [self styleVirtualControlButton:button
                                pressed:[self.pressedVirtualControls containsObject:key]
                                editing:NO];
    }];
    [UIView animateWithDuration:0.18
                     animations:^{
                         self.virtualLayoutEditPanel.alpha = 0.0;
                         self.virtualLayoutEditPanel.transform = CGAffineTransformMakeTranslation(0.0, -14.0);
                     }
                     completion:^(BOOL finished) {
                         self.virtualLayoutEditPanel.hidden = YES;
                         self.virtualLayoutEditPanel.transform = CGAffineTransformIdentity;
                     }];
}

- (void)saveVirtualLayoutEditPressed {
    [self finishVirtualLayoutEditSaving:YES];
}

- (void)cancelVirtualLayoutEditPressed {
    [self finishVirtualLayoutEditSaving:NO];
}

- (void)resetVirtualLayoutEditPressed {
    if (!self.virtualLayoutEditing) {
        return;
    }
    [self applyDefaultVirtualControllerLayoutAnimated:YES];
    self.selectedVirtualControlKey = nil;
    self.virtualLayoutEditHintLabel.text = @"Default layout preview. Tap Save Layout to keep it.";
    self.statusLabel.text = @"Controller layout reset preview";
    [self playMoveSound];
}

- (void)makeSelectedVirtualControlBigger {
    UIButton* button = self.virtualControlButtons[self.selectedVirtualControlKey];
    if (button == nil) {
        self.virtualLayoutEditHintLabel.text = @"Tap a control first, then choose Bigger.";
        [self playBackSound];
        return;
    }
    [self resizeVirtualControl:button byScale:1.12 animated:YES];
    self.virtualLayoutEditHintLabel.text = @"Size changed. Tap Save Layout to keep it.";
    [self playMoveSound];
}

- (void)makeSelectedVirtualControlSmaller {
    UIButton* button = self.virtualControlButtons[self.selectedVirtualControlKey];
    if (button == nil) {
        self.virtualLayoutEditHintLabel.text = @"Tap a control first, then choose Smaller.";
        [self playBackSound];
        return;
    }
    [self resizeVirtualControl:button byScale:0.88 animated:YES];
    self.virtualLayoutEditHintLabel.text = @"Size changed. Tap Save Layout to keep it.";
    [self playMoveSound];
}

- (void)saveStatePressed {
    [self hideRuntimeOverlayMenu];
    [self playAcceptSound];
    NSLog(@"shadPS4 iOS: save state requested. Hook core save-state API here.");
}

- (void)runtimeMenuButtonPressed {
    if (!self.dashboardView.hidden) {
        return;
    }
    if (self.overlayMenuView.hidden) {
        [self showRuntimeOverlayMenu];
    } else {
        [self hideRuntimeOverlayMenu];
    }
}

- (void)showRuntimeOverlayMenu {
    if (!self.dashboardView.hidden) {
        return;
    }
    self.overlayMenuView.hidden = NO;
    self.overlayMenuView.alpha = 0.0;
    self.overlayMenuView.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(-34.0, 0.0),
                                                             CGAffineTransformMakeScale(0.97, 0.97));
    [self animateDashboardChanges:YES
                          baseTime:0.26
                           damping:0.86
                           changes:^{
                               self.overlayMenuView.alpha = 1.0;
                               self.overlayMenuView.transform = CGAffineTransformIdentity;
                           }
                        completion:nil];
    [self playMoveSound];
}

- (void)hideRuntimeOverlayMenu {
    if (self.overlayMenuView.hidden) {
        return;
    }
    [self animateDashboardChanges:YES
                          baseTime:0.18
                           damping:0.90
                           changes:^{
                               self.overlayMenuView.alpha = 0.0;
                               self.overlayMenuView.transform =
                                   CGAffineTransformConcat(CGAffineTransformMakeTranslation(-28.0, 0.0),
                                                           CGAffineTransformMakeScale(0.98, 0.98));
                           }
                        completion:^(BOOL finished) {
                            self.overlayMenuView.hidden = YES;
                            self.overlayMenuView.alpha = 1.0;
                            self.overlayMenuView.transform = CGAffineTransformIdentity;
                        }];
}

- (void)toggleTouchControls {
    self.touchControlsVisible = !self.touchControlsVisible;
    float opacity = [[NSUserDefaults standardUserDefaults] objectForKey:ShadSettingTouchOverlayOpacityKey] == nil
                        ? 0.42f
                        : [[NSUserDefaults standardUserDefaults] floatForKey:ShadSettingTouchOverlayOpacityKey];
    [self animateDashboardChanges:YES
                          baseTime:0.20
                           damping:0.84
                           changes:^{
                               self.touchOverlay.alpha = self.touchControlsVisible ? MIN(MAX(opacity, 0.18f), 0.70f) : 0.0;
                               self.touchOverlay.transform =
                                   self.touchControlsVisible ? CGAffineTransformIdentity : CGAffineTransformMakeScale(1.018, 1.018);
                           }
                        completion:nil];
    [self playMoveSound];
}

- (BOOL)runtimeSettingEnabled:(NSString*)key defaultValue:(BOOL)defaultValue {
    id stored = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    return stored == nil ? defaultValue : [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

- (float)runtimeSettingFloat:(NSString*)key defaultValue:(float)defaultValue {
    id stored = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    return stored == nil ? defaultValue : [[NSUserDefaults standardUserDefaults] floatForKey:key];
}

- (NSInteger)runtimeSettingInteger:(NSString*)key defaultValue:(NSInteger)defaultValue {
    id stored = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    return stored == nil ? defaultValue : [[NSUserDefaults standardUserDefaults] integerForKey:key];
}

- (void)updatePerformanceOverlayStyle {
    float opacity = [self runtimeSettingFloat:ShadSettingRuntimeStatsOpacityKey defaultValue:0.82f];
    self.performanceOverlayView.alpha = MIN(MAX(opacity, 0.35f), 1.0f);

    NSInteger position = [self runtimeSettingInteger:ShadSettingRuntimeStatsPositionKey defaultValue:0];
    position = MIN(MAX(position, 0), 2);
    self.performanceOverlayLeadingConstraint.active = position == 0;
    self.performanceOverlayCenterConstraint.active = position == 1;
    self.performanceOverlayTrailingConstraint.active = position == 2;
    self.performanceOverlayTopConstraint.constant = position == 0 ? 66.0 : 16.0;
    [self.view setNeedsLayout];
}

- (void)updatePerformanceOverlayVisibility {
    const BOOL inGame = self.dashboardView.hidden;
    const BOOL enabled = [self runtimeSettingEnabled:ShadSettingRuntimeStatsOverlayKey defaultValue:YES];
    self.runtimeMenuButton.hidden = !inGame;
    self.performanceOverlayView.hidden = !(inGame && enabled);
}

- (void)updatePerformanceOverlayText {
    if (self.performanceOverlayView.hidden) {
        return;
    }

    NSMutableArray<NSString*>* lines = [NSMutableArray array];
    if ([self runtimeSettingEnabled:ShadSettingRuntimeStatsFPSKey defaultValue:YES]) {
        [lines addObject:[NSString stringWithFormat:@"FPS  %.0f", self.currentFPS]];
    }
    if ([self runtimeSettingEnabled:ShadSettingRuntimeStatsCPUKey defaultValue:YES]) {
        [lines addObject:[NSString stringWithFormat:@"CPU  %.0f%%", self.currentCPUPercent]];
    }
    if ([self runtimeSettingEnabled:ShadSettingRuntimeStatsGPUKey defaultValue:YES]) {
        [lines addObject:[NSString stringWithFormat:@"GPU  %.0f%%", self.currentGPULoadPercent]];
    }
    if ([self runtimeSettingEnabled:ShadSettingRuntimeStatsRAMKey defaultValue:YES]) {
        [lines addObject:[NSString stringWithFormat:@"RAM  %.0f MB", self.currentRAMMB]];
    }
    const uint64_t gameFrames = ShadIOSGetPresenterGameFrameCount();
    const uint64_t blankFrames = ShadIOSGetPresenterBlankFrameCount();
    const uint64_t presents = ShadIOSGetPresenterPresentCount();
    [lines addObject:[NSString stringWithFormat:@"Render G%llu B%llu P%llu",
                                                (unsigned long long)gameFrames,
                                                (unsigned long long)blankFrames,
                                                (unsigned long long)presents]];
    const char* coreStageText = ShadIOSGetCoreStageDescription();
    [lines addObject:[NSString stringWithFormat:@"Core %d %s",
                                                ShadIOSGetCoreStage(),
                                                coreStageText != nullptr ? coreStageText : ""]];
    self.performanceOverlayLabel.text = lines.count > 0 ? [lines componentsJoinedByString:@"\n"] : @"Stats disabled";
}

- (void)tickRuntimeStatsOverlay {
    if (!self.dashboardView.hidden) {
        return;
    }

    const CFTimeInterval now = CACurrentMediaTime();
    const CFTimeInterval minDelta = 1.0 / MAX(1, self.frameLimit);
    const CFTimeInterval frameDelta = self.lastDrawTime > 0 ? now - self.lastDrawTime : minDelta;
    self.lastDrawTime = now;
    self.framesSinceStatsUpdate++;

    if (now - self.lastThermalCheckTime >= 1.0) {
        self.lastThermalCheckTime = now;
        NSProcessInfoThermalState thermalState = NSProcessInfo.processInfo.thermalState;
        if (thermalState != self.lastThermalState || thermalState >= NSProcessInfoThermalStateSerious) {
            self.lastThermalState = thermalState;
            [[ShadIOSCoreBridge sharedBridge] applyThermalState:thermalState];
            self.frameLimit = [ShadIOSCoreBridge sharedBridge].activeFrameLimit;
        }
    }

    if (self.lastStatsUpdateTime <= 0) {
        self.lastStatsUpdateTime = now;
        return;
    }

    if (now - self.lastStatsUpdateTime >= 0.50) {
        const uint64_t presentCount = ShadIOSGetPresenterPresentCount();
        const uint64_t presentDelta = presentCount >= self.lastPresenterPresentCount
                                          ? presentCount - self.lastPresenterPresentCount
                                          : 0;
        self.currentFPS = (double)presentDelta / (now - self.lastStatsUpdateTime);
        self.lastPresenterPresentCount = presentCount;
        self.currentCPUPercent = [self currentProcessCPUPercent];
        self.currentRAMMB = [self currentProcessRAMMB];
        self.currentGPULoadPercent = MIN(MAX((frameDelta / minDelta) * 100.0, 0.0), 100.0);
        self.framesSinceStatsUpdate = 0;
        self.lastStatsUpdateTime = now;
        [self updatePerformanceOverlayVisibility];
        [self updatePerformanceOverlayText];
    }
}

- (void)runtimeStatsTimerFired:(NSTimer*)timer {
    [self tickRuntimeStatsOverlay];
}

- (double)currentProcessCPUPercent {
    thread_array_t threads = nullptr;
    mach_msg_type_number_t threadCount = 0;
    kern_return_t kr = task_threads(mach_task_self(), &threads, &threadCount);
    if (kr != KERN_SUCCESS) {
        return 0.0;
    }

    double total = 0.0;
    for (mach_msg_type_number_t i = 0; i < threadCount; i++) {
        thread_info_data_t threadInfo;
        mach_msg_type_number_t infoCount = THREAD_INFO_MAX;
        kr = thread_info(threads[i], THREAD_BASIC_INFO, (thread_info_t)threadInfo, &infoCount);
        if (kr != KERN_SUCCESS) {
            continue;
        }
        thread_basic_info_t basicInfo = (thread_basic_info_t)threadInfo;
        if ((basicInfo->flags & TH_FLAGS_IDLE) == 0) {
            total += (double)basicInfo->cpu_usage / (double)TH_USAGE_SCALE * 100.0;
        }
    }

    if (threads != nullptr) {
        vm_deallocate(mach_task_self(), (vm_address_t)threads, (vm_size_t)threadCount * sizeof(thread_t));
    }
    return MIN(MAX(total, 0.0), 999.0);
}

- (double)currentProcessRAMMB {
    task_vm_info_data_t vmInfo;
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    kern_return_t kr = task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&vmInfo, &count);
    if (kr != KERN_SUCCESS) {
        return 0.0;
    }
    return (double)vmInfo.phys_footprint / (1024.0 * 1024.0);
}

- (void)updateAddTileFocusAnimated:(BOOL)animated {
    const BOOL selected = !self.topMenuFocused && self.selectedGameIndex >= (NSInteger)self.games.count;
    void (^changes)(void) = ^{
        self.addGameTile.transform = selected ? CGAffineTransformMakeScale(1.14, 1.14) : CGAffineTransformIdentity;
        self.addGameTile.layer.borderColor =
            (selected ? [UIColor colorWithRed:0.55 green:0.86 blue:1.0 alpha:1.0]
                      : [UIColor colorWithWhite:1.0 alpha:0.30])
                .CGColor;
        self.addGameTile.layer.shadowOpacity = selected ? 0.32 : 0.0;
        self.addGameTile.layer.shadowRadius = selected ? 18.0 : 0.0;
        self.addGameTile.layer.shadowColor = UIColor.cyanColor.CGColor;
    };
    [self animateDashboardChanges:animated baseTime:0.22 damping:0.76 changes:changes completion:nil];
}

- (void)updateTopMenuFocusAnimated:(BOOL)animated {
    [self.topMenuButtons enumerateObjectsUsingBlock:^(UIButton* button, NSUInteger idx, BOOL* stop) {
        const BOOL selected = self.topMenuFocused && idx == (NSUInteger)self.topMenuIndex;
        void (^changes)(void) = ^{
            button.transform = selected ? CGAffineTransformMakeScale(1.28, 1.28) : CGAffineTransformIdentity;
            button.tintColor =
                selected ? [UIColor colorWithRed:0.58 green:0.88 blue:1.0 alpha:1.0]
                         : [UIColor colorWithWhite:1.0 alpha:0.92];
            button.layer.shadowOpacity = selected ? 0.48 : 0.0;
            button.layer.shadowRadius = selected ? 12.0 : 0.0;
            button.layer.shadowColor = UIColor.cyanColor.CGColor;
        };
        [self animateDashboardChanges:animated baseTime:0.18 damping:0.72 changes:changes completion:nil];
    }];
}

- (void)installControllerSupport {
    NSNotificationCenter* center = NSNotificationCenter.defaultCenter;
    [center addObserver:self
               selector:@selector(controllerDidConnect:)
                   name:GCControllerDidConnectNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(controllerDidDisconnect:)
                   name:GCControllerDidDisconnectNotification
                 object:nil];

    [GCController startWirelessControllerDiscoveryWithCompletionHandler:nil];
    self.activeController = GCController.controllers.firstObject;
    [self configureController:self.activeController];

    self.controllerPollLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(pollController)];
    self.controllerPollLink.preferredFramesPerSecond = 30;
    [self.controllerPollLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}

- (void)controllerDidConnect:(NSNotification*)notification {
    GCController* controller = notification.object;
    self.activeController = controller;
    [self configureController:controller];
}

- (void)controllerDidDisconnect:(NSNotification*)notification {
    if (notification.object == self.activeController) {
        self.activeController = GCController.controllers.firstObject;
        [self configureController:self.activeController];
    }
}

- (void)configureController:(GCController*)controller {
    if (controller == nil) {
        self.statusLabel.text = @"No Bluetooth controller connected";
        NSLog(@"shadPS4 iOS: no GameController device visible to iPadOS.");
        return;
    }

    controller.playerIndex = GCControllerPlayerIndex1;
    NSString* name = controller.vendorName ?: @"Controller";
    self.statusLabel.text = [NSString stringWithFormat:@"%@ connected", name];
    NSLog(@"shadPS4 iOS: GameController connected: %@", name);

    GCExtendedGamepad* gamepad = controller.extendedGamepad;
    gamepad.buttonA.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, BOOL pressed) {
        [self controllerPhysicalButton:@"A" pressed:pressed defaultTarget:@"Cross"];
    };
    gamepad.buttonB.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, BOOL pressed) {
        [self controllerPhysicalButton:@"B" pressed:pressed defaultTarget:@"Circle"];
    };
    gamepad.buttonX.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, BOOL pressed) {
        [self controllerPhysicalButton:@"X" pressed:pressed defaultTarget:@"Square"];
    };
    gamepad.buttonY.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, BOOL pressed) {
        [self controllerPhysicalButton:@"Y" pressed:pressed defaultTarget:@"Triangle"];
    };
    GCControllerButtonInput* menuButton = ShadOptionalButtonInput(gamepad, @selector(buttonMenu));
    menuButton.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, BOOL pressed) {
        if (pressed) {
            if (self.dashboardView.hidden) {
                [self runtimeMenuButtonPressed];
            } else {
                [self settingsPressed];
            }
        }
    };
    GCControllerButtonInput* optionsButton = ShadOptionalButtonInput(gamepad, @selector(buttonOptions));
    optionsButton.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, BOOL pressed) {
        if (pressed) {
            if (self.dashboardView.hidden) {
                [self runtimeMenuButtonPressed];
            } else {
                [self settingsPressed];
            }
        }
    };
}

- (void)pollController {
    GCExtendedGamepad* gamepad = self.activeController.extendedGamepad;
    if (gamepad == nil || self.presentedViewController != nil) {
        return;
    }

    if (self.dashboardView.hidden) {
        ShadIOSCoreBridge* bridge = [ShadIOSCoreBridge sharedBridge];
        [bridge setLeftStickX:gamepad.leftThumbstick.xAxis.value y:gamepad.leftThumbstick.yAxis.value];
        [bridge setRightStickX:gamepad.rightThumbstick.xAxis.value y:gamepad.rightThumbstick.yAxis.value];
        [bridge setDpadX:gamepad.dpad.xAxis.value y:gamepad.dpad.yAxis.value];
        [bridge setLeftTrigger:gamepad.leftTrigger.value];
        [bridge setRightTrigger:gamepad.rightTrigger.value];
        return;
    }

    const CFTimeInterval now = CACurrentMediaTime();
    if (now - self.lastControllerMoveTime < 0.18) {
        return;
    }

    const float x = fabsf(gamepad.leftThumbstick.xAxis.value) > fabsf(gamepad.dpad.xAxis.value)
                        ? gamepad.leftThumbstick.xAxis.value
                        : gamepad.dpad.xAxis.value;
    const float y = fabsf(gamepad.leftThumbstick.yAxis.value) > fabsf(gamepad.dpad.yAxis.value)
                        ? gamepad.leftThumbstick.yAxis.value
                        : gamepad.dpad.yAxis.value;

    if (x > 0.55f) {
        [self controllerMoveHorizontal:1];
        self.lastControllerMoveTime = now;
    } else if (x < -0.55f) {
        [self controllerMoveHorizontal:-1];
        self.lastControllerMoveTime = now;
    } else if (y > 0.55f) {
        self.topMenuFocused = YES;
        [self playMoveSound];
        [self updateSelectedGameAnimated:YES];
        self.lastControllerMoveTime = now;
    } else if (y < -0.55f) {
        self.topMenuFocused = NO;
        [self playMoveSound];
        [self updateSelectedGameAnimated:YES];
        self.lastControllerMoveTime = now;
    }
}

- (void)controllerMoveHorizontal:(NSInteger)delta {
    if (self.dashboardView.hidden) {
        return;
    }

    if (self.topMenuFocused) {
        self.topMenuIndex = MIN(MAX(self.topMenuIndex + delta, 0), (NSInteger)self.topMenuButtons.count - 1);
    } else {
        const NSInteger maxIndex = (NSInteger)self.games.count;
        self.selectedGameIndex = MIN(MAX(self.selectedGameIndex + delta, 0), maxIndex);
        [self scrollSelectedTileIntoView];
    }
    [self playMoveSound];
    [self updateSelectedGameAnimated:YES];
}

- (void)scrollSelectedTileIntoView {
    UIView* selectedView = nil;
    if (self.selectedGameIndex >= 0 && self.selectedGameIndex < (NSInteger)self.gameButtons.count) {
        selectedView = self.gameButtons[(NSUInteger)self.selectedGameIndex];
    } else if (self.selectedGameIndex >= (NSInteger)self.games.count) {
        selectedView = self.addGameTile;
    }

    if (selectedView == nil) {
        return;
    }
    CGRect rect = [self.gameScrollView convertRect:selectedView.bounds fromView:selectedView];
    [self.gameScrollView scrollRectToVisible:CGRectInset(rect, -40.0, 0.0) animated:YES];
}

- (NSString*)mappedTargetForPhysicalButton:(NSString*)physical defaultTarget:(NSString*)defaultTarget {
    NSDictionary* mapping = [[NSUserDefaults standardUserDefaults] dictionaryForKey:ShadControllerMappingDefaultsKey];
    NSString* target = mapping[physical];
    return target.length > 0 ? target : defaultTarget;
}

- (NSString*)virtualControlKeyForMappedTarget:(NSString*)target {
    NSDictionary* table = @{
        @"Cross" : @"cross",
        @"Circle" : @"circle",
        @"Square" : @"square",
        @"Triangle" : @"triangle",
        @"Options" : @"options",
        @"Share" : @"share",
    };
    return table[target] ?: @"cross";
}

- (void)controllerPhysicalButton:(NSString*)physical pressed:(BOOL)pressed defaultTarget:(NSString*)defaultTarget {
    NSString* target = [self mappedTargetForPhysicalButton:physical defaultTarget:defaultTarget];
    if (self.dashboardView.hidden) {
        [self setVirtualControl:[self virtualControlKeyForMappedTarget:target] pressed:pressed];
        return;
    }
    if (!pressed || self.presentedViewController != nil) {
        return;
    }
    if ([target isEqualToString:@"Cross"]) {
        [self controllerAccept];
    } else if ([target isEqualToString:@"Circle"]) {
        [self controllerBack];
    } else if ([target isEqualToString:@"Options"]) {
        [self settingsPressed];
    } else if ([target isEqualToString:@"Share"]) {
        [self trophiesPressed];
    } else {
        [self playMoveSound];
    }
}

- (void)controllerAccept {
    if (self.presentedViewController != nil) {
        return;
    }

    if (self.dashboardView.hidden) {
        [self setVirtualControl:@"cross" pressed:YES];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.08 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self setVirtualControl:@"cross" pressed:NO];
        });
        return;
    }

    if (self.topMenuFocused) {
        if (self.topMenuIndex == 0) {
            [self trophiesPressed];
        } else if (self.topMenuIndex == 1) {
            [self settingsPressed];
        } else {
            [self profilePressed];
        }
        return;
    }

    [self startSelectedGame];
}

- (void)controllerBack {
    if (self.presentedViewController != nil) {
        [self dismissViewControllerAnimated:YES completion:nil];
        [self playMoveSound];
        return;
    }

    if (!self.dashboardView.hidden) {
        self.topMenuFocused = NO;
        [self updateSelectedGameAnimated:YES];
        [self playMoveSound];
        return;
    }

    [self setVirtualControl:@"circle" pressed:YES];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.08 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self setVirtualControl:@"circle" pressed:NO];
    });
}

- (void)updateClock {
    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"HH:mm";
    self.clockLabel.text = [formatter stringFromDate:NSDate.date];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView*)scrollView {
    [self selectNearestGameFromScrollPosition];
}

- (void)scrollViewDidEndDragging:(UIScrollView*)scrollView willDecelerate:(BOOL)decelerate {
    if (!decelerate) {
        [self selectNearestGameFromScrollPosition];
    }
}

- (void)selectNearestGameFromScrollPosition {
    if (self.gameButtons.count == 0) {
        return;
    }

    CGFloat viewportMid = self.gameScrollView.contentOffset.x + self.gameScrollView.bounds.size.width * 0.5;
    CGFloat bestDistance = CGFLOAT_MAX;
    NSInteger bestIndex = self.selectedGameIndex;
    for (NSUInteger i = 0; i < self.gameButtons.count; i++) {
        UIButton* button = self.gameButtons[i];
        CGPoint center = [self.gameScrollView convertPoint:button.center fromView:button.superview];
        CGFloat distance = fabs(center.x - viewportMid);
        if (distance < bestDistance) {
            bestDistance = distance;
            bestIndex = (NSInteger)i;
        }
    }
    if (bestIndex != self.selectedGameIndex) {
        self.selectedGameIndex = bestIndex;
        [self playMoveSound];
        [self updateSelectedGameAnimated:YES];
    }
}

- (void)playMoveSound {
    [self playSoundPlayer:([self consoleSoundThemeEnabled] ? self.consoleMoveSoundPlayer : self.moveSoundPlayer)
                 fallback:1104];
}

- (void)playAcceptSound {
    [self playSoundPlayer:([self consoleSoundThemeEnabled] ? self.consoleAcceptSoundPlayer : self.acceptSoundPlayer)
                 fallback:1105];
}

- (void)playBackSound {
    [self playSoundPlayer:([self consoleSoundThemeEnabled] ? self.consoleBackSoundPlayer : self.backSoundPlayer)
                 fallback:1155];
}

- (void)playSoundPlayer:(AVAudioPlayer*)player fallback:(SystemSoundID)fallback {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:ShadSettingUISoundEffectsKey] &&
        [[NSUserDefaults standardUserDefaults] objectForKey:ShadSettingUISoundEffectsKey] != nil) {
        return;
    }
    [self ensureUISoundAudioSessionActive];

    float master = [[NSUserDefaults standardUserDefaults] objectForKey:ShadSettingMasterVolumeKey] == nil
                       ? 0.78f
                       : [[NSUserDefaults standardUserDefaults] floatForKey:ShadSettingMasterVolumeKey];
    float click = [[NSUserDefaults standardUserDefaults] objectForKey:ShadSettingClickVolumeKey] == nil
                      ? 0.82f
                      : [[NSUserDefaults standardUserDefaults] floatForKey:ShadSettingClickVolumeKey];
    float volume = MIN(MAX(master * click, 0.0f), 1.0f);

    if (player != nil) {
        player.volume = volume;
        [player prepareToPlay];
        player.currentTime = 0.0;
        if ([player play]) {
            return;
        }
        NSLog(@"shadPS4 iOS: AVAudioPlayer did not start, falling back to system sound %u", fallback);
    }
    if (fallback != 0) {
        AudioServicesPlaySystemSound(fallback);
    }
}

- (void)drawInMTKView:(MTKView*)view {
    const CFTimeInterval now = CACurrentMediaTime();
    const CFTimeInterval minDelta = 1.0 / MAX(1, self.frameLimit);
    if (self.lastDrawTime > 0 && now - self.lastDrawTime < minDelta) {
        return;
    }
    CFTimeInterval frameDelta = self.lastDrawTime > 0 ? now - self.lastDrawTime : minDelta;
    self.lastDrawTime = now;
    self.framesSinceStatsUpdate++;

    if (self.dashboardView.hidden) {
        if (now - self.lastThermalCheckTime >= 1.0) {
            self.lastThermalCheckTime = now;
            NSProcessInfoThermalState thermalState = NSProcessInfo.processInfo.thermalState;
            if (thermalState != self.lastThermalState || thermalState >= NSProcessInfoThermalStateSerious) {
                self.lastThermalState = thermalState;
                [[ShadIOSCoreBridge sharedBridge] applyThermalState:thermalState];
                self.frameLimit = [ShadIOSCoreBridge sharedBridge].activeFrameLimit;
                view.preferredFramesPerSecond = self.frameLimit;
            }
        }
        if (self.lastStatsUpdateTime <= 0) {
            self.lastStatsUpdateTime = now;
            self.previousStatsFrameTime = now;
        } else if (now - self.lastStatsUpdateTime >= 0.50) {
            self.currentFPS = (double)self.framesSinceStatsUpdate / (now - self.lastStatsUpdateTime);
            self.currentCPUPercent = [self currentProcessCPUPercent];
            self.currentRAMMB = [self currentProcessRAMMB];
            self.currentGPULoadPercent = MIN(MAX((frameDelta / minDelta) * 100.0, 0.0), 100.0);
            self.framesSinceStatsUpdate = 0;
            self.lastStatsUpdateTime = now;
            [self updatePerformanceOverlayVisibility];
            [self updatePerformanceOverlayText];
        }
    }

    // TODO(iOS): hand view.currentDrawable and the CAMetalLayer-backed surface to MoltenVK here.
}

- (void)mtkView:(MTKView*)view drawableSizeWillChange:(CGSize)size {
    NSLog(@"shadPS4 iOS: drawable size changed to %.0fx%.0f", size.width, size.height);
}

@end
