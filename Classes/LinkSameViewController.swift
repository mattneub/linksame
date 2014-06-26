//
//  LinkSameViewController.swift
//  LinkSame
//
//  Created by Matt Neuburg on 6/23/14.
//
//

import UIKit
import QuartzCore

func delay(delay:Double, closure:()->()) {
    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            Int64(delay * Double(NSEC_PER_SEC))
        ),
        dispatch_get_main_queue(), closure)
}

var ud : NSUserDefaults {
return NSUserDefaults.standardUserDefaults()
}

var nc : NSNotificationCenter {
return NSNotificationCenter.defaultCenter()
}

extension Array {
    func shuffle () {
        for var i = self.count - 1; i != 0; i-- {
            let ix1 = i
            let ix2 = Int(arc4random_uniform(UInt32(i+1)))
            (self[ix1], self[ix2]) = (self[ix2], self[ix1])
        }
    }
}

struct Default {
    static let kSize = "Size"
    static let kStyle = "Style"
    static let kLastStage = "Stages"
    static let kScores = "Scores"
    static let kBoardData = "boardData"
}

struct Sizes {
    static let Easy = "Easy"
    static let Normal = "Normal"
    static let Hard = "Hard"
    static func sizes () -> String[] {
        return [Easy, Normal, Hard]
    }
    static func boardSize (s:String) -> (Int,Int) {
        let d = [
            Easy:(12,7),
            Normal:(14,8),
            Hard:(16,9)
        ]
        return d[s]!
    }
}


struct Styles {
    static let Animals = "Animals"
    static let Snacks = "Snacks"
    static func styles () -> String[] {
        return [Animals, Snacks]
    }
    static func pieces (s:String) -> (Int,Int) {
        let d = [
            Animals:(11,110),
            Snacks:(21,210)
        ]
        return d[s]!
    }
}


/*
@{@"Size": @"Easy",
    @"Style": @"Snacks",
    @"Stages": @8,
    @"Scores": @{}}];
So Size and Style are strings;
Stages is an integer;
and Scores is a dictionary of string-and-integer
*/


class LinkSameViewController : UIViewController, UIToolbarDelegate, UIPopoverPresentationControllerDelegate {
    
    
    var score = 0
    var lastTime : NSTimeInterval = 0
    var didSetUpObservers = false
    
    var board : Board!
    @IBOutlet var boardView : UIView
    @IBOutlet var stageLabel : UILabel
    @IBOutlet var scoreLabel : UILabel
    @IBOutlet var prevLabel : UILabel
    @IBOutlet var hintButton : UIBarButtonItem
    @IBOutlet var timedPractice : UISegmentedControl
    @IBOutlet var toolbar : UIToolbar
    var popover : UIPopoverController!
    var oldDefs : NSDictionary!
    var timer : NSTimer!
    
    enum InterfaceMode : Int {
        case Timed = 0
        case Practice = 1
        // and these are also the indexes of the timedPractice segmented control, heh heh
    }
    
    var interfaceMode : InterfaceMode = .Timed {
    willSet (mode) {
        var timed : Bool
        switch mode {
        case .Timed:
            timed = true
        case .Practice:
            timed = false
        }
        self.scoreLabel.hidden = !timed
        self.prevLabel.hidden = !timed
        self.timedPractice.selectedSegmentIndex = mode.toRaw()
        self.timedPractice.enabled = timed
    }
    }
    
    enum HintButtonTitle : String {
        case Show = "Show Hint"
        case Hide = "Hide Hint"
    }
    
    enum BoardTransition {
        case Slide
        case Fade
    }
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    func positionForBar(bar: UIBarPositioning!) -> UIBarPosition {
        return .TopAttached
    }
    
    func scoresKey() -> String {
        let size = ud.stringForKey(Default.kSize)
        let stages = ud.integerForKey(Default.kLastStage)
        return "\(size)\(stages)"
    }
    
