

import UIKit
import Swift
import WebKit

class CancelableTimer: NSObject {
    private var q = DispatchQueue(label: "timer")
    private var timer : DispatchSourceTimer!
    private var firsttime = true
    private var once : Bool
    private var handler : () -> ()
    init(once:Bool, handler:@escaping ()->()) {
        self.once = once
        self.handler = handler
        super.init()
    }
    func start(interval:Double, leeway:Int) {
        self.firsttime = true
        self.cancel()
        self.timer = DispatchSource.makeTimerSource(queue: self.q)
        self.timer.schedule(wallDeadline: .now(), repeating: interval, leeway: .milliseconds(leeway))
        self.timer.setEventHandler {
            if self.firsttime {
                self.firsttime = false
                return
            }
            self.handler()
            if self.once {
                self.cancel()
            }
        }
        self.timer.resume()
    }
    func cancel() {
        self.timer?.cancel()
    }
    deinit {
        print("deinit cancelable timer")
    }
}


class LinkSameViewController : UIViewController, CAAnimationDelegate {
    
    
    fileprivate var board : Board?
    @IBOutlet fileprivate weak var backgroundView : UIView?
    @IBOutlet fileprivate weak var stageLabel : UILabel?
    @IBOutlet fileprivate weak var scoreLabel : UILabel?
    @IBOutlet fileprivate weak var prevLabel : UILabel?
    @IBOutlet fileprivate weak var hintButton : UIBarButtonItem?
    @IBOutlet fileprivate weak var timedPractice : UISegmentedControl?
    @IBOutlet fileprivate weak var restartStageButton : UIBarButtonItem?
    @IBOutlet fileprivate weak var toolbar : UIToolbar?
    fileprivate var boardView : UIView?
    fileprivate var oldDefs : [String : Any]?
    
    override var nibName : String {
        get {
            return onPhone ? "LinkSameViewControllerPhone" : "LinkSameViewController"
        }
    }
    
    fileprivate enum InterfaceMode : Int {
        case timed = 0
        case practice = 1
        // and these are also the indexes of the timedPractice segmented control, heh heh
    }
    
    // changing the interface mode changes our interace
    fileprivate var interfaceMode : InterfaceMode = .timed {
        willSet (mode) {
            let timed : Bool
            switch mode {
            case .timed:
                timed = true
            case .practice:
                timed = false
            }
            self.scoreLabel?.isHidden = !timed
            self.prevLabel?.isHidden = !timed
            self.timedPractice?.selectedSegmentIndex = mode.rawValue
            self.timedPractice?.isEnabled = timed
            self.restartStageButton?.isEnabled = timed
        }
    }
    
    fileprivate struct HintButtonTitle {
        static let Show = "Show Hint"
        static let Hide = "Hide Hint"
    }
    
    fileprivate enum BoardTransition {
        case slide
        case fade
    }
    
    fileprivate var stage : Stage?
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init(coder: NSCoder) {
        fatalError("NSCoding not supported")
    }
    
    fileprivate var scoresKey : String {
        let size = ud.string(forKey: Default.size)
        let stages = ud.integer(forKey: Default.lastStage)
        let key = "\(size!)\(stages)"
        return key
    }
    
    // bring together the score, the timer, and control over the score display part of the interface
    // the idea is to make a new Stage object every time a new timed stage begins...
    // ...and then communicate with it only in terms of game-related events
    
