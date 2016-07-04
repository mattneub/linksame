

import UIKit

func delay(_ delay:Double, closure:()->()) {
    let when = DispatchTime.now() + delay
    DispatchQueue.main.after(when: when, execute: closure)
}

let ud = UserDefaults.standard()

let nc = NotificationCenter.default()

infix operator <<< {
associativity none
precedence 135
}

func <<<<Bound where Bound : Comparable, Bound.Stride : Integer>
    (minimum: Bound, maximum: Bound) ->
    CountableRange<Bound> {
        return (minimum..<maximum)
}

infix operator >>> {
associativity none
precedence 135
}

func >>><Bound where Bound : Comparable, Bound.Stride : Integer>
    (maximum: Bound, minimum: Bound) ->
    ReversedRandomAccessCollection<CountableRange<Bound>> {
        return (minimum..<maximum).reversed()
}

extension Array {
    mutating func shuffle () {
        // for var i = self.count - 1; i != 0; i-- {
        for i in self.count >>> 0 {
            let ix1 = i
            let ix2 = Int(arc4random_uniform(UInt32(i+1)))
            (self[ix1], self[ix2]) = (self[ix2], self[ix1])
        }
    }
}

struct Default {
    static let size = "Size"
    static let style = "Style"
    static let lastStage = "Stages"
    static let scores = "Scores"
    static let boardData = "boardData"
}

struct Sizes {
    static let easy = "Easy"
    static let normal = "Normal"
    static let hard = "Hard"
    static func sizes () -> [String] {
        return [easy, normal, hard]
    }
    private static var easySize : (Int,Int) {
        var result : (Int,Int) = onPhone ? (10,6) : (12,7)
        if on6plus { result = (12,7) }
        return result
    }
    static func boardSize (_ s:String) -> (Int,Int) {
        let d = [
            easy:self.easySize,
            normal:(14,8),
            hard:(16,9)
        ]
        return d[s]!
    }
}

struct Styles {
    static let animals = "Animals"
    static let snacks = "Snacks"
    static func styles () -> [String] {
        return [animals, snacks]
    }
    static func pieces (_ s:String) -> (Int,Int) {
        let d = [
            animals:(11,110),
            snacks:(21,210)
        ]
        return d[s]!
    }
}



class LinkSameViewController : UIViewController {
    
    private var score = 0
    private var scoreAtStartOfStage = 0
    private var lastTime : TimeInterval = 0
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
    private var timer : Timer! { // any time the timer is to be replaced, invalidate existing timer
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
        case timed = 0
        case practice = 1
        // and these are also the indexes of the timedPractice segmented control, heh heh
    }
    
    private var interfaceMode : InterfaceMode = .timed {
        willSet (mode) {
            let timed : Bool
            switch mode {
            case .timed:
                timed = true
            case .practice:
                timed = false
            }
            self.scoreLabel.isHidden = !timed
            self.prevLabel.isHidden = !timed
            self.timedPractice?.selectedSegmentIndex = mode.rawValue
            self.timedPractice?.isEnabled = timed
            self.restartStageButton?.isEnabled = timed
        }
    }
    
    private struct HintButtonTitle {
        static let Show = "Show Hint"
        static let Hide = "Hide Hint"
    }
    
    private enum BoardTransition {
        case slide
        case fade
    }
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init(coder: NSCoder) {
        fatalError("NSCoding not supported")
    }
    
    private var scoresKey : String {
        let size = ud.string(forKey: Default.size)
        let stages = ud.integer(forKey: Default.lastStage)
        let key = "\(size)\(stages)"
        return key
    }
    