    func initializeScores () {
        // current score
        self.score = 0
        self.incrementScore(0, resetTimer:false)
        // prev score, look up in user defaults
        self.prevLabel.text = ""
        let prev : Int? = ud.dictionaryForKey(Default.kScores)[self.scoresKey()] as? Int
        if prev {
            self.prevLabel.text = "High score: \(prev)"
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.toolbar.delegate = self
        self.initializeScores()
        // fix width of hint button to accomodate new labels Show Hint and Hide Hint
        self.hintButton.possibleTitles =
            NSSet(objects: HintButtonTitle.Show.toRaw(), HintButtonTitle.Hide.toRaw())
        self.hintButton.title = HintButtonTitle.Show.toRaw()
    }
    
    // setting up interface and observers in viewDidLoad was always wrong
    override func viewDidAppear(animated: Bool) {
        if self.didSetUpObservers {
            return
        }
        self.didSetUpObservers = true
        // must wait until rotation has settled down before finishing interface, otherwise dimensions are wrong
        // have we a state saved from prior practice?
        // return; // uncomment for launch image screen shot
        let boardData : AnyObject! = ud.objectForKey(Default.kBoardData)
        if boardData { // reconstruct practice game from board data
            // (non-practice game is not saved as board data!)
            // set up our own view
            self.clearViewAndCreatePathView()
            // fetch stored board
            let boardData = ud.objectForKey(Default.kBoardData) as NSData
            self.board = NSKeyedUnarchiver.unarchiveObjectWithData(boardData) as Board
            // but this board is not fully realized; it has no view pointer
            self.board.view = self.boardView
            // another problem is that the board's reconstructed pieces are not actually showing
            // but the board itself will fix that if we ask it to rebuild itself
            self.board.rebuild()
            // set interface up as practice and we're all set
            self.interfaceMode = .Practice
            self.displayStage()
        } else {
            self.saveNewGame(nil)
        }
        delay(2) { // but we still need a delay to prevent didBecomeActive being called immediately
            // I have filed a bug on this; it's the same issue I had in 99 Bottles
            nc.addObserver(self, selector: "setUpInterface:", name: "gameOver", object: nil)
            nc.addObserver(self, selector: "userMoved:", name: "userMoved", object: nil)
            nc.addObserver(self, selector: "screenOff", name: UIApplicationWillResignActiveNotification, object: nil)
            nc.addObserver(self, selector: "screenOff", name: UIApplicationWillTerminateNotification, object: nil)
            nc.addObserver(self, selector: "screenOn", name: UIApplicationDidBecomeActiveNotification, object: nil)
        }
    }
    
    func resetTimer() {
        self.timer?.invalidate()
        if self.interfaceMode == InterfaceMode.Practice {
            return // don't bother making a new timer, we were doing that (harmlessly) but why bother?
        }
        self.timer = NSTimer.scheduledTimerWithTimeInterval(10, target: self, selector: "decrementScore", userInfo: nil, repeats: true)
    }
    
    func decrementScore () {
        self.incrementScore(-1, resetTimer:false, red:true)
    }
    
    // very good use case for default param; no need for most callers even to know there's a choice
    func incrementScore (n:Int, resetTimer:Bool, red:Bool = false) {
        self.score += n
        self.scoreLabel.text = String(score)
        self.scoreLabel.textColor = red ? UIColor.redColor() : UIColor.blackColor()
        if resetTimer {
            self.resetTimer()
        }
    }
    
    // called when we resign active
    func screenOff () { // TODO: is this working as expected?
        // I see what the problem is: yes, I'm removing the board data...
        // but we exist in suspension so this does not affect us unless we are also terminated
        // let's leave it
        self.timer?.invalidate()
        self.timer = nil
        switch InterfaceMode.fromRaw(self.timedPractice.selectedSegmentIndex)! {
        case .Timed:
            ud.removeObjectForKey(Default.kBoardData)
        case .Practice: // practice, save out board state
            let boardData = NSKeyedArchiver.archivedDataWithRootObject(self.board)
            ud.setObject(boardData, forKey:Default.kBoardData)
        }
        // this stuff does no harm if no popovers...
        // and if there is one, it is dismissed
        // plus we restore prefs if needed
        self.dismissViewControllerAnimated(false, completion: nil)
        if self.oldDefs {
            println("counts as cancelled, restoring old prefs")
            ud.setValuesForKeysWithDictionary(self.oldDefs)
            self.oldDefs = nil
        }
    }
    
    // called when we resume active
    func screenOn () {
        self.resetTimer()
    }
    
    func clearViewAndCreatePathView () {
        // clear the view!
        for v in self.boardView.subviews as UIView[] {
            v.removeFromSuperview()
        }
        // board is now completely empty
        // place invisible view on top of it; this is where paths will be drawn
        // we will draw directly into its layer using layer delegate's drawLayer:inContext:
        // but we must not set a view's layer's delegate, so we create a sublayer
        let v = UIView(frame: self.boardView.bounds)
        v.tag = 999
        v.userInteractionEnabled = false // clicks just fall right thru
        let lay = CALayer()
        v.layer.addSublayer(lay)
        lay.frame = v.layer.bounds
        self.boardView.addSubview(v)
    }
    
    func displayStage () {
        // delay to give any other animations time to happen, add emphasis
        delay(1) {
            UIView.transitionWithView(self.stageLabel, duration: 0.4,
                options: UIViewAnimationOptions.TransitionFlipFromLeft,
                animations: {
                self.stageLabel.text =
                    "Stage \(self.board.stage + 1) " +
                    "of \(ud.integerForKey(Default.kLastStage) + 1)"
                }, completion: nil)
        }
    }
    
    func animateBoardReplacement (transition: BoardTransition) {
        self.boardView.userInteractionEnabled = false
        // about to animate, turn off interaction; will turn back on in delegate
        let t = CATransition()
        if transition == .Slide {
            t.type = kCATransitionMoveIn
            t.subtype = kCATransitionFromLeft
        }
        t.duration = 0.7
        t.beginTime = CACurrentMediaTime() + 0.4
        t.fillMode = kCAFillModeBackwards
        t.timingFunction = CAMediaTimingFunction(name:kCAMediaTimingFunctionLinear)
        t.delegate = self
        t.setValue("boardReplacement", forKey:"name")
        self.boardView.layer.addAnimation(t, forKey:nil)
    }
    
    override func animationDidStop(anim: CAAnimation!, finished flag: Bool) {
        if anim.valueForKey("name") as? NSString == "boardReplacement" {
            self.boardView.userInteractionEnabled = true // but really no need to test, should just do it
        }
    }
    
    // called at startup
    // called when user asks for a new game
    // called when user completes a stage
    func setUpInterface (n : AnyObject?) {
        // initialize time
        self.lastTime = NSDate.timeIntervalSinceReferenceDate()
        // remove existing timer; timing will start when user moves
        self.timer?.invalidate()
        self.timer = nil
        // determine layout dimensions
        let (w,h) = Sizes.boardSize(ud.stringForKey(Default.kSize)!)
        // determine which pieces to use
        let (start1,start2) = Styles.pieces(ud.stringForKey(Default.kStyle)!)
        // create deck of piece names
        var deck = String[]()
        for ct in 0..4 {
            for i in start1..start1+9 {
                deck += String(i)
            }
        }
        // determine which additional pieces to use, finish deck of piece names
        let howmany : Int = ((w * h) / 4) - 9
        for ct in 0..4 {
            for i in start2..start2+howmany {
                deck += String(i)
            }
        }
        for ct in 0..4 {
            deck.shuffle()
        }
        
        // create new board object and configure it
        self.board = Board(boardView:self.boardView)
        self.board.setGridSizeX(w, y: h)
        
        // stage (current stage arrived in notification, or nil if we are just starting)
        self.board.stage = 0 // default
        if let userInfo = (n as? NSNotification)?.userInfo {
            let stage = userInfo["stage"].integerValue
            if stage < ud.integerForKey(Default.kLastStage) {
                self.board.stage = stage + 1
                self.animateBoardReplacement(.Slide)
            }
            // but if we received a stage in notification and it's the last stage, game is over!
            else {
                // do score and notification stuff only if user is not just practicing
                if InterfaceMode.fromRaw(self.timedPractice.selectedSegmentIndex)! == .Timed {
                    let key = self.scoresKey()
                    var d = ud.dictionaryForKey(Default.kScores) as Dictionary<String,Integer>
                    let prev = d[key] as? Int
                    var newHigh = false
                    if !prev || prev < self.score {
                        newHigh = true
                        d[key] = self.score
                        ud.setObject(d, forKey:Default.kScores)
                    }
                    // notify user
                    let alert = UIAlertController(
                        title: "Congratulations!",
                        message: "You have finished the game with a score of \(self.score)." +
                            (newHigh ? " This is a new high score for this level!" : ""),
                        preferredStyle: .Alert)
                    alert.addAction(UIAlertAction(
                        title: "Cool!", style: .Cancel, handler: nil))
                    self.presentViewController(alert, animated: true, completion: nil)
                }
                self.initializeScores()
                self.interfaceMode = .Timed // every new game is a timed game
                self.animateBoardReplacement(.Fade)
            }
        }
        // continue to lay out new game / stage, even if alert just went up
        // stage label
        self.displayStage()
        // initialize empty board
        self.clearViewAndCreatePathView()
        // deal out the pieces and we're all set! Pieces themselves and Board object take over interactions from here
        for i in 0..w {
            for j in 0..h {
                self.board.addPieceAt((i,j), withPicture: deck.removeLast()) // heh heh, pops and returns
            }
        }
    }
    
    
    // ============================ toolbar buttons =================================
    
    @IBAction func doHint(_:AnyObject?) { // hintButton
        if !self.board.showingHint {
            self.hintButton.title = HintButtonTitle.Hide.toRaw()
            self.incrementScore(-10, resetTimer:true)
            self.board.hint()
            // if user taps board now, this should have just the same effect as tapping button
            // so, attach gesture rec
            let t = UITapGestureRecognizer(target: self, action: "doHint:")
            self.boardView.viewWithTag(999).addGestureRecognizer(t)
        } else {
            self.hintButton.title = HintButtonTitle.Show.toRaw()
            self.board.unilluminate()
            self.boardView.viewWithTag(999).gestureRecognizers = nil
        }
    }
    
    @IBAction func doShuffle(_:AnyObject?) {
        if self.board.showingHint {
            self.doHint(nil)
        }
        self.board.redeal()
        self.incrementScore(-20, resetTimer:true)
    }
    
    // === popovers ===
    
    /*
    So in iOS 8 Apple has tried to solve the popover problem at last!
    A popover is just a style of presented view controller. No need to retain a reference to it, therefore.
    Let's see...
*/
    
    @IBAction func doNew(sender:AnyObject?) {
        if self.board.showingHint {
            self.doHint(nil)
        }
        // create dialog from scratch (see NewGameController for rest of interface)
        let dlg = NewGameController()
        let b1 = UIBarButtonItem(barButtonSystemItem: .Cancel, target: self, action: "cancelNewGame:")
        dlg.navigationItem.rightBarButtonItem = b1
        let b2 = UIBarButtonItem(barButtonSystemItem: .Done, target: self, action: "saveNewGame:")
        dlg.navigationItem.leftBarButtonItem = b2
        let nav = UINavigationController(rootViewController: dlg)
        nav.modalPresentationStyle = .Popover // *
        self.presentViewController(nav, animated: true, completion: nil)
        // configure the popover _after_ presentation, even though, as Apple says, this may see counterintuitive
        // it isn't really there yet, so there is time
        // configuration is thru the implicitly created popover presentation controller
        let pop = nav.popoverPresentationController
        pop.permittedArrowDirections = .Any
        pop.barButtonItem = sender as UIBarButtonItem
        delay (0.01) { pop.passthroughViews = nil } // must be delayed to work
        pop.delegate = self // this is a whole new delegate protocol, of course
        // save defaults so we can restore them later if user cancels
        self.oldDefs = ud.dictionaryWithValuesForKeys([Default.kStyle, Default.kSize, Default.kLastStage])
    }
    
    func cancelNewGame(_:AnyObject?) { // cancel button in new game popover
        self.dismissViewControllerAnimated(true, completion: nil)
        if self.oldDefs {
            ud.setValuesForKeysWithDictionary(self.oldDefs)
            self.oldDefs = nil
        }
    }
    
    func saveNewGame(_:AnyObject?) { // save button in new game popover; can also be called manually at launch
        self.dismissViewControllerAnimated(true, completion: nil) // and if there is no presented vc, no problem
        self.setUpInterface(nil)
        self.initializeScores()
        self.interfaceMode = .Timed
        self.animateBoardReplacement(.Fade)
    }
    
    func popoverPresentationControllerShouldDismissPopover(pop: UIPopoverPresentationController!) -> Bool {
        // we can identify which popover it is because it is our presentedViewController
        if let vc = self.presentedViewController as? UINavigationController {
            if self.oldDefs {
                println("counts as cancelled, restoring old prefs")
                ud.setValuesForKeysWithDictionary(self.oldDefs)
                self.oldDefs = nil
            }
        }
        return true
    }
    
    
    @IBAction func doTimedPractice(_ : AnyObject?) {
        if self.board.showingHint {
            self.doHint(nil)
        }
        let ix = self.timedPractice.selectedSegmentIndex
        // 0 = timed; 1 = practice
        // in reality the user should never be able to switch to timed! it's just an indicator
        if ix == 1 {
            self.scoreLabel.hidden = true
            self.prevLabel.hidden = true
            self.timedPractice.enabled = false
        }
    }
    
    @IBAction func doHelp(sender : AnyObject?) {
        // create help from scratch
        let vc = UIViewController()
        let wv = UIWebView()
        let path = NSBundle.mainBundle().pathForResource("linkhelp", ofType: "html")
        let s = String.stringWithContentsOfFile(path, encoding:NSUTF8StringEncoding, error:nil)
        wv.loadHTMLString(s, baseURL: nil)
        vc.view = wv
        vc.modalPresentationStyle = .Popover
        vc.preferredContentSize = CGSizeMake(600,800) // NB! setting ppc's popoverContentSize didn't work
        self.presentViewController(vc, animated: true, completion: nil)
        let pop = vc.popoverPresentationController
        pop.permittedArrowDirections = .Any
        pop.barButtonItem = sender as UIBarButtonItem
        delay (0.01) { pop.passthroughViews = nil } // must be delayed to work
        // no delegate needed, as it turns out
    }
    
    // ================= notif from board =================
    
    // the board notifies us that the user removed a pair of pieces
    // track time between moves, award points (and remember, points mean prizes)

    func userMoved ( _ : AnyObject?) {
        let t = NSDate.timeIntervalSinceReferenceDate()
        let told = self.lastTime
        self.lastTime = t
        let diff = t - told
        var bonus = 0
        if diff < 10 {
            bonus = Int(ceil(10.0/diff))
        }
        self.incrementScore(1 + bonus, resetTimer:true)
    }
    
}
