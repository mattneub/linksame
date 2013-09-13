

#import <UIKit/UIKit.h>
@class Board;
//@class NameablePopoverController;

@interface LinkSameViewController : UIViewController <UIPopoverControllerDelegate> {
    Board* board;
    IBOutlet UIView* boardView;
    IBOutlet UILabel* stageLabel;
    IBOutlet UILabel* scoreLabel;
    IBOutlet UILabel* prevLabel;
    IBOutlet UIBarButtonItem* hintButton;
    int score;
    NSTimeInterval lastTime;
    NSTimer* timer;
    UIView* transp;
}

@property (nonatomic, retain) Board* board;
@property (nonatomic, assign) IBOutlet UIView* boardView;
@property (nonatomic, assign) IBOutlet UILabel* stageLabel;
@property (nonatomic, assign) IBOutlet UILabel* scoreLabel;
@property (nonatomic, assign) IBOutlet UILabel* prevLabel;
@property (nonatomic, assign) IBOutlet UIBarButtonItem* hintButton;
@property (nonatomic, assign) IBOutlet UISegmentedControl* timedPractice;
@property (nonatomic, retain) UIPopoverController* popover;
@property (nonatomic, retain) NSDictionary* oldDefs;
@property (nonatomic, retain) NSTimer* timer;

- (IBAction) doHint: (id) sender;
- (IBAction) doNew: (id) sender;
- (IBAction) doHelp: (id) sender;
- (IBAction) doShuffle: (id) sender;
- (IBAction) doTimedPractice: (id) sender;

@end

