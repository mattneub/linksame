

#import <UIKit/UIKit.h>

@class LinkSameViewController;

@interface LinkSameAppDelegate : NSObject <UIApplicationDelegate> {
    UIWindow *window;
    LinkSameViewController *viewController;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet LinkSameViewController *viewController;

@end