    private func initializeScores () {
        // current score
        self.score = 0
        self.incrementScore(0, resetTimer:false)
        // prev score, look up in user defaults
        self.prevLabel.text = ""
        if let scoresDict = ud.dictionary(forKey: Default.scores) as? [String:Int] {
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
            for lab in [self.scoreLabel!, self.prevLabel!, self.stageLabel!] {
                let f = lab.font!
                lab.font = f.withSize(f.pointSize + 2)
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
        if let boardData = ud.object(forKey: Default.boardData) as? Data {
            self.board = NSKeyedUnarchiver.unarchiveObject(with: boardData) as! Board
            self.boardView = self.board.view
            self.backgroundView.addSubview(self.boardView)
            self.boardView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            // set interface up as practice and we're all set
            self.interfaceMode = .practice
            self.animateBoardTransition(.fade)
        } else { // otherwise, create new game from scratch
            self.startNewGame()
        }
        ui(true)
        delay(2) { // delay to prevent didBecomeActive being called immediately
            // I have filed a bug on this; it's the same issue I had in 99 Bottles
            nc.addObserver(forName: .gameOver, object: nil, queue: nil) {
                n in
                self.prepareNewStage(n)
            }
            nc.addObserver(forName: .userMoved, object: nil, queue: nil) {
                // the board notifies us that the user removed a pair of pieces
                // track time between moves, award points (and remember, points mean prizes)
                _ in
                let now = Date.timeIntervalSinceReferenceDate
                let diff = now - self.lastTime
                self.lastTime = now
                var bonus = 0
                if diff < 10 {
                    bonus = Int(ceil(10.0/diff))
                }
                self.incrementScore(1 + bonus, resetTimer:true)
            }
            nc.addObserver(forName: .UIApplicationWillResignActive, object: nil, queue: nil) {
                _ in
                // remove hint
                if self.board.showingHint {
                    self.toggleHint(nil)
                }
                // stop timer
                self.timer = nil
                // dismiss popover if any; counts as cancelling, so restore defaults if needed
                self.dismiss(animated: false, completion: nil)
                if (self.oldDefs != nil) {
                    ud.setValuesForKeys(self.oldDefs)
                    self.oldDefs = nil
                }
            }
            nc.addObserver(forName: .UIApplicationDidBecomeActive, object: nil, queue: nil) {
                _ in
                // if we are coming back from mere deactivation, just restart the timer
                self.resetTimer()
                // but if we are coming back from suspension, and if we are in timed mode...
                // ... we have created a whole new game; in that case, don't start the timer
                if self.score == 0 {
                    self.timer = nil
                }
                // show the board view, just in case it was hidden on suspension
                self.boardView?.isHidden = false
            }
            nc.addObserver(forName: .UIApplicationDidEnterBackground, object: nil, queue: nil) {
                _ in
                // set up board data defaults
                // user cannot escape the timer by suspending the app; the game just ends if we background
                switch self.interfaceMode {
                case .timed: // timed, make sure there is no saved board data
                    ud.removeObject(forKey: Default.boardData)
                    // hide the game, stop the timer, kill the score; snapshot will capture blank background
                    self.boardView.isHidden = true
                    self.initializeScores()
                    self.timer = nil
                case .practice: // practice, save out board state
                    let boardData = NSKeyedArchiver.archivedData(withRootObject: self.board)
                    ud.set(boardData, forKey:Default.boardData)
                }
            }
            nc.addObserver(forName: .UIApplicationWillEnterForeground, object: nil, queue: nil) {
                // if there is no saved board, start the whole game over
                _ in
                if ud.object(forKey: Default.boardData) == nil {
                    self.startNewGame()
                }
            }
        }
    }
    
    private func resetTimer() {
        self.timer = nil
        if self.interfaceMode == .practice {
            return // don't bother making a new timer, we were doing that (harmlessly) but why bother?
        }
        self.timer = Timer.scheduledTimer(
            timeInterval: 10, target: self, selector: #selector(decrementScore), userInfo: nil, repeats: true
        )
        self.timer?.tolerance = 0.2
    }
    
    // called by timer
    @objc private func decrementScore () {
        self.incrementScore(-1, resetTimer:false, red:true)
    }
    
    // very good use case for default param; no need for most callers even to know there's a choice
    private func incrementScore (_ n:Int, resetTimer:Bool, red:Bool = false) {
        self.score += n
        self.scoreLabel.text = String(self.score)
        self.scoreLabel.textColor = red ? UIColor.red() : UIColor.black()
        if resetTimer {
            self.resetTimer()
        }
    }
    
    private func animateBoardTransition (_ transition: BoardTransition) {
        ui(false)
        // about to animate, turn off interaction; will turn back on in delegate
        let t = CATransition()
        if transition == .slide { // default is .Fade, fade in
            t.type = kCATransitionMoveIn
            t.subtype = kCATransitionFromLeft
        }
        t.duration = 0.7
        t.beginTime = CACurrentMediaTime() + 0.4
        t.fillMode = kCAFillModeBackwards
        t.timingFunction = CAMediaTimingFunction(name:kCAMediaTimingFunctionLinear)
        t.delegate = self
        t.setValue("boardReplacement", forKey:"name")
        self.boardView.layer.add(t, forKey:nil)
    }
    
    // delegate from previous, called when animation ends
    override func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        if anim.value(forKey: "name") as? NSString == "boardReplacement" {
            // set and animated showing of "stage" label
            UIView.transition(with: self.stageLabel, duration: 0.4,
                options: .transitionFlipFromLeft,
                animations: {
                    let s = "Stage \(self.board.stage + 1) " +
                    "of \(ud.integer(forKey: Default.lastStage) + 1)"
                    self.stageLabel.text = s
                }, completion: {_ in ui(true) })
        }
    }
    
    // utility used only by next method: show board containing new deal
    // if new game, also set up scores and mode
    private func newBoard(newGame:Bool) {
        
        let boardTransition : BoardTransition = newGame ? .fade : .slide
        if newGame {
            self.initializeScores()
            self.interfaceMode = .timed // every new game is a timed game
        }
        board.createAndDealDeck()
        self.scoreAtStartOfStage = self.score // in case we have to restart this stage
        self.animateBoardTransition(boardTransition)
    }

    
    // called at startup
    // called when user asks for a new game
    // called via notification when user completes a stage
    @objc private func prepareNewStage (_ n : AnyObject?) {
        ui(false)
        // stop timer!
        // initialize time
        self.lastTime = Date.timeIntervalSinceReferenceDate
        // remove existing timer; timing will start when user moves
        self.timer = nil
        
        // determine layout dimensions
        var (w,h) = Sizes.boardSize(ud.string(forKey: Default.size)!)
        if onPhone {
            (w,h) = Sizes.boardSize(Sizes.easy)
        }
        // create new board object and configure it
        self.board = Board(boardFrame:self.backgroundView.bounds, gridSize:(w,h))
        // put its `view` into the interface, replacing the one that may be there already
        self.boardView?.removeFromSuperview()
        self.boardView = self.board.view
        self.backgroundView.addSubview(self.boardView)
        self.boardView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        // stage (current stage arrived in notification, or nil if we are just starting)
        self.board.stage = 0 // default
        // self.board.stage = 8 // testing, comment out!
        
        // there are three possibilities:
        // * startup, or user asked for new game
        // * notification, on to next stage
        // * notification, game is over
        // in all three cases, we will deal out a new board and show it with a transition
        // the "game is over" actually subdivides into two cases: we were playing timed or playing practice
        
        if let stage = (n as? Notification)?.userInfo?["stage"] as? Int {
            if stage < ud.integer(forKey: Default.lastStage) {
                // * notification, on to next stage
                self.board.stage = stage + 1
                self.newBoard(newGame:false)
            }
            else {
                // * notification, game is over
                // do score and notification stuff only if user is not just practicing
                if self.interfaceMode == .timed {
                    let key = self.scoresKey
                    var newHigh = false
                    // get dict from defaults, or an empty dict
                    var scoresDict = [String:Int]()
                    if let d = ud.dictionary(forKey: Default.scores) as? [String:Int] {
                        scoresDict = d
                    }
                    // self.score is new high score if it is higher than corresponding previous dict entry...
                    // ...or if there was no corresponding previous dict entry
                    let prev = scoresDict[key]
                    if prev == nil || prev! < self.score {
                        newHigh = true
                        scoresDict[key] = self.score
                        ud.set(scoresDict, forKey:Default.scores)
                    }
                    // notify user
                    let alert = UIAlertController(
                        title: "Congratulations!",
                        message: "You have finished the game with a score of \(self.score)." +
                            (newHigh ? " That is a new high score for this level!" : ""),
                        preferredStyle: .alert)
                    alert.addAction(UIAlertAction(
                        title: "Cool!", style: .cancel, handler:  {
                            _ in self.newBoard(newGame:true)
                    }))
                    self.present(alert, animated: true, completion:nil)
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
    
    @IBAction @objc private func toggleHint(_:AnyObject?) { // hintButton
        self.board.unhilite()
        if let v = self.board.pathView {
            if !self.board.showingHint {
                self.hintButton?.title = HintButtonTitle.Hide
                self.incrementScore(-10, resetTimer:true, red:true)
                self.board.hint()
                // if user taps board now, this should have just the same effect as tapping button
                // so, attach gesture rec
                let t = UITapGestureRecognizer(target: self, action: #selector(toggleHint))
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
        let alert = UIAlertController(title: "Restart Stage", message: "Really restart this stage?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: {
            _ in
            self.board.restartStage()
            self.score = self.scoreAtStartOfStage
            self.incrementScore(0, resetTimer: false) // cause new score to show
            self.timer = nil // stop timer and wait
            self.animateBoardTransition(.fade)
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    
}

extension LinkSameViewController : UIPopoverPresentationControllerDelegate {
    
    // === popovers ===
    
    /*
    So in iOS 8 Apple has tried to solve the popover problem at last!
    A popover is just a style of presented view controller. No need to retain a reference to it, therefore.
    Let's see...
    */
    
    @IBAction private func doNew(_ sender:AnyObject?) {
        if self.board.showingHint {
            self.toggleHint(nil)
        }
        self.board.unhilite()
        // create dialog from scratch (see NewGameController for rest of interface)
        let dlg = NewGameController()
        dlg.isModalInPopover = true // must be before presentation to work
        let b1 = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelNewGame))
        dlg.navigationItem.rightBarButtonItem = b1
        let b2 = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(startNewGame))
        dlg.navigationItem.leftBarButtonItem = b2
        let nav = UINavigationController(rootViewController: dlg)
        nav.modalPresentationStyle = .popover // *
        self.present(nav, animated: true, completion: nil)
        // configure the popover _after_ presentation, even though, as Apple says, this may see counterintuitive
        // it isn't really there yet, so there is time
        // configuration is thru the implicitly created popover presentation controller
        if let pop = nav.popoverPresentationController, sender = sender as? UIBarButtonItem {
            pop.permittedArrowDirections = .any
            pop.barButtonItem = sender
            delay (0.01) { pop.passthroughViews = nil } // must be delayed to work
            pop.delegate = self // this is a whole new delegate protocol, of course
        }
        // save defaults so we can restore them later if user cancels
        self.oldDefs = ud.dictionaryWithValues(forKeys: [Default.style, Default.size, Default.lastStage])
    }
    
    @objc private func cancelNewGame() { // cancel button in new game popover
        ui(false)
        self.dismiss(animated: true, completion: {_ in ui(true)})
        if (self.oldDefs != nil) {
            ud.setValuesForKeys(self.oldDefs)
            self.oldDefs = nil
        }
    }
    
    @objc private func startNewGame() { // save button in new game popover; can also be called manually at launch
        func whatToDo() {
            self.initializeScores()
            self.interfaceMode = .timed
            self.oldDefs = nil // crucial or we'll fall one behind
            self.prepareNewStage(nil)
        }
        if self.presentedViewController != nil {
            self.dismiss(animated: true, completion: whatToDo)
        } else {
            whatToDo()
        }
    }
    
    // this should now never happen, because I've made this popover modal
    func popoverPresentationControllerShouldDismissPopover(_ pop: UIPopoverPresentationController) -> Bool {
        // we can identify which popover it is because it is our presentedViewController
        if pop.presentedViewController is UINavigationController {
            if (self.oldDefs != nil) {
                print("counts as cancelled, restoring old prefs")
                ud.setValuesForKeys(self.oldDefs)
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
    
    @IBAction private func doHelp(_ sender : AnyObject?) {
        // create help from scratch
        let vc = UIViewController()
        let wv = UIWebView()
        wv.backgroundColor = UIColor.white() // new, fix background
        let path = Bundle.main().pathForResource("linkhelp", ofType: "html")!
        let s = try! String(contentsOfFile:path, encoding:.utf8)
        wv.loadHTMLString(s, baseURL: nil)
        vc.view = wv
        vc.modalPresentationStyle = .popover
        vc.preferredContentSize = CGSize(width: 450,height: 800) // NB! setting ppc's popoverContentSize didn't work
        if let pop = vc.popoverPresentationController {
            pop.delegate = self // adapt! on iPhone, we need a way to dismiss
        }
        self.present(vc, animated: true, completion: nil)
        if let pop = vc.popoverPresentationController {
            pop.permittedArrowDirections = .any
            if let sender = sender as? UIBarButtonItem {
                pop.barButtonItem = sender
            }
            pop.backgroundColor = UIColor.white() // new - fix arrow
            delay (0.01) { pop.passthroughViews = nil} // must be delayed to work
        }
    }
    
    func adaptivePresentationStyle(
        for controller: UIPresentationController) -> UIModalPresentationStyle {
            return .fullScreen
    }
    func presentationController(_ controller: UIPresentationController,
        viewControllerForAdaptivePresentationStyle style:
        UIModalPresentationStyle) -> UIViewController? {
            let vc = controller.presentedViewController
            if vc.view is UIWebView {
                let nav = UINavigationController(rootViewController: vc)
                vc.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(dismissHelp))
                return nav
            }
            return nil
    }
    
    @objc private func dismissHelp(_:AnyObject) {
        self.dismiss(animated: true, completion: nil)
    }
    
}

extension LinkSameViewController : UIToolbarDelegate {
    func position(for bar: UIBarPositioning) -> UIBarPosition {
        return .topAttached
    }
}

extension LinkSameViewController { // hamburger button on phone
    @IBAction func doHamburgerButton (_ sender:AnyObject!) {
        if self.board.showingHint {
            self.toggleHint(nil)
        }
        self.board.unhilite()

        let action = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        action.addAction(UIAlertAction(title: "Game", style: .default, handler: {
            _ in
            self.doNew(nil)
        }))
        action.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        action.addAction(UIAlertAction(title: "Hint", style: .default, handler: {
            _ in
            self.toggleHint(nil)
        }))
        action.addAction(UIAlertAction(title: "Shuffle", style: .default, handler: {
            _ in
            self.doShuffle(nil)
        }))
        action.addAction(UIAlertAction(title: "Restart Stage", style: .default, handler: {
            _ in
            self.doRestartStage(nil)
        }))
        action.addAction(UIAlertAction(title: "Help", style: .default, handler: {
            _ in
            self.doHelp(nil)
        }))
        self.present(action, animated: true, completion: nil)
    }
    

}



