#import "ShadAppDelegate.h"

#import "ShadViewController.h"

@implementation ShadAppDelegate

- (BOOL)application:(UIApplication*)application
    didFinishLaunchingWithOptions:(NSDictionary<UIApplicationLaunchOptionsKey, id>*)launchOptions {
    @autoreleasepool {
        application.idleTimerDisabled = YES;

        UIScreen* screen = UIScreen.mainScreen;
        self.window = [[UIWindow alloc] initWithFrame:screen.bounds];
        self.window.backgroundColor = UIColor.blackColor;
        self.window.clipsToBounds = YES;
        ShadViewController* root = [[ShadViewController alloc] init];
        root.modalPresentationStyle = UIModalPresentationFullScreen;
        self.window.rootViewController = root;
        [self.window makeKeyAndVisible];
        self.window.frame = screen.bounds;
    }

    NSLog(@"Orbit Console iOS: UIKit bootstrap completed; emulator core is not started until a ROM is loaded.");
    return YES;
}

- (void)applicationDidEnterBackground:(UIApplication*)application {
    application.idleTimerDisabled = NO;
    NSLog(@"Orbit Console iOS: entered background, heavy emulator work should be paused here.");
}

- (void)applicationWillEnterForeground:(UIApplication*)application {
    application.idleTimerDisabled = YES;
    NSLog(@"Orbit Console iOS: entering foreground.");
}

- (void)applicationWillTerminate:(UIApplication*)application {
    NSLog(@"Orbit Console iOS: terminating, stop emulator threads here.");
}

@end
