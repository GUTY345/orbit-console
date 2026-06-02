#pragma once

#import <Foundation/Foundation.h>
#import <MetalKit/MetalKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ShadIOSCoreBridge : NSObject

@property(nonatomic, readonly, getter=isRunning) BOOL running;
@property(nonatomic, readonly, getter=isDebuggerAttached) BOOL debuggerAttached;
@property(nonatomic, readonly) NSInteger activeFrameLimit;

+ (instancetype)sharedBridge;

- (void)prepareRuntimeEnvironment;
- (void)attachMetalView:(MTKView*)metalView;
- (void)updateRenderSurfaceDrawableSize:(CGSize)drawableSize;
- (void)applyUserDefaultsToCore;
- (BOOL)startGameAtPath:(NSString*)gamePath error:(NSError**)error;
- (void)applyThermalState:(NSProcessInfoThermalState)thermalState;
- (void)releaseAllInputs;

- (void)setButton:(NSString*)button pressed:(BOOL)pressed;
- (void)setLeftStickX:(float)x y:(float)y;
- (void)setRightStickX:(float)x y:(float)y;
- (void)setDpadX:(float)x y:(float)y;
- (void)setLeftTrigger:(float)value;
- (void)setRightTrigger:(float)value;

@end

extern "C" void ShadIOSApplyPendingEmulatorSettings(void);
extern "C" void* ShadIOSGetNativeMetalLayer(void);
extern "C" float ShadIOSGetNativeRenderScale(void);
extern "C" int ShadIOSGetCoreStage(void);
extern "C" const char* ShadIOSGetCoreStageDescription(void);
extern "C" void ShadIOSSetCoreStage(int stage, const char* description);
extern "C" void ShadIOSAppendDiagnosticLog(const char* message);

NS_ASSUME_NONNULL_END