    final class Stage : NSObject {
        private(set) var score : Int
        let scoreAtStartOfStage : Int
        private var timer : CancelableTimer! // no timer initially (user has not moved yet)
        private var lastTime : Date = Date.distantPast
        private unowned let lsvc : LinkSameViewController
        init(lsvc:LinkSameViewController, score:Int = 0) { // initial score for this stage
            print("new game!")
            self.lsvc = lsvc
            self.score = score
            self.scoreAtStartOfStage = score // might need this if we restart this stage later
            super.init()
            self.lsvc.scoreLabel?.text = String(self.score)
            self.lsvc.scoreLabel?.textColor = .black
            self.lsvc.prevLabel?.text = ""
            if let scoresDict = ud.dictionary(forKey: Default.scores) as? [String:Int] {
                if let prev = scoresDict[self.lsvc.scoresKey] {
                    self.lsvc.prevLabel?.text = "High score: \(prev)"
                }
            }
            // application lifetime events affect our timer
            nc.addObserver(self, selector: #selector(resigningActive), name: UIApplication.willResignActiveNotification, object: nil)
            nc.addObserver(self, selector: #selector(becomingActive), name: UIApplication.didBecomeActiveNotification, object: nil)
            // long-distance communication from the board object
            nc.addObserver(self, selector: #selector(userMadeLegalMove), name: .userMoved, object: nil)
        }
        deinit {
            print("farewell from game")
            self.timer?.cancel()
            nc.removeObserver(self)
        }
        @objc private func resigningActive() { // notification
            self.timer?.cancel()
        }
        private func restartTimer() { // private utility
            // print("restartTimer")
            self.timer?.cancel()
            self.timer = CancelableTimer(once: false) { [unowned self] in
                DispatchQueue.main.async {
                    self.userFailedToMove()
                }
            }
            self.timer.start(interval: 10, leeway: 100)
        }
        @objc private func becomingActive() { // notification
            self.restartTimer()
        }
        func gameEnded() {
            self.timer?.cancel()
        }
        private func userFailedToMove() {
            self.score -= 1
            self.lsvc.scoreLabel?.text = String(self.score)
            self.lsvc.scoreLabel?.textColor = .red
        }
        func userAskedForHint() {
            self.restartTimer()
            self.score -= 10
            self.lsvc.scoreLabel?.text = String(self.score)
            self.lsvc.scoreLabel?.textColor = .red
        }
        func userAskedForShuffle() {
            self.restartTimer()
            self.score -= 20
            self.lsvc.scoreLabel?.text = String(self.score)
            self.lsvc.scoreLabel?.textColor = .red
        }
        @objc private func userMadeLegalMove() {
            self.restartTimer()
            // track time between moves, award points (and remember, points mean prizes)
            let now = Date()
            let diff = now.timeIntervalSinceReferenceDate - self.lastTime.timeIntervalSinceReferenceDate
            self.lastTime = now
            let bonus = (diff < 10) ? Int((10.0/diff).rounded(.up)) : 0
            self.score += 1 + bonus
            self.lsvc.scoreLabel?.text = String(self.score)
            self.lsvc.scoreLabel?.textColor = .black
        }
    }
    
    fileprivate var didSetUp = false
    override func viewDidLayoutSubviews() {
        guard !self.didSetUp else { return }
        self.didSetUp = true
        
        // prepare interface, including game setup if needed
        
        // increase font size on 6 plus
        if on6plus {
            for lab in [self.scoreLabel!, self.prevLabel!, self.stageLabel!] {
                let f = lab.font!
                lab.font = f.withSize(f.pointSize + 2)
            }
        }
        // fix width of hint button to accomodate new labels Show Hint and Hide Hint
        self.hintButton?.possibleTitles = [HintButtonTitle.Show, HintButtonTitle.Hide] // not working
        self.hintButton?.title = HintButtonTitle.Show
        self.hintButton?.width = 100 // forced to take a wild guess 
        // return; // uncomment for launch image screen shot
        // have we a state saved from prior practice? (non-practice game is not saved as board data!)
        // if so, reconstruct practice game from board data
        if let boardData = ud.object(forKey: Default.boardData) as? Data {
            self.board = NSKeyedUnarchiver.unarchiveObject(with: boardData) as! Board?
            self.boardView = self.board!.view
            self.backgroundView!.addSubview(self.boardView!)
            self.boardView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            // set interface up as practice and we're all set
            self.interfaceMode = .practice
            self.stage = nil // just in case
            self.animateBoardTransition(.fade)
        } else { // otherwise, create new game from scratch
            self.startNewGame()
        }
        
        // responses to game events and application lifetime events
        
        // sent long-distance by board
        nc.addObserver(forName: .gameOver, object: nil, queue: nil) { n in
            self.stage?.gameEnded()
            self.prepareNewStage(n)
        }
        nc.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: nil) { _ in
            // remove hint
            if self.board!.showingHint {
                self.toggleHint(nil)
            }
            // dismiss popover if any; counts as cancelling, so restore defaults if needed
            self.dismiss(animated: false)
            if let defs = self.oldDefs {
                ud.setValuesForKeys(defs)
                self.oldDefs = nil
            }
        }
        nc.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { _ in
            // user cannot escape the timer by suspending the app; the game just ends if we background
            self.stage = nil
            switch self.interfaceMode {
            case .timed:
                ud.removeObject(forKey: Default.boardData)
                self.boardView?.isHidden = true // so snapshot will capture blank background
            case .practice:
                // save out board state
                let boardData = NSKeyedArchiver.archivedData(withRootObject: self.board!)
                ud.set(boardData, forKey:Default.boardData)
            }
        }
        // a big problem with lifetime events is that they are not sufficient fine-grained
        // it makes a big difference whether we are activating from a mere deactivate...
        // ...or coming back from the background
        // to detect this, we have configured things in didEnterBackground
        nc.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { _ in
            // show the board view, just in case it was hidden on suspension
            self.boardView?.isHidden = false
            if self.stage == nil && ud.object(forKey: Default.boardData) == nil {
                self.startNewGame()
            }
        }

    }
    
    fileprivate func animateBoardTransition (_ transition: BoardTransition) {
        ui(false) // about to animate, turn off interaction; will turn back on in delegate
        let t = CATransition()
        if transition == .slide { // default is .Fade, fade in
            t.type = .moveIn
            t.subtype = .fromLeft
        }
        t.duration = 0.7
        t.beginTime = CACurrentMediaTime() + 0.4
        t.fillMode = .backwards
        t.timingFunction = CAMediaTimingFunction(name:.linear)
        t.delegate = self
        t.setValue("boardReplacement", forKey:"name")
        self.boardView?.layer.add(t, forKey:nil)
    }
    
    // delegate from previous, called when animation ends
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        if anim.value(forKey: "name") as? String == "boardReplacement" {
            // set "stage" label, animate the change
            let s = "Stage \(self.board!.stage + 1) " +
            "of \(ud.integer(forKey: Default.lastStage) + 1)"
            self.stageLabel?.text = s
            UIView.transition(with: self.stageLabel!, duration: 0.4,
                options: .transitionFlipFromLeft, animations: nil,
                completion: {_ in ui(true) })
        }
    }
    
