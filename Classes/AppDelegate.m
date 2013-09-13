

#import "AppDelegate.h"
#import "LinkSameViewController.h"

@implementation AppDelegate

+ (void) initialize {
    if ( self == [AppDelegate class] ) {
        [[NSUserDefaults standardUserDefaults] registerDefaults:
         @{@"Size": @"Easy", 
          @"Style": @"Snacks", 
          @"Stages": @8, 
          @"Scores": @{}}];
    }
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {    
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
    
    self.window.rootViewController = [LinkSameViewController new];
    
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    return YES;

}



@end
