

import UIKit

func delay(delay:Double, closure:()->()) {
    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            Int64(delay * Double(NSEC_PER_SEC))
        ),
        dispatch_get_main_queue(), closure)
}

let ud = NSUserDefaults.standardUserDefaults()

let nc = NSNotificationCenter.defaultCenter()

extension Array {
    mutating func shuffle () {
        for var i = self.count - 1; i != 0; i-- {
            let ix1 = i
            let ix2 = Int(arc4random_uniform(UInt32(i+1)))
            (self[ix1], self[ix2]) = (self[ix2], self[ix1])
        }
    }
}

struct Default {
    static let Size = "Size"
    static let Style = "Style"
    static let LastStage = "Stages"
    static let Scores = "Scores"
    static let BoardData = "boardData"
}

struct Sizes {
    static let Easy = "Easy"
    static let Normal = "Normal"
    static let Hard = "Hard"
    static func sizes () -> [String] {
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
    static func styles () -> [String] {
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



class LinkSameViewController : UIViewController {
    
    private var score = 0
    private var lastTime : NSTimeInterval = 0
    private var didSetUp = false
    
    var board : Board!
    @IBOutlet weak var boardView : UIView!
    @IBOutlet weak var stageLabel : UILabel!
    @IBOutlet weak var scoreLabel : UILabel!
    @IBOutlet weak var prevLabel : UILabel!
    @IBOutlet weak var hintButton : UIBarButtonItem!
    @IBOutlet weak var timedPractice : UISegmentedControl!
    @IBOutlet weak var toolbar : UIToolbar!
    private var popover : UIPopoverController!
    private var oldDefs : [NSObject : AnyObject]!
    private var timer : NSTimer!
    
    override var nibName : String {
        get {
            return "LinkSameViewController"
        }
    }
    
    private enum InterfaceMode : Int {
        case Timed = 0
        case Practice = 1
        // and these are also the indexes of the timedPractice segmented control, heh heh
    }
    
    private var interfaceMode : InterfaceMode = .Timed {
        willSet (mode) {
            let timed : Bool
            switch mode {
            case .Timed:
                timed = true
            case .Practice:
                timed = false
            }
            self.scoreLabel.hidden = !timed
            self.prevLabel.hidden = !timed
            self.timedPractice.selectedSegmentIndex = mode.rawValue
            self.timedPractice.enabled = timed
        }
    }
    
    private enum HintButtonTitle : String {
        case Show = "Show Hint"
        case Hide = "Hide Hint"
    }
    
    private enum BoardTransition {
        case Slide
        case Fade
    }
    
    override init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init(coder: NSCoder) {
        fatalError("NSCoding not supported")
    }
    
    var scoresKey : String {
        let size = ud.stringForKey(Default.Size)
        let stages = ud.integerForKey(Default.LastStage)
        let key = "\(size)\(stages)"
        return key
    }
    
    private func initializeScores () {
        // current score
        self.score = 0
        self.incrementScore(0, resetTimer:false)
        // prev score, look up in user defaults
        self.prevLabel.text = ""
        if let scoresDict = ud.dictionaryForKey(Default.Scores) as? [String:Int] {
            if let prev = scoresDict[self.scoresKey] {
                self.prevLabel.text = "High score: \(prev)"
            }
        }
    }
    
    override func viewWillLayoutSubviews() {
        if self.didSetUp {
            return
        }
        self.didSetUp = true
        // one-time launch initializations of model and interface
        self.initializeScores()
        // fix width of hint button to accomodate new labels Show Hint and Hide Hint
        self.hintButton.possibleTitles =
            Set([HintButtonTitle.Show.rawValue, HintButtonTitle.Hide.rawValue])
        self.hintButton.title = HintButtonTitle.Show.rawValue
        // return; // uncomment for launch image screen shot
        // have we a state saved from prior practice? (non-practice game is not saved as board data!)
        // if so, reconstruct practice game from board data
        if let boardData = ud.objectForKey(Default.BoardData) as? NSData {
            // set up our own view
            self.clearViewAndCreatePathView()
            self.board = NSKeyedUnarchiver.unarchiveObjectWithData(boardData) as! Board
            // but this board is not fully realized; it has no view pointer
            self.board.view = self.boardView
            self.board.rebuild() // cause pieces to be displayed
            // set interface up as practice and we're all set
            self.interfaceMode = .Practice
            self.displayStage()
        } else { // otherwise, create new game from scratch
            self.saveNewGame()
        }
        delay(2) { // delay to prevent didBecomeActive being called immediately
            // I have filed a bug on this; it's the same issue I had in 99 Bottles
            nc.addObserver(self, selector: "setUpInterface:", name: "gameOver", object: nil)
            nc.addObserverForName("userMoved", object: nil, queue: nil) {
                // the board notifies us that the user removed a pair of pieces
                // track time between moves, award points (and remember, points mean prizes)
                _ in
                let now = NSDate.timeIntervalSinceReferenceDate()
                let diff = now - self.lastTime
                self.lastTime = now
                var bonus = 0
                if diff < 10 {
                    bonus = Int(ceil(10.0/diff))
                }
                self.incrementScore(1 + bonus, resetTimer:true)
            }
            nc.addObserverForName(UIApplicationWillResignActiveNotification, object: nil, queue: nil) {
                _ in
                // remove hint
                if self.board.showingHint {
                    self.doHint(nil)
                }
                // stop timer
                self.timer?.invalidate()
                self.timer = nil
                // dismiss popover if any; counts as cancelling, so restore defaults if needed
                self.dismissViewControllerAnimated(false, completion: nil)
                if (self.oldDefs != nil) {
                    ud.setValuesForKeysWithDictionary(self.oldDefs)
                    self.oldDefs = nil
                }
            }
            nc.addObserverForName(UIApplicationDidBecomeActiveNotification, object: nil, queue: nil) {
                _ in
                // if we are coming back from mere deactivation, just restart the timer
                self.resetTimer()
                // but if we are coming back from suspension, and if we are in timed mode...
                // ... we have created a whole new game; in that case, don't start the timer
                if self.score == 0 {
                    self.timer?.invalidate()
                    self.timer = nil
                }
            }
            nc.addObserverForName(UIApplicationDidEnterBackgroundNotification, object: nil, queue: nil) {
                _ in
                // set up board data defaults
                // user cannot escape the timer by suspending the app; the game just ends if we background
                switch self.interfaceMode {
                case .Timed: // timed, make sure there is no saved board data
                    ud.removeObjectForKey(Default.BoardData)
                case .Practice: // practice, save out board state
                    let boardData = NSKeyedArchiver.archivedDataWithRootObject(self.board)
                    ud.setObject(boardData, forKey:Default.BoardData)
                }
            }
            nc.addObserverForName(UIApplicationWillEnterForegroundNotification, object: nil, queue: nil) {
                // if there is no saved board, start the whole game over
                _ in
                if ud.objectForKey(Default.BoardData) == nil {
                    self.saveNewGame()
                }
            }
        }
    }
    
    func resetTimer() {
        self.timer?.invalidate()
        if self.interfaceMode == .Practice {
            return // don't bother making a new timer, we were doing that (harmlessly) but why bother?
        }
        self.timer = NSTimer.scheduledTimerWithTimeInterval(10, target: self, selector: "decrementScore", userInfo: nil, repeats: true)
    }
    
    // called by timer
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
    
    private func clearViewAndCreatePathView () {
        // clear the view!
        for v in self.boardView.subviews as NSArray as! [UIView] {
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
                    let s = "Stage \(self.board.stage + 1) " +
                    "of \(ud.integerForKey(Default.LastStage) + 1)"
                    self.stageLabel.text = s
                }, completion: nil)
        }
    }
    
    private func animateBoardReplacement (transition: BoardTransition) {
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
    // called via notification when user completes a stage
    func setUpInterface (n : AnyObject?) {
        // initialize time
        self.lastTime = NSDate.timeIntervalSinceReferenceDate()
        // remove existing timer; timing will start when user moves
        self.timer?.invalidate()
        self.timer = nil
        // determine layout dimensions
        let (w,h) = Sizes.boardSize(ud.stringForKey(Default.Size)!)
        // determine which pieces to use
        let (start1,start2) = Styles.pieces(ud.stringForKey(Default.Style)!)
        // create deck of piece names
        var deck = [String]()
        for ct in 0..<4 {
            for i in start1..<start1+9 {
                deck += [String(i)]
            }
        }
        // determine which additional pieces to use, finish deck of piece names
        let howmany : Int = ((w * h) / 4) - 9
        for ct in 0..<4 {
            for i in start2..<start2+howmany {
                deck += [String(i)]
            }
        }
        for ct in 0..<4 {
            deck.shuffle()
        }
        
        // create new board object and configure it
        self.board = Board(boardView:self.boardView, gridSize:(w,h))
        
        // stage (current stage arrived in notification, or nil if we are just starting)
        self.board.stage = 0 // default
        // self.board.stage = 8 // testing, comment out!
        if let userInfo = (n as? NSNotification)?.userInfo {
            let stage = (userInfo["stage"] as! NSNumber).integerValue
            if stage < ud.integerForKey(Default.LastStage) {
                self.board.stage = stage + 1
                self.animateBoardReplacement(.Slide)
            }
                // but if we received a stage in notification and it's the last stage, game is over!
            else {
                // do score and notification stuff only if user is not just practicing
                // TODO: why not just if self.interfaceMode == .Timed? I seem not to have adopted enum all the way here
                if InterfaceMode(rawValue: self.timedPractice.selectedSegmentIndex)! == .Timed {
                    let key = self.scoresKey
                    var newHigh = false
                    // get dict from defaults, or an empty dict
                    var scoresDict = [String:Int]()
                    if var d = ud.dictionaryForKey(Default.Scores) as? [String:Int] {
                        scoresDict = d
                    }
                    // self.score is new high score if it is higher than corresponding previous dict entry...
                    // ...or if there was no corresponding previous dict entry
                    let prev = scoresDict[key]
                    if prev == nil || prev! < self.score {
                        newHigh = true
                        scoresDict[key] = self.score
                        ud.setObject(scoresDict, forKey:Default.Scores)
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
        for i in 0..<w {
            for j in 0..<h {
                self.board.addPieceAt((i,j), withPicture: deck.removeLast()) // heh heh, pops and returns
            }
        }
        printlnNOT(self.board.grid)
    }
    
    
    // ============================ toolbar buttons =================================
    
    @IBAction func doHint(_:AnyObject?) { // hintButton
        let v = self.boardView.viewWithTag(999)!
        if !self.board.showingHint {
            self.hintButton.title = HintButtonTitle.Hide.rawValue
            self.incrementScore(-10, resetTimer:true)
            self.board.hint()
            // if user taps board now, this should have just the same effect as tapping button
            // so, attach gesture rec
            let t = UITapGestureRecognizer(target: self, action: "doHint:")
            v.addGestureRecognizer(t)
        } else {
            self.hintButton.title = HintButtonTitle.Show.rawValue
            self.board.unilluminate()
            let gs = v.gestureRecognizers! as NSArray as! [UIGestureRecognizer]
            for g in gs {
                v.removeGestureRecognizer(g)
            }
        }
    }
    
    @IBAction func doShuffle(_:AnyObject?) {
        if self.board.showingHint {
            self.doHint(nil)
        }
        self.board.redeal()
        self.incrementScore(-20, resetTimer:true)
    }
    
    
    
}

extension LinkSameViewController : UIPopoverPresentationControllerDelegate {
    
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
        let b2 = UIBarButtonItem(barButtonSystemItem: .Done, target: self, action: "saveNewGame")
        dlg.navigationItem.leftBarButtonItem = b2
        let nav = UINavigationController(rootViewController: dlg)
        nav.modalPresentationStyle = .Popover // *
        self.presentViewController(nav, animated: true, completion: nil)
        // configure the popover _after_ presentation, even though, as Apple says, this may see counterintuitive
        // it isn't really there yet, so there is time
        // configuration is thru the implicitly created popover presentation controller
        if let pop = nav.popoverPresentationController {
            pop.permittedArrowDirections = .Any
            pop.barButtonItem = sender as! UIBarButtonItem
            delay (0.01) { pop.passthroughViews = nil } // must be delayed to work
            pop.delegate = self // this is a whole new delegate protocol, of course
        }
        // save defaults so we can restore them later if user cancels
        self.oldDefs = ud.dictionaryWithValuesForKeys([Default.Style, Default.Size, Default.LastStage])
    }
    
    func cancelNewGame(_:AnyObject?) { // cancel button in new game popover
        self.dismissViewControllerAnimated(true, completion: nil)
        if (self.oldDefs != nil) {
            ud.setValuesForKeysWithDictionary(self.oldDefs)
            self.oldDefs = nil
        }
    }
    
    func saveNewGame() { // save button in new game popover; can also be called manually at launch
        self.dismissViewControllerAnimated(true, completion: nil) // and if there is no presented vc, no problem
        self.setUpInterface(nil)
        self.initializeScores()
        self.interfaceMode = .Timed
        self.animateBoardReplacement(.Fade)
        self.oldDefs = nil // crucial or we'll fall one behind
    }
    
    func popoverPresentationControllerShouldDismissPopover(pop: UIPopoverPresentationController) -> Bool {
        // we can identify which popover it is because it is our presentedViewController
        if pop.presentedViewController is UINavigationController {
            if (self.oldDefs != nil) {
                printlnNOT("counts as cancelled, restoring old prefs")
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
        self.interfaceMode = InterfaceMode(rawValue:self.timedPractice.selectedSegmentIndex)!
//        let ix = self.timedPractice.selectedSegmentIndex
//        // 0 = timed; 1 = practice
//        // in reality the user should never be able to switch to timed! it's just an indicator
//        if ix == 1 {
//            self.scoreLabel.hidden = true
//            self.prevLabel.hidden = true
//            self.timedPractice.enabled = false
//        }
    }
    
    @IBAction func doHelp(sender : AnyObject?) {
        // create help from scratch
        let vc = UIViewController()
        let wv = UIWebView()
        let path = NSBundle.mainBundle().pathForResource("linkhelp", ofType: "html")!
        let s = String(contentsOfFile:path, encoding:NSUTF8StringEncoding, error:nil)
        wv.loadHTMLString(s, baseURL: nil)
        vc.view = wv
        vc.modalPresentationStyle = .Popover
        vc.preferredContentSize = CGSizeMake(600,800) // NB! setting ppc's popoverContentSize didn't work
        self.presentViewController(vc, animated: true, completion: nil)
        if let pop = vc.popoverPresentationController {
            pop.permittedArrowDirections = .Any
            pop.barButtonItem = sender as! UIBarButtonItem
            delay (0.01) { pop.passthroughViews = nil } // must be delayed to work
        }
        // no delegate needed, as it turns out
    }
    
}

extension LinkSameViewController : UIToolbarDelegate {
    func positionForBar(bar: UIBarPositioning) -> UIBarPosition {
        return .TopAttached
    }
}



