

#import "LinkSameViewController.h"
#import "Piece.h"
#import "Board.h"
#import "MutableArrayCategories.h"
#import "NewGameController.h"
//#import "NameablePopoverController.h"

@interface LinkSameViewController ()<UIPopoverControllerDelegate, UIToolbarDelegate> {
    int score;
    NSTimeInterval lastTime;
    UIView* transp;
}

@property (nonatomic, strong) Board* board;
@property (nonatomic, weak) IBOutlet UIView* boardView;
@property (nonatomic, weak) IBOutlet UILabel* stageLabel;
@property (nonatomic, weak) IBOutlet UILabel* scoreLabel;
@property (nonatomic, weak) IBOutlet UILabel* prevLabel;
@property (nonatomic, weak) IBOutlet UIBarButtonItem* hintButton;
@property (nonatomic, weak) IBOutlet UISegmentedControl* timedPractice;
@property (nonatomic, weak) IBOutlet UIToolbar* toolbar;
@property (nonatomic, strong) UIPopoverController* popover;
@property (nonatomic, strong) NSDictionary* oldDefs;
@property (nonatomic, strong) NSTimer* timer;


- (IBAction) doHint: (id) sender;
- (IBAction) doNew: (id) sender;
- (IBAction) doHelp: (id) sender;
- (IBAction) doShuffle: (id) sender;
- (IBAction) doTimedPractice: (id) sender;

- (void) incrementScore: (int) n;
- (void) initializeScores;
@end


@implementation LinkSameViewController

-(UIBarPosition)positionForBar:(id<UIBarPositioning>)bar {
    return UIBarPositionTopAttached;
}

- (void) setInterfaceMode: (BOOL) timed {
    self.scoreLabel.hidden = !timed;
    self.prevLabel.hidden = !timed;
    self.timedPractice.selectedSegmentIndex = timed ? 0 : 1;
    self.timedPractice.enabled = timed;
}

- (void) initializeScores {
    // current score, zero
    self->score = 0;
    [self incrementScore:0];
    // prev score, look up in user defaults
    self.prevLabel.text = @"";
    NSUserDefaults* ud = [NSUserDefaults standardUserDefaults];
    NSString* size = [ud stringForKey:@"Size"];
    NSString* stages = [[ud objectForKey:@"Stages"] stringValue];
    NSNumber* prev = [ud dictionaryForKey:@"Scores"][[NSString stringWithFormat: @"%@%@", size, stages]];
    if (prev)
        self.prevLabel.text = [NSString stringWithFormat:@"(High score: %@)", prev];
    // every new game should be a real game initially
//    self.scoreLabel.hidden = NO;
//    self.prevLabel.hidden = NO;
//    self.timedPractice.selectedSegmentIndex = 0;
//    self.timedPractice.enabled = YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.toolbar.delegate = self;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setUpInterface:) name:@"gameOver" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userMoved:) name:@"userMoved" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(screenOff:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(screenOff:) name:UIApplicationWillTerminateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(screenOn:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [self initializeScores];
    //NSLog(@"didload frame %@", NSStringFromCGRect(self.view.frame));
    //NSLog(@"didload bounds %@", NSStringFromCGRect(self.view.bounds));
    // fix width of hint button to accomodate new labels Show Hint and Hide Hint
    self.hintButton.possibleTitles = [NSSet setWithObjects:@"Show Hint", @"Hide Hint", nil];
    self.hintButton.title = @"Show Hint";
    // must wait until rotation has settled down before finishing interface, otherwise dimensions are wrong
    // have we a state saved from prior practice?
    NSData* boardData = [[NSUserDefaults standardUserDefaults] valueForKey:@"boardData"];
    if (boardData)
        [self performSelector:@selector(reconstructInterface:) withObject:nil afterDelay:0.1];
    else
        [self performSelector:@selector(saveNewGame:) withObject:nil afterDelay:0.1];
}

