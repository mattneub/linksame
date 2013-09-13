

#import "LinkSameAppDelegate.h"
#import "LinkSameViewController.h"

@implementation LinkSameAppDelegate

@synthesize window;
@synthesize viewController;


+ (void) initialize {
    if ( self == [LinkSameAppDelegate class] ) {
        [[NSUserDefaults standardUserDefaults] registerDefaults:
         [NSDictionary dictionaryWithObjectsAndKeys:
          @"Easy", @"Size", 
          @"Snacks", @"Style", 
          [NSNumber numberWithInt:8], @"Stages", 
          [NSDictionary dictionary], @"Scores", 
          nil]];
    }
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {    
    
    [window addSubview:viewController.view];
    [window makeKeyAndVisible];

	return YES;
}

- (void)dealloc {
    [viewController release];
    [window release];
    [super dealloc];
}


@end