    // called at startup
    // called when user asks for a new game
    // called via notification when user completes a stage
    @objc fileprivate func prepareNewStage (_ n : Any?) {
        ui(false)
        
        // determine layout dimensions
        var (w,h) = Sizes.boardSize(ud.string(forKey: Default.size)!)
        if onPhone {
            (w,h) = Sizes.boardSize(Sizes.easy)
        }
        // create new board object and configure it
        self.board = Board(boardFrame:self.backgroundView!.bounds, gridSize:(w,h))
        // put its `view` into the interface, replacing the one that may be there already
        self.boardView?.removeFromSuperview()
        self.boardView = self.board!.view
        self.backgroundView!.addSubview(self.boardView!)
        self.boardView!.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        // stage (current stage arrived in notification, or nil if we are just starting)
        self.board!.stage = 0 // default
        // self.board!.stage = 8 // testing, comment out!
        
        // there are three possibilities:
        // * startup, or user asked for new game
        // * notification, on to next stage
        // * notification, game is over
        // in all three cases, we will deal out a new board and show it with a transition
        // the "game is over" actually subdivides into two cases: we were playing timed or playing practice
        
        // no matter what, this is what we will do at the end:
        func newBoard(newGame:Bool) {
            if newGame {
                self.stage = Stage(lsvc: self)
                self.interfaceMode = .timed // every new game is a timed game
            } else {
                self.stage = Stage(lsvc: self, score: self.stage!.score) // score carries over
            }
            let boardTransition : BoardTransition = newGame ? .fade : .slide
            self.board!.createAndDealDeck()
            self.animateBoardTransition(boardTransition)
        }
        
        if let stage = (n as? Notification)?.userInfo?["stage"] as? Int {
            if stage < ud.integer(forKey: Default.lastStage) {
                // * notification, on to next stage
                self.board!.stage = stage + 1
                newBoard(newGame:false)
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
                    if prev == nil || prev! < self.stage!.score {
                        newHigh = true
                        scoresDict[key] = self.stage!.score
                        ud.set(scoresDict, forKey:Default.scores)
                    }
                    // notify user
                    let alert = UIAlertController(
                        title: "Congratulations!",
                        message: "You have finished the game with a score of \(self.stage!.score)." +
                            (newHigh ? " That is a new high score for this level!" : ""),
                        preferredStyle: .alert)
                    alert.addAction(UIAlertAction(
                        title: "Cool!", style: .cancel, handler:  { _ in
                            newBoard(newGame:true)
                    }))
                    self.present(alert, animated: true)
                } else {
                    // user was doing a practice game
                    newBoard(newGame:true)
                }
            }
        } else {
            // * startup, or user asked for new game
            newBoard(newGame:true)
        }
        ui(true)
    }
    
    
    // ============================ toolbar buttons =================================
    