/*
- (void) didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    // log messages in order to demonstrate how dimensions change as interface settles down
    // however, it may be that my conclusions would have been different if I had set plist orientations first
    //NSLog(@"didrotate frame %@", NSStringFromCGRect(self.view.frame));
    //NSLog(@"didrotate bounds %@", NSStringFromCGRect(self.view.bounds));
}
 */

- (void) replaceTimer {
    if (self.timer)
        [self.timer invalidate];
    //NSLog(@"creating timer");
    self.timer = [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(decrementScore:) 
                                                userInfo:nil repeats:YES];
}

- (void) incrementScore: (int) n {
    self->score += n;
    self.scoreLabel.text = [NSString stringWithFormat:@"%i", score];
    self.scoreLabel.textColor = [UIColor blackColor];
    [self replaceTimer];
}

- (void) decrementScore: (id) dummy {
    //NSLog(@"decrementing score");
    self->score -= 1;
    self.scoreLabel.text = [NSString stringWithFormat:@"%i", score];
    self.scoreLabel.textColor = [UIColor redColor];
}

- (void) screenOff: (id) dummy {
    if (self.timer)
        [self.timer invalidate];
    // we might be about to terminate
    NSInteger ix = self.timedPractice.selectedSegmentIndex;
    // 0 = timed; 1 = practice
    if (ix == 1) { // save out board state
        NSData* boardData = [NSKeyedArchiver archivedDataWithRootObject:self.board];
        [[NSUserDefaults standardUserDefaults] setValue:boardData forKey:@"boardData"];
        //NSLog(@"saving out board data");
    } else { // make sure that board state is not saved
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"boardData"];
    }
}

- (void) screenOn: (id) dummy {
    [self replaceTimer];
}

- (void) clearViewAndCreatePathView {
    // clear the view!
    for (UIView *v in [self.boardView subviews]) {
        [v removeFromSuperview];
    }
    
    // board is now completely empty
    // place invisible view on top of it; this is where paths will be drawn
    // we will draw directly into its layer using layer delegate's drawLayer:inContext:
    // but we must not set a view's layer's delegate, so we create a sublayer
    UIView* v = [[UIView alloc] initWithFrame:[self.boardView bounds]];
    v.tag = 999;
    v.userInteractionEnabled = NO; // clicks just fall right thru
    self->transp = v;
    [self.boardView addSubview:v];
    CALayer* lay = [CALayer layer];
    [[self->transp layer] addSublayer:lay];
    lay.frame = [self->transp layer].bounds;       
}

- (void) displayStage {
    // delay to give any other animations time to happen, add emphasis
    [self performSelector:@selector(reallyDisplayStage) withObject:nil afterDelay:1.0];
}

- (void) reallyDisplayStage {
    NSUserDefaults* ud = [NSUserDefaults standardUserDefaults];
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.4];
    [UIView setAnimationTransition:UIViewAnimationTransitionFlipFromLeft forView:self.stageLabel cache:YES];
    self.stageLabel.text = [NSString stringWithFormat:@"Stage %i of %i", 
                            [self.board.stage intValue] + 1, 
                            [ud integerForKey:@"Stages"] + 1];
    [UIView commitAnimations];    
}

- (void) animateBoardReplacement: (BOOL) slide {
    self.boardView.userInteractionEnabled = NO; // about to animate, turn off interaction; will turn back on in delegate
    CATransition* t = [CATransition animation];
    if (slide) {
        t.type = kCATransitionMoveIn;
        t.subtype = kCATransitionFromLeft;
    }
    t.duration = 0.7;
    t.beginTime = CACurrentMediaTime() + 0.4;
    t.fillMode = kCAFillModeBackwards;
    t.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    t.delegate = self;
    [t setValue: @"boardReplacement" forKey: @"name"];
    [self.boardView.layer addAnimation: t forKey: nil];
}

