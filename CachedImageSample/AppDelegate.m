#import "AppDelegate.h"

void uncaughtExceptionHandler(NSException *exception) {
    LOG(@"CRASH: %@", exception);
    LOG(@"Stack Trace: %@", [exception callStackSymbols]);
}

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
#if DEBUG
    NSSetUncaughtExceptionHandler(&uncaughtExceptionHandler);
#endif
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
}

- (void)applicationWillTerminate:(UIApplication *)application {
}

@end
