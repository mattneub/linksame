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
    var transp : UIView!
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
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    func positionForBar(bar: UIBarPositioning!) -> UIBarPosition {
        return .TopAttached
    }
    
    func setInterfaceMode (timed:Bool) {
        self.scoreLabel.hidden = !timed
        self.prevLabel.hidden = !timed
        self.timedPractice.selectedSegmentIndex = timed ? 0 : 1
        self.timedPractice.enabled = timed
        // uncomment for launch image screen shot
        //    self.scoreLabel.hidden = true
        //    self.prevLabel.hidden = true
        //    self.stageLabel.hidden = true
    }
    
    func initializeScores () {
        // current score
        self.score = 0
        self.incrementScore(0)
        // previous line created timer, kill it
        self.timer?.invalidate()
        // prev score, look up in user defaults
        self.prevLabel.text = ""
        let size = ud.stringForKey("Size")
        let stages = ud.integerForKey("Stages")
        let prev : Int? = ud.dictionaryForKey("Scores")["\(size)\(stages)"] as? Int
        if prev {
            self.prevLabel.text = "High score: \(prev)"
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.toolbar.delegate = self
        self.initializeScores()
        // fix width of hint button to accomodate new labels Show Hint and Hide Hint
        self.hintButton.possibleTitles = NSSet(objects: "Show Hint", "Hide Hint")
        self.hintButton.title = "Show Hint"
        // must wait until rotation has settled down before finishing interface, otherwise dimensions are wrong
        // have we a state saved from prior practice?
        // return; // uncomment for launch image screen shot
        let boardData : AnyObject! = ud.objectForKey("boardData")
        if boardData {
            delay(0.1) {self.reconstructInterface()}
        } else {
            delay(0.1) {self.saveNewGame(nil)}
        }
    }
    
    // setting up observers in viewDidLoad was always wrong
    override func viewDidAppear(animated: Bool) {
        if self.didSetUpObservers {
            return
        }
        self.didSetUpObservers = true
        delay(2) { // but we still need a delay to prevent didBecomeActive being called immediately
            // I have filed a bug on this; it's the same issue I had in 99 Bottles
            nc.addObserver(self, selector: "setUpInterface:", name: "gameOver", object: nil)
            nc.addObserver(self, selector: "userMoved:", name: "userMoved", object: nil)
            nc.addObserver(self, selector: "screenOff:", name: UIApplicationWillResignActiveNotification, object: nil)
            nc.addObserver(self, selector: "screenOff:", name: UIApplicationWillTerminateNotification, object: nil)
            nc.addObserver(self, selector: "screenOn:", name: UIApplicationDidBecomeActiveNotification, object: nil)
        }
    }
    
    func replaceTimer() {
        self.timer?.invalidate()
        self.timer = NSTimer.scheduledTimerWithTimeInterval(10, target: self, selector: "decrementScore:", userInfo: nil, repeats: true)
    }
    
    func incrementScore (n:Int) {
        self.score += n
        self.scoreLabel.text = String(score)
        self.scoreLabel.textColor = UIColor.blackColor()
        self.replaceTimer()
    }
    
    func decrementScore (_:AnyObject) {
        self.score -= 1
        self.scoreLabel.text = String(score)
        self.scoreLabel.textColor = UIColor.redColor()
    }
    
    func screenOff (_:AnyObject) { // TODO: is this working as expected?
        // I see what the problem is: yes, I'm removing the board data...
        // but we exist in suspension so this does not affect us unless we are also terminated
        // let's leave it
        self.timer?.invalidate()
        switch self.timedPractice.selectedSegmentIndex {
        case 1: // practice, save out board state
            let boardData = NSKeyedArchiver.archivedDataWithRootObject(self.board)
            ud.setObject(boardData, forKey:"boardData")
        default: // make sure board state is not saved
            ud.removeObjectForKey("boardData")
        }
    }
    
    func screenOn (_:AnyObject) {
        self.replaceTimer()
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
        self.transp = v
        self.boardView.addSubview(v)
        let lay = CALayer()
        self.transp.layer.addSublayer(lay)
        lay.frame = self.transp.layer.bounds
    }
    
    func displayStage () {
        // delay to give any other animations time to happen, add emphasis
        delay(1) {
            let stages = "Stages"
            UIView.transitionWithView(self.stageLabel, duration: 0.4, options: UIViewAnimationOptions.TransitionFlipFromLeft, animations: {
                self.stageLabel.text = "Stage \(self.board.stage.integerValue + 1) of \(ud.integerForKey(stages) + 1)"
                }, completion: nil)
        }
    }
    
    func animateBoardReplacement (slide: Bool) {
        self.boardView.userInteractionEnabled = false // about to animate, turn off interaction; will turn back on in delegate
        let t = CATransition()
        if slide {
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
        // initialize tim
        self.lastTime = NSDate.timeIntervalSinceReferenceDate()
        // remove existing timer; timing will start when user moves
        self.timer?.invalidate()
        self.timer = nil
        // determine layout dimensions
        var w : Int, h : Int
        switch ud.stringForKey("Size")! {
        case "Normal":
            (w,h) = (14,8)
        case "Hard":
            (w,h) = (16,9)
        default: // "Easy"
            (w,h) = (12,7)
        }
        // determine which pieces to use
        var start1 : Int, start2 : Int
        switch ud.stringForKey("Style")! {
        case "Snacks":
            (start1, start2) = (21,210)
        default: // "Animals"
            (start1, start2) = (11,110)
        }
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
        self.board.stage = 0
        if let userInfo = (n as? NSNotification)?.userInfo {
            let stage = userInfo["stage"].integerValue
            if stage < ud.integerForKey("Stages") {
                self.board.stage = stage + 1
                self.animateBoardReplacement(true)
            }
            // but if we received a stage in notification and it's the last stage, game is over!
            else {
                // do score and notification stuff only if user is not just practicing
                if self.timedPractice.selectedSegmentIndex == 0 {
                    let size = ud.stringForKey("Size")
                    let stages = ud.integerForKey("Stages")
                    let key = "\(size)\(stages)"
                    var d = ud.dictionaryForKey("Scores") as Dictionary<String,Integer>
                    let prev = d[key] as? Int
                    var newHigh = false
                    if !prev || prev < self.score {
                        newHigh = true
                        d[key] = self.score
                        ud.setObject(d, forKey:"Scores")
                    }
                    // notify user
                    let alert = UIAlertController(title: "Congratulations!", message: "You have finished the game with a score of \(self.score)." + (newHigh ? " This is a new high score for this level!" : ""), preferredStyle: .Alert)
                    alert.addAction(UIAlertAction(title: "Cool!", style: .Cancel, handler: nil))
                    self.presentViewController(alert, animated: true, completion: nil)
                }
                self.initializeScores()
                self.setInterfaceMode(true) // every new game is a timed game
                self.timer?.invalidate() // previous line starts timer, stop it
                self.animateBoardReplacement(false)
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
                self.board.addPieceAtX(i, y: j, withPicture: deck.removeLast()) // heh heh, pops and returns
            }
        }
    }
    
    func reconstructInterface() {
        // set up our own view
        self.clearViewAndCreatePathView()
        // fetch stored board
        let boardData = ud.objectForKey("boardData") as NSData
        self.board = NSKeyedUnarchiver.unarchiveObjectWithData(boardData) as Board
        // but this board is not fully realized; it has no view pointer
        self.board.view = self.boardView
        // another problem is that the board's reconstructed pieces are not actually showing
        // but the board itself will fix that if we ask it to rebuild itself
        self.board.rebuild()
        // set interface up as practice and we're all set
        self.setInterfaceMode(false)
        self.displayStage()
    }
    
    // ============================ toolbar buttons =================================
    
    @IBAction func doHint(_:AnyObject?) { // hintButton
        if !self.board.showingHint {
            self.hintButton.title = "Hide Hint"
            self.incrementScore(-10)
            self.board.hint()
            // if user taps board now, this should have just the same effect as tapping button
            // so, attach gesture rec
            let t = UITapGestureRecognizer(target: self, action: "doHint:")
            self.boardView.viewWithTag(999).addGestureRecognizer(t)
        } else {
            self.hintButton.title = "Show Hint"
            self.board.unilluminate()
            self.boardView.viewWithTag(999).gestureRecognizers = nil
        }
    }
    
    @IBAction func doShuffle(_:AnyObject?) {
        if self.board.showingHint {
            self.doHint(nil)
        }
        self.board.redeal()
        self.incrementScore(-20)
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
        pop.passthroughViews = nil // probably unnecessary, I think this is now the default, but need to test
        pop.delegate = self // this is a whole new delegate protocol, of course
        // save defaults so we can restore them later if user cancels
        self.oldDefs = ud.dictionaryWithValuesForKeys(["Style", "Size", "Stages"])
    }
    
    func cancelNewGame(_:AnyObject?) { // cancel button in new game popover
        self.dismissViewControllerAnimated(true, completion: nil)
        ud.setValuesForKeysWithDictionary(self.oldDefs)
    }
    
    func saveNewGame(_:AnyObject?) { // save button in new game popover
        self.dismissViewControllerAnimated(true, completion: nil)
        self.setUpInterface(nil)
        self.initializeScores()
        self.setInterfaceMode(true)
        self.timer?.invalidate() // prev line starts timer, stop it
        self.animateBoardReplacement(false)
    }
    
    // TODO: I have not solved the problem of how to restore oldDefs if user dismissed popover by tapping outside it
    
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
        println(path)
        let s = String.stringWithContentsOfFile(path, encoding:NSUTF8StringEncoding, error:nil)
        println(s)
        wv.loadHTMLString(s, baseURL: nil)
        vc.view = wv
        vc.modalPresentationStyle = .Popover
        vc.preferredContentSize = CGSizeMake(600,800) // NB! setting ppc's popoverContentSize didn't work
        self.presentViewController(vc, animated: true, completion: nil)
        let ppc = vc.popoverPresentationController
        ppc.permittedArrowDirections = .Any
        ppc.barButtonItem = sender as UIBarButtonItem
        ppc.passthroughViews = nil

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
        self.incrementScore(1 + bonus)
    }
    
}