- (void) animationDidStop:(CAAnimation *)anim finished:(BOOL)flag {
    if ([[anim valueForKey:@"name"] isEqualToString: @"boardReplacement"]) // should be
        self.boardView.userInteractionEnabled = YES;
}

// called at startup
// called when user asks for a new game
// called when user completes a stage
- (void) setUpInterface: (NSNotification*) n {
    // log messages show that after delayed performance is when interface dimensions are correct
    //NSLog(@"setup frame %@", NSStringFromCGRect(self.view.frame));
    //NSLog(@"setup bounds %@", NSStringFromCGRect(self.view.bounds));
    
    // initialize time
    self->lastTime = [NSDate timeIntervalSinceReferenceDate];
    // remove existing timer; timing will start when user moves
    if (self.timer) {
        [self.timer invalidate];
        self.timer = nil;
    }
    // determine layout dimensions
    NSUserDefaults* ud = [NSUserDefaults standardUserDefaults];
    int w = 12;
    int h = 7;
    if ([[ud valueForKey: @"Size"] isEqualToString:@"Normal"]) {
        w = 14;
        h = 8;
    }
    if ([[ud valueForKey: @"Size"] isEqualToString:@"Hard"]) {
        w = 16;
        h = 9;
    }
    // determine which pieces to use
    int start1 = 11;
    int start2 = 110;
    if ([[ud valueForKey: @"Style"] isEqualToString:@"Snacks"]) {
        start1 = 21;
        start2 = 210;
    }
    // create deck of piece names
    NSMutableArray* deck = [NSMutableArray array];
    for (int ct=0; ct<4; ct++) {
        for (int i=start1; i<start1+9; i++) {
            NSString* name = [NSString stringWithFormat:@"%i", i];
            [deck addObject: name];
        }
    }
    // determine which additional pieces to use, finish deck of piece names
    int howmany = (w * h)/4 - 9;
    for (int ct=0; ct<4; ct++) {
        for (int i=start2; i<start2+howmany; i++) {
            NSString* name = [NSString stringWithFormat:@"%i", i];
            [deck addObject: name];
        }
    }
    [deck shuffle];
    [deck shuffle];
    [deck shuffle];
    [deck shuffle];
    
    // create new board object and configure it
    Board* b = [[Board alloc] initWithBoardView:self.boardView];
    self.board = b;
    
    [self.board setGridSizeX:w Y:h];
    
    // stage (current stage arrived in notification, or nil if we are just starting)
    [self.board setStage:@0]; // default
    // notice use of [NSNotification class] here; using class name didn't work, it's a cluster or something!
    if (n && ([n isKindOfClass: [NSNotification class]]) && [n userInfo]) {
        int stage = [[[n userInfo] valueForKey:@"stage"] intValue];
        // if we received a stage in notification, just increment stage
        if (stage < [[NSUserDefaults standardUserDefaults] integerForKey:@"Stages"]) {
            [self.board setStage:@(stage+1)];
            [self animateBoardReplacement: YES];
        }
        // but if we received a stage in notification and it's the last stage, game is over!
        else {
            // do score and notification stuff only if user is not just practicing
            if (self.timedPractice.selectedSegmentIndex == 0) {
                // if high score, store
                NSUserDefaults* ud = [NSUserDefaults standardUserDefaults];
                NSString* size = [ud stringForKey:@"Size"];
                NSString* stages = [[ud objectForKey:@"Stages"] stringValue];
                NSString* key = [NSString stringWithFormat: @"%@%@", size, stages];
                NSMutableDictionary* d = [NSMutableDictionary dictionaryWithDictionary:[ud dictionaryForKey:@"Scores"]];
                NSNumber* prev = d[key];
                BOOL newHigh = NO;
                if (!prev || [prev intValue] < self->score) {
                    newHigh = YES;
                    d[key] = @(self->score);
                    [ud setObject: d forKey: @"Scores"];
                }
                // notify user
                UIAlertView* alert = [[UIAlertView alloc] 
                                      initWithTitle:@"Congratulations!" 
                                      message:[NSString stringWithFormat: @"You have finished the game with a score of %i.%@", 
                                               self->score, 
                                               (newHigh ? @" This is a new high score for this level!" : @"")] 
                                      delegate:nil 
                                      cancelButtonTitle:@"Cool!" 
                                      otherButtonTitles:nil];
                [alert show];
            }
            [self initializeScores];
            [self setInterfaceMode: YES]; // every new game is a timed game
            [self.timer invalidate]; // prev line starts timer, stop it
            [self animateBoardReplacement: NO];
        }
    }
    
    // continue to lay out new game / stage, even if alert just went up
    
    // stage label
    [self displayStage];
    
    // initialize empty board
    [self clearViewAndCreatePathView];
    
    // deal out the pieces and we're all set! Pieces themselves and Board object take over interactions from here
    for (int i=0; i<w; i++) {
        for (int j=0; j<h; j++) {
            [self.board addPieceAtX: i Y:j withPicture:[deck lastObject]];
            [deck removeLastObject];
        }
    }
}