    @IBAction @objc fileprivate func toggleHint(_:Any?) { // hintButton
        self.board!.unhilite()
        let v = self.board!.pathView
        if !self.board!.showingHint {
            self.hintButton?.title = HintButtonTitle.Hide
            self.stage?.userAskedForHint()
            self.board!.hint()
            // if user taps board now, this should have just the same effect as tapping button
            // so, attach gesture rec
            let t = UITapGestureRecognizer(target: self, action: #selector(toggleHint))
            v.addGestureRecognizer(t)
        } else {
            self.hintButton?.title = HintButtonTitle.Show
            self.board!.unhint()
            if let gs = v.gestureRecognizers {
                for g in gs {
                    v.removeGestureRecognizer(g)
                }
            }
        }
    }
    
    @IBAction fileprivate func doShuffle(_:Any?) {
        if self.board!.showingHint {
            self.toggleHint(nil)
        }
        self.stage?.userAskedForShuffle()
        self.board!.unhilite()
        self.board!.redeal()
    }
    
    @IBAction fileprivate func doRestartStage(_:Any?) {
        if self.board!.showingHint {
            self.toggleHint(nil)
        }
        self.board!.unhilite()
        let alert = UIAlertController(title: "Restart Stage", message: "Really restart this stage?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: {
            _ in
            self.board!.restartStage()
            self.stage = Stage(lsvc: self, score: self.stage!.scoreAtStartOfStage)
            self.animateBoardTransition(.fade)
        }))
        self.present(alert, animated: true)
    }
    
    
}

extension LinkSameViewController : UIPopoverPresentationControllerDelegate {
    
    func adaptivePresentationStyle(
        for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .fullScreen
    }
    
    func presentationController(_ controller: UIPresentationController,
                                viewControllerForAdaptivePresentationStyle style:
        UIModalPresentationStyle) -> UIViewController? {
        let vc = controller.presentedViewController
        if vc.view is WKWebView {
            let nav = UINavigationController(rootViewController: vc)
            vc.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(dismissHelp))
            return nav
        }
        return nil
    }
}

