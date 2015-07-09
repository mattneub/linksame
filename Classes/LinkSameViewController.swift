

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
    private static var easySize : (Int,Int) {
        var result : (Int,Int) = onPhone ? (10,6) : (12,7)
        if on6plus { result = (12,7) }
        return result
    }
    static func boardSize (s:String) -> (Int,Int) {
        let d = [
            Easy:self.easySize,
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
    private var scoreAtStartOfStage = 0
    private var lastTime : NSTimeInterval = 0
    private var didSetUp = false
    
    private var board : Board!
    @IBOutlet private weak var backgroundView : UIView!
    @IBOutlet private weak var stageLabel : UILabel!
    @IBOutlet private weak var scoreLabel : UILabel!
    @IBOutlet private weak var prevLabel : UILabel!
    @IBOutlet private weak var hintButton : UIBarButtonItem!
    @IBOutlet private weak var timedPractice : UISegmentedControl!
    @IBOutlet private weak var restartStageButton : UIBarButtonItem!
    @IBOutlet private weak var toolbar : UIToolbar!
    private var boardView : UIView!
    private var popover : UIPopoverController!
    private var oldDefs : [String : AnyObject]!
    private var timer : NSTimer! { // any time the timer is to be replaced, invalidate existing timer
        willSet {
            self.timer?.invalidate() // to stop timer, set it to nil, we invalidate
        }
    }
    
    override var nibName : String {
        get {
            return onPhone ? "LinkSameViewControllerPhone" : "LinkSameViewController"
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
            self.timedPractice?.selectedSegmentIndex = mode.rawValue
            self.timedPractice?.enabled = timed
            self.restartStageButton?.enabled = timed
        }
    }
    
    private struct HintButtonTitle {
        static let Show = "Show Hint"
        static let Hide = "Hide Hint"
    }
    
    private enum BoardTransition {
        case Slide
        case Fade
    }
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init(coder: NSCoder) {
        fatalError("NSCoding not supported")
    }
    
    private var scoresKey : String {
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
    
    override func viewDidLayoutSubviews() {
        if self.didSetUp {
            return
        }
        self.didSetUp = true
        ui(false)
        // increase font size on 6 plus
        if on6plus {
            for lab in [self.scoreLabel, self.prevLabel, self.stageLabel] {
                let f = lab.font
                lab.font = f.fontWithSize(f.pointSize + 2)
            }
        }
        // one-time launch initializations of model and interface
        self.initializeScores()
        // fix width of hint button to accomodate new labels Show Hint and Hide Hint
        self.hintButton?.possibleTitles =
            Set([HintButtonTitle.Show, HintButtonTitle.Hide])
        self.hintButton?.title = HintButtonTitle.Show
        // return; // uncomment for launch image screen shot
        // have we a state saved from prior practice? (non-practice game is not saved as board data!)
        // if so, reconstruct practice game from board data
        if let boardData = ud.objectForKey(Default.BoardData) as? NSData {
            self.board = NSKeyedUnarchiver.unarchiveObjectWithData(boardData) as! Board
            self.boardView = self.board.view
            self.backgroundView.addSubview(self.boardView)
            self.boardView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
            // set interface up as practice and we're all set
            self.interfaceMode = .Practice
            self.animateBoardTransition(.Fade)
        } else { // otherwise, create new game from scratch
            self.startNewGame()
        }
        ui(true)
        delay(2) { // delay to prevent didBecomeActive being called immediately
            // I have filed a bug on this; it's the same issue I had in 99 Bottles
            nc.addObserverForName("gameOver", object: nil, queue: nil) {
                n in
                self.prepareNewStage(n)
            }
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
                    self.toggleHint(nil)
                }
                // stop timer
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
                    self.timer = nil
                }
                // show the board view, just in case it was hidden on suspension
                self.boardView?.hidden = false
            }
            nc.addObserverForName(UIApplicationDidEnterBackgroundNotification, object: nil, queue: nil) {
                _ in
                // set up board data defaults
                // user cannot escape the timer by suspending the app; the game just ends if we background
                switch self.interfaceMode {
                case .Timed: // timed, make sure there is no saved board data
                    ud.removeObjectForKey(Default.BoardData)
                    // hide the game, stop the timer, kill the score; snapshot will capture blank background
                    self.boardView.hidden = true
                    self.initializeScores()
                    self.timer = nil
                case .Practice: // practice, save out board state
                    let boardData = NSKeyedArchiver.archivedDataWithRootObject(self.board)
                    ud.setObject(boardData, forKey:Default.BoardData)
                }
            }
            nc.addObserverForName(UIApplicationWillEnterForegroundNotification, object: nil, queue: nil) {
                // if there is no saved board, start the whole game over
                _ in
                if ud.objectForKey(Default.BoardData) == nil {
                    self.startNewGame()
                }
            }
        }
    }
    
    private func resetTimer() {
        self.timer = nil
        if self.interfaceMode == .Practice {
            return // don't bother making a new timer, we were doing that (harmlessly) but why bother?
        }
        self.timer = NSTimer.scheduledTimerWithTimeInterval(
            10, target: self, selector: "decrementScore", userInfo: nil, repeats: true
        )
        self.timer?.tolerance = 0.2
    }
    
    // called by timer
    @objc private func decrementScore () {
        self.incrementScore(-1, resetTimer:false, red:true)
    }
    
    // very good use case for default param; no need for most callers even to know there's a choice
    private func incrementScore (n:Int, resetTimer:Bool, red:Bool = false) {
        self.score += n
        self.scoreLabel.text = String(self.score)
        self.scoreLabel.textColor = red ? UIColor.redColor() : UIColor.blackColor()
        if resetTimer {
            self.resetTimer()
        }
    }
    
    private func animateBoardTransition (transition: BoardTransition) {
        ui(false)
        // about to animate, turn off interaction; will turn back on in delegate
        let t = CATransition()
        if transition == .Slide { // default is .Fade, fade in
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
    
    // delegate from previous, called when animation ends
    override func animationDidStop(anim: CAAnimation, finished flag: Bool) {
        if anim.valueForKey("name") as? NSString == "boardReplacement" {
            // set and animated showing of "stage" label
            UIView.transitionWithView(self.stageLabel, duration: 0.4,
                options: UIViewAnimationOptions.TransitionFlipFromLeft,
                animations: {
                    let s = "Stage \(self.board.stage + 1) " +
                    "of \(ud.integerForKey(Default.LastStage) + 1)"
                    self.stageLabel.text = s
                }, completion: {_ in ui(true) })
        }
    }
    
    // utility used only by next method: show board containing new deal
    // if new game, also set up scores and mode
    private func newBoard(newGame newGame:Bool) {
        
        let boardTransition : BoardTransition = newGame ? .Fade : .Slide
        if newGame {
            self.initializeScores()
            self.interfaceMode = .Timed // every new game is a timed game
        }
        board.createAndDealDeck()
        self.scoreAtStartOfStage = self.score // in case we have to restart this stage
        self.animateBoardTransition(boardTransition)
    }

    
    // called at startup
    // called when user asks for a new game
    // called via notification when user completes a stage
    @objc private func prepareNewStage (n : AnyObject?) {
        ui(false)
        // stop timer!
        // initialize time
        self.lastTime = NSDate.timeIntervalSinceReferenceDate()
        // remove existing timer; timing will start when user moves
        self.timer = nil
        
        // determine layout dimensions
        var (w,h) = Sizes.boardSize(ud.stringForKey(Default.Size)!)
        if onPhone {
            (w,h) = Sizes.boardSize(Sizes.Easy)
        }
        // create new board object and configure it
        self.board = Board(boardFrame:self.backgroundView.bounds, gridSize:(w,h))
        // put its `view` into the interface, replacing the one that may be there already
        self.boardView?.removeFromSuperview()
        self.boardView = self.board.view
        self.backgroundView.addSubview(self.boardView)
        self.boardView.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
        // stage (current stage arrived in notification, or nil if we are just starting)
        self.board.stage = 0 // default
        // self.board.stage = 8 // testing, comment out!
        
        // there are three possibilities:
        // * startup, or user asked for new game
        // * notification, on to next stage
        // * notification, game is over
        // in all three cases, we will deal out a new board and show it with a transition
        // the "game is over" actually subdivides into two cases: we were playing timed or playing practice
        
        if let stage = (n as? NSNotification)?.userInfo?["stage"] as? Int {
            if stage < ud.integerForKey(Default.LastStage) {
                // * notification, on to next stage
                self.board.stage = stage + 1
                self.newBoard(newGame:false)
            }
            else {
                // * notification, game is over
                // do score and notification stuff only if user is not just practicing
                if self.interfaceMode == .Timed {
                    let key = self.scoresKey
                    var newHigh = false
                    // get dict from defaults, or an empty dict
                    var scoresDict = [String:Int]()
                    if let d = ud.dictionaryForKey(Default.Scores) as? [String:Int] {
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
                            (newHigh ? " That is a new high score for this level!" : ""),
                        preferredStyle: .Alert)
                    alert.addAction(UIAlertAction(
                        title: "Cool!", style: .Cancel, handler:  {
                            _ in self.newBoard(newGame:true)
                    }))
                    self.presentViewController(alert, animated: true, completion:nil)
                } else {
                    // user was doing a practice game
                    self.newBoard(newGame:true)
                }
            }
        } else {
            // * startup, or user asked for new game
            self.newBoard(newGame:true)
        }
        ui(true)
    }
    
    
    // ============================ toolbar buttons =================================
    
    @IBAction private func toggleHint(_:AnyObject?) { // hintButton
        self.board.unhilite()
        if let v = self.board.pathView {
            if !self.board.showingHint {
                self.hintButton?.title = HintButtonTitle.Hide
                self.incrementScore(-10, resetTimer:true, red:true)
                self.board.hint()
                // if user taps board now, this should have just the same effect as tapping button
                // so, attach gesture rec
                let t = UITapGestureRecognizer(target: self, action: "toggleHint:")
                v.addGestureRecognizer(t)
            } else {
                self.hintButton?.title = HintButtonTitle.Show
                self.board.unilluminate()
                if let gs = v.gestureRecognizers {
                    for g in gs {
                        v.removeGestureRecognizer(g)
                    }
                }
            }
        }
    }
    
    @IBAction private func doShuffle(_:AnyObject?) {
        if self.board.showingHint {
            self.toggleHint(nil)
        }
        self.board.unhilite()
        self.board.redeal()
        self.incrementScore(-20, resetTimer:true, red:true)
    }
    
    @IBAction private func doRestartStage(_:AnyObject?) {
        if self.board.showingHint {
            self.toggleHint(nil)
        }
        self.board.unhilite()
        let alert = UIAlertController(title: "Restart Stage", message: "Really restart this stage?", preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: {
            _ in
            self.board.restartStage()
            self.score = self.scoreAtStartOfStage
            self.incrementScore(0, resetTimer: false) // cause new score to show
            self.timer = nil // stop timer and wait
            self.animateBoardTransition(.Fade)
        }))
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    
}

extension LinkSameViewController : UIPopoverPresentationControllerDelegate {
    
    // === popovers ===
    
    /*
    So in iOS 8 Apple has tried to solve the popover problem at last!
    A popover is just a style of presented view controller. No need to retain a reference to it, therefore.
    Let's see...
    */
    
    @IBAction private func doNew(sender:AnyObject?) {
        if self.board.showingHint {
            self.toggleHint(nil)
        }
        self.board.unhilite()
        // create dialog from scratch (see NewGameController for rest of interface)
        let dlg = NewGameController()
        dlg.modalInPopover = true // must be before presentation to work
        let b1 = UIBarButtonItem(barButtonSystemItem: .Cancel, target: self, action: "cancelNewGame")
        dlg.navigationItem.rightBarButtonItem = b1
        let b2 = UIBarButtonItem(barButtonSystemItem: .Done, target: self, action: "startNewGame")
        dlg.navigationItem.leftBarButtonItem = b2
        let nav = UINavigationController(rootViewController: dlg)
        nav.modalPresentationStyle = .Popover // *
        self.presentViewController(nav, animated: true, completion: nil)
        // configure the popover _after_ presentation, even though, as Apple says, this may see counterintuitive
        // it isn't really there yet, so there is time
        // configuration is thru the implicitly created popover presentation controller
        if let pop = nav.popoverPresentationController, sender = sender as? UIBarButtonItem {
            pop.permittedArrowDirections = .Any
            pop.barButtonItem = sender
            delay (0.01) { pop.passthroughViews = nil } // must be delayed to work
            pop.delegate = self // this is a whole new delegate protocol, of course
        }
        // save defaults so we can restore them later if user cancels
        self.oldDefs = ud.dictionaryWithValuesForKeys([Default.Style, Default.Size, Default.LastStage])
    }
    
    @objc private func cancelNewGame() { // cancel button in new game popover
        ui(false)
        self.dismissViewControllerAnimated(true, completion: {_ in ui(true)})
        if (self.oldDefs != nil) {
            ud.setValuesForKeysWithDictionary(self.oldDefs)
            self.oldDefs = nil
        }
    }
    
    @objc private func startNewGame() { // save button in new game popover; can also be called manually at launch
        func whatToDo() {
            self.initializeScores()
            self.interfaceMode = .Timed
            self.oldDefs = nil // crucial or we'll fall one behind
            self.prepareNewStage(nil)
        }
        if self.presentedViewController != nil {
            self.dismissViewControllerAnimated(true, completion: whatToDo)
        } else {
            whatToDo()
        }
    }
    
    // this should now never happen, because I've made this popover modal
    func popoverPresentationControllerShouldDismissPopover(pop: UIPopoverPresentationController) -> Bool {
        // we can identify which popover it is because it is our presentedViewController
        if pop.presentedViewController is UINavigationController {
            if (self.oldDefs != nil) {
                print("counts as cancelled, restoring old prefs")
                ud.setValuesForKeysWithDictionary(self.oldDefs)
                self.oldDefs = nil
            }
        }
        return true
    }
    
    @IBAction private func doTimedPractice(_ : AnyObject?) {
        if self.board.showingHint {
            self.toggleHint(nil)
        }
        self.board.unhilite()
        self.interfaceMode = InterfaceMode(rawValue:self.timedPractice.selectedSegmentIndex)!
        // and changing the interface mode changes the interface accordingly
    }
    
    @IBAction private func doHelp(sender : AnyObject?) {
        // create help from scratch
        let vc = UIViewController()
        let wv = UIWebView()
        let path = NSBundle.mainBundle().pathForResource("linkhelp", ofType: "html")!
        let s = try! String(contentsOfFile:path, encoding:NSUTF8StringEncoding)
        wv.loadHTMLString(s, baseURL: nil)
        vc.view = wv
        vc.modalPresentationStyle = .Popover
        vc.preferredContentSize = CGSizeMake(600,800) // NB! setting ppc's popoverContentSize didn't work
        if let pop = vc.popoverPresentationController {
            pop.delegate = self // adapt! on iPhone, we need a way to dismiss
        }
        self.presentViewController(vc, animated: true, completion: nil)
        if let pop = vc.popoverPresentationController {
            pop.permittedArrowDirections = .Any
            if let sender = sender as? UIBarButtonItem {
                pop.barButtonItem = sender
            }
            delay (0.01) { pop.passthroughViews = nil } // must be delayed to work
        }
    }
    
    func adaptivePresentationStyleForPresentationController(
        controller: UIPresentationController) -> UIModalPresentationStyle {
            return .FullScreen
    }
    func presentationController(controller: UIPresentationController,
        viewControllerForAdaptivePresentationStyle style:
        UIModalPresentationStyle) -> UIViewController? {
            let vc = controller.presentedViewController
            if vc.view is UIWebView {
                let nav = UINavigationController(rootViewController: vc)
                vc.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Done", style: .Plain, target: self, action: "dismissHelp:")
                return nav
            }
            return nil
    }
    
    @objc private func dismissHelp(_:AnyObject) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
}

extension LinkSameViewController : UIToolbarDelegate {
    func positionForBar(bar: UIBarPositioning) -> UIBarPosition {
        return .TopAttached
    }
}

extension LinkSameViewController { // hamburger button on phone
    @IBAction func doHamburgerButton (sender:AnyObject!) {
        if self.board.showingHint {
            self.toggleHint(nil)
        }
        self.board.unhilite()

        let action = UIAlertController(title: nil, message: nil, preferredStyle: .ActionSheet)
        action.addAction(UIAlertAction(title: "Game", style: .Default, handler: {
            _ in
            self.doNew(nil)
        }))
        action.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        action.addAction(UIAlertAction(title: "Hint", style: .Default, handler: {
            _ in
            self.toggleHint(nil)
        }))
        action.addAction(UIAlertAction(title: "Shuffle", style: .Default, handler: {
            _ in
            self.doShuffle(nil)
        }))
        action.addAction(UIAlertAction(title: "Restart Stage", style: .Default, handler: {
            _ in
            self.doRestartStage(nil)
        }))
        action.addAction(UIAlertAction(title: "Help", style: .Default, handler: {
            _ in
            self.doHelp(nil)
        }))
        self.presentViewController(action, animated: true, completion: nil)
    }
    

}