- (void) reconstructInterface: (id) dummy {
    // set up our own view
    [self clearViewAndCreatePathView];
    // fetch stored board
    NSData* boardData = [[NSUserDefaults standardUserDefaults] valueForKey:@"boardData"];
    self.board = [NSKeyedUnarchiver unarchiveObjectWithData:boardData];
    // but this board is not fully realized; it has no view pointer
    self.board.view = self.boardView;
    // another problem is that the board's reconstructed pieces are not actually showing
    // but the board itself will fix that if we ask it to rebuild itself
    [self.board rebuild];
    // set interface up as practice and we're all set
    [self setInterfaceMode: NO];
    [self displayStage];
}


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.timer invalidate];
}

#pragma mark toolbar buttons

- (IBAction) doHint: (id) sender { // sender should be hintButton
    if (!self.board.showingHint) {
        self.hintButton.title = @"Hide Hint";
        [self incrementScore:-10];
        [self.board hint];
        // if user taps board now, this should have just the same effect as tapping button
        // so, attach gesture rec
        UITapGestureRecognizer* t = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doHint:)];
        [[self.boardView viewWithTag:999] addGestureRecognizer:t];
    } else {
        self.hintButton.title = @"Show Hint";
        [self.board unilluminate];
        [[self.boardView viewWithTag:999] setGestureRecognizers:nil];
    }
}

- (IBAction) doShuffle: (id) sender {
    if (self.board.showingHint)
        [self doHint: nil];
    [self.board redeal];
    [self incrementScore:-20];
}

/* popovers - ok, popovers are really badly implemented by the system!
   (1) You are not allowed to release a popover controller while the popover is showing
   ...so you have to release it yourself later (unless you cache it)
   (2) If you want to dismiss a popover via a button in the popover,
   ...you can't get a reference to the popover controller (the "sender" doesn't know it's "in" a popover)
   (3) You can't distinguish popovers from one another; the controllers have no "name" or other identifier property
   Putting these together, you are basically forced to keep a reference to a popover as an ivar
   But suppose you have more than one popover (as we do); now what?
   We can worry less because we see to it that only one popover at a time will show;
   but if you wanted to show multiple popovers simultaneously you'd have to manage references to all of them.
 */

// okay, so self.popover is used to maintain a pointer to the currently showing popover
// and only one can show at a time, so this works
   