extension LinkSameViewController { // buttons in popover
    
    @IBAction fileprivate func doNew(_ sender:Any?) {
        if self.board!.showingHint {
            self.toggleHint(nil)
        }
        self.board!.unhilite()
        // create dialog from scratch (see NewGameController for rest of interface)
        let dlg = NewGameController()
        dlg.isModalInPopover = true // must be before presentation to work
        let b1 = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelNewGame))
        dlg.navigationItem.rightBarButtonItem = b1
        let b2 = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(startNewGame))
        dlg.navigationItem.leftBarButtonItem = b2
        let nav = UINavigationController(rootViewController: dlg)
        nav.modalPresentationStyle = .popover // *
        self.present(nav, animated: true)
        if let pop = nav.popoverPresentationController, let sender = sender as? UIBarButtonItem {
            pop.permittedArrowDirections = .any
            pop.barButtonItem = sender
            delay (0.01) { pop.passthroughViews = nil } // must be delayed to work
            pop.delegate = self
        }
        // save defaults so we can restore them later if user cancels
        self.oldDefs = ud.dictionaryWithValues(forKeys: [Default.style, Default.size, Default.lastStage])
    }
    
    @objc fileprivate func cancelNewGame() { // cancel button in new game popover
        ui(false)
        self.dismiss(animated: true, completion: {ui(true)})
        if let d = self.oldDefs {
            ud.setValuesForKeys(d)
            self.oldDefs = nil
        }
    }
    
    @objc fileprivate func startNewGame() { // save button in new game popover; can also be called manually at launch
        func whatToDo() {
            self.stage = Stage(lsvc: self)
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
    
    @IBAction fileprivate func doTimedPractice(_ : Any) {
        if self.board!.showingHint {
            self.toggleHint(nil)
        }
        self.board!.unhilite()
        self.interfaceMode = InterfaceMode(rawValue:self.timedPractice!.selectedSegmentIndex)!
        // and changing the interface mode changes the interface accordingly
        if self.interfaceMode == .practice {
            self.stage = nil
        }
    }
    
    @IBAction fileprivate func doHelp(_ sender: Any?) {
        // create help from scratch
        let vc = UIViewController()
        let wv = WKWebView()
        
        wv.backgroundColor = .white // new, fix background
        let path = Bundle.main.path(forResource: "linkhelp", ofType: "html")!
        var s = try! String.init(contentsOfFile: path)
        s = s.replacingOccurrences(of: "FIXME", with: (!onPhone || on6plus) ? "12" : "9") // fix text size issue
        wv.loadHTMLString(s, baseURL: nil)
        print(s)
        vc.view = wv
        vc.modalPresentationStyle = .popover
        vc.preferredContentSize = CGSize(width: 450, height: 800) // setting ppc's popoverContentSize failed
        if let pop = vc.popoverPresentationController {
            pop.delegate = self // adapt! on iPhone, we need a way to dismiss
        }
        self.present(vc, animated: true)
        if let pop = vc.popoverPresentationController {
            pop.permittedArrowDirections = .any
            if let sender = sender as? UIBarButtonItem {
                pop.barButtonItem = sender
            }
            pop.backgroundColor = UIColor.white // new - fix arrow
            delay (0.01) { pop.passthroughViews = nil} // must be delayed to work
        }
    }
    
    @objc fileprivate func dismissHelp(_:Any) {
        self.dismiss(animated: true)
    }
    
}

extension LinkSameViewController : UIToolbarDelegate {
    func position(for bar: UIBarPositioning) -> UIBarPosition {
        return .topAttached
    }
}

extension LinkSameViewController { // hamburger button on phone
    @IBAction func doHamburgerButton (_ : Any) {
        if self.board!.showingHint {
            self.toggleHint(nil)
        }
        self.board!.unhilite()

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
        self.present(action, animated: true)
    }
    

}