- (IBAction) doNew: (id) sender {
    if (self.board.showingHint)
        [self doHint:nil];
    if (self.popover)
        return; // amazingly, it is up to us to prevent button being pressed while we are up
    // okay, wait, the real problem is that the whole nav bar is passthru view
    // fixed by setting passthru views to nil after presenting
    // but I've left that line in, to alert myself that this can be an issue
    
    // create dialog from scratch (see NewGameController for rest of interface)
    NewGameController* dlg = [[NewGameController alloc] init];
    UIBarButtonItem* b = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemCancel
                                                                       target:self
                                                                       action:@selector(cancelNewGame:)];
    dlg.navigationItem.rightBarButtonItem = b;
    b = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemDone
                                                      target: self
                                                      action: @selector(saveNewGame:)];
    dlg.navigationItem.leftBarButtonItem = b;
    UINavigationController* nav = [[UINavigationController alloc] initWithRootViewController:dlg];
    UIPopoverController* pop = [[UIPopoverController alloc] initWithContentViewController:nav];
    pop.delegate = self;
    // pop.popoverContentSize = CGSizeMake(320, 310+216+40);
    // pop.name = @"new";
    [pop presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
    pop.passthroughViews = nil;
    //NSLog(@"%@ %@", NSStringFromCGSize(nav.contentSizeForViewInPopover), NSStringFromCGSize(nav.topViewController.contentSizeForViewInPopover));
    self.popover = pop;
    // save defaults so we can restore them later if user cancels
    self.oldDefs = [[NSUserDefaults standardUserDefaults] dictionaryWithValuesForKeys:
                    @[@"Style", @"Size", @"Stages"]];
}

- (void) cancelNewGame: (id) sender { // cancel button in New Game popover
    [self.popover dismissPopoverAnimated:YES];
    self.popover = nil;
    [[NSUserDefaults standardUserDefaults] setValuesForKeysWithDictionary:self.oldDefs];
}

- (void) saveNewGame: (id) sender { // save button in New Game popover
    [self.popover dismissPopoverAnimated:YES];
    self.popover = nil;
    [self setUpInterface:nil];
    [self initializeScores];
    [self setInterfaceMode:YES];
    [self.timer invalidate]; // prev line starts timer, stop it
    [self animateBoardReplacement: NO];
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)pc {
    // this is why we gave the popover a name; we can tell which popover is up
    //if ([self.popover.name isEqualToString:@"new"])
    if ([pc.contentViewController isKindOfClass: [UINavigationController class]]) {
        [[NSUserDefaults standardUserDefaults] setValuesForKeysWithDictionary:self.oldDefs];
    }
    self.popover = nil;
}

- (IBAction) doTimedPractice: (id) sender {
    if (self.board.showingHint)
        [self doHint:nil];
    NSInteger ix = self.timedPractice.selectedSegmentIndex;
    // 0 = timed; 1 = practice
    // in reality the user should never be able to switch to timed! it's just an indicator
    if (ix == 1) {
        self.scoreLabel.hidden = YES;
        self.prevLabel.hidden = YES;
        self.timedPractice.enabled = NO;
    }
}

- (IBAction) doHelp: (id) sender {
    // create help from scratch
    UIViewController* vc = [[UIViewController alloc] init];
    UIWebView* wv = [[UIWebView alloc] init];
    NSString* s = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"linkhelp" ofType:@"html"] encoding:NSUTF8StringEncoding error:nil];
    [wv loadHTMLString:s baseURL:nil];
    vc.view = wv;
    UIPopoverController* pop = [[UIPopoverController alloc] initWithContentViewController:vc];
    //pop.name = @"help";
    pop.delegate = self; // must have delegate so we can manage popover pointer when dismissed
    pop.popoverContentSize = CGSizeMake(600, 800);
    [pop presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
    pop.passthroughViews = nil;
    self.popover = pop;
}

#pragma mark notif from board

// the board notifies us that the user removed a pair of pieces
// track time between moves, award points (and remember, points mean prizes)

- (void) userMoved: (id) dummy {
    NSTimeInterval t = [NSDate timeIntervalSinceReferenceDate];
    NSTimeInterval told = self->lastTime;
    self->lastTime = t;
    NSTimeInterval diff = t - told;
    int bonus = 0;
    if (diff < 10)
        bonus = ceil(10.0/diff);
    [self incrementScore: 1 + bonus];
}

@end
