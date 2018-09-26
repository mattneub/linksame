

import UIKit
import Swift
import WebKit

private final class CancelableTimer: NSObject {
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

// ------ score-calculation utilities ------

// not used here, but good for output
// https://stackoverflow.com/a/45174913/341994
func myround(_ num: Double, to places: Int) -> Double {
    let p = log10(abs(num))
    let f = pow(10, p.rounded() - Double(places) + 1)
    let rnum = (num / f).rounded() * f
    return rnum
}
// how I ran the test in Playground to see what the curve is
func test() {
    for d in stride(from: 11, to: 0.1, by: -0.1) {
        let f = NumberFormatter()
        f.minimumFractionDigits = 1
        let s = f.string(from: myround(d, to: 3) as NSNumber)!
        print(s, calcBonus(d))
    }
}
// https://math.stackexchange.com/a/377174
// Quote: If you have numbers x in the range [a,b] and you want to transform them
// to numbers y in the range [c,d], you need to do this:
// y = (x-a)*(d-c)/(b-a)+c
func transform(x:Double, r1lo a:Double, r1hi b:Double, r2lo c:Double, d2hi d:Double) -> Double {
    return (x-a)*(d-c)/(b-a)+c
}
// ok, this is it! arrived at experimentally
// I like the curve and I like the values attainable (i.e. you can pretty easily get 10 but not _too_ easily)
func calcBonus(_ diff:Double) -> Int {
    // https://stackoverflow.com/a/30203599/341994
    func getNthRoot(_ x:Double, r:Double = 2.5) -> Double {
        return pow(x, 1.0/r)
    }
    let bonus = (diff >= 10) ? 0 : 15-1.5*transform(
        x: diff.squareRoot(), r1lo: 0, r1hi: (10.0).squareRoot(), r2lo: 0, d2hi: 10)
    // other attempts, just the opposite, I hated them
    // let bonus = (diff < 10) ? Int((10.0/diff).rounded(.up)) : 0
    // let bonus = (diff < 10) ? Int((100.0/(diff*diff)).rounded(.up)) : 0
    // and this is how I was doing it all these years
    // let bonus = (diff < 10) ? Int((10.0/diff).rounded(.up)) : 0
    return Int(bonus)
}

// bring together the score, the timer, and control over the score display part of the interface
// the idea is to make a new Stage object every time a new timed stage begins...
// ...and then communicate with it only in terms of game-related events

// Stage object always has a LinkSameViewController object
// it is permitted to see and change its scoreLabel and prevLabel, and can see its scoresKey
// in other words it is a kind of subcontroller for maintenance and display of the score

private final class Stage : NSObject {
    private(set) var score : Int
    let scoreAtStartOfStage : Int
    private var timer : CancelableTimer? // no timer initially (user has not moved yet)
    private var lastTime : Date = Date.distantPast
    private unowned let lsvc : LinkSameViewController
    init(lsvc:LinkSameViewController, score:Int = 0) { // initial score for this stage
        self.lsvc = lsvc
        self.score = score
        self.scoreAtStartOfStage = score // might need this if we restart this stage later
        super.init()
        print("new Stage object!", self)

        self.lsvc.scoreLabel?.text = String(self.score)
        self.lsvc.scoreLabel?.textColor = .black
        if let scoresDict = ud.dictionary(forKey: Default.scores) as? [String:Int],
            let prev = scoresDict[self.lsvc.scoresKey] {
            self.lsvc.prevLabel?.text = "High score: \(prev)"
        } else {
            self.lsvc.prevLabel?.text = ""
        }
        
        // application lifetime events affect our timer
        nc.addObserver(self, selector: #selector(resigningActive),
                       name: UIApplication.willResignActiveNotification, object: nil)
        // long-distance communication from the board object
        nc.addObserver(self, selector: #selector(userMadeLegalMove),
                       name: Board.userMoved, object: nil)
        nc.addObserver(self, selector: #selector(gameEnded),
                       name: Board.gameOver, object: nil)
    }
    deinit {
        print("farewell from Stage object", self)
        self.timer?.cancel()
        nc.removeObserver(self) // probably not needed, but whatever
    }
    // okay, you're never going to believe this one
    // I finally saw how to register for become active without triggering on the first one:
    // register in the first resign active! what a dummy I am not to have realized this
    private var didResign = false
    @objc private func resigningActive() { // notification
        self.timer?.cancel()
        if !self.didResign {
            self.didResign = true
            nc.addObserver(self, selector: #selector(becomingActive),
                           name: UIApplication.didBecomeActiveNotification, object: nil)
        }
    }
    private func restartTimer() { // private utility: start counting down from 10
        print("restartTimer")
        self.timer?.cancel()
        self.timer = CancelableTimer(once: false) { [unowned self] in
            DispatchQueue.main.async {
                // timed out! user failed to move, adjust score, interface
                // this is our main job!
                self.score -= 1
                self.lsvc.scoreLabel?.text = String(self.score)
                self.lsvc.scoreLabel?.textColor = .red
            }
        }
        self.timer!.start(interval: 10, leeway: 100)
    }
    @objc private func becomingActive() { // notification
        self.restartTimer()
    }
    @objc private func gameEnded() { // notification from Board
        self.timer?.cancel()
    }
    func userAskedForHint() { // called by LinkSameViewController
        self.restartTimer()
        self.score -= 10
        self.lsvc.scoreLabel?.text = String(self.score)
        self.lsvc.scoreLabel?.textColor = .red
    }
    func userAskedForShuffle() { // called by LinkSameViewController
        self.restartTimer()
        self.score -= 20
        self.lsvc.scoreLabel?.text = String(self.score)
        self.lsvc.scoreLabel?.textColor = .red
    }
    @objc private func userMadeLegalMove() { // notification from Board
        self.restartTimer()
        // calculate time between moves, award points (and remember, points mean prizes)
        let now = Date()
        let diff = now.timeIntervalSinceReferenceDate - self.lastTime.timeIntervalSinceReferenceDate
        self.lastTime = now
        // THIS IS A MAJOR CHANGE, whole new way of calculating the score
        // therefore I have invalidated past scores
        // let bonus = (diff < 10) ? Int((10.0/diff).rounded(.up)) : 0
        let bonus = calcBonus(diff)
        print("diff", diff)
        print("bonus", bonus)
        self.score += 1 + bonus
        self.lsvc.scoreLabel?.text = String(self.score)
        self.lsvc.scoreLabel?.textColor = .black
    }
}

private struct State : Codable {
    let board : Board
    let score : Int
    let timed : Bool
}

final class LinkSameViewController : UIViewController, CAAnimationDelegate {
    
    private var board : Board!
    @IBOutlet private weak var backgroundView : UIView!
    @IBOutlet private weak var stageLabel : UILabel!
    @IBOutlet fileprivate weak var scoreLabel : UILabel! // fileprivate so Stage can see it
    @IBOutlet fileprivate weak var prevLabel : UILabel! // fileprivate so State can see it
    @IBOutlet private weak var hintButton : UIBarButtonItem!
    @IBOutlet private weak var timedPractice : UISegmentedControl!
    @IBOutlet private weak var restartStageButton : UIBarButtonItem!
    @IBOutlet private weak var toolbar : UIToolbar!
    private var boardView : UIView!
    private var oldDefs : [String : Any]?
    
    override var nibName : String {
        get {
            return onPhone ? "LinkSameViewControllerPhone" : "LinkSameViewController"
        }
    }
    
    private enum InterfaceMode : Int {
        case timed = 0
        case practice = 1
        // these are also the indexes of the timedPractice segmented control, heh heh
    }
    
    // changing the interface mode changes our interface
    private var interfaceMode : InterfaceMode = .timed {
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
    
    private struct HintButtonTitle {
        static let show = "Show Hint"
        static let hide = "Hide Hint"
    }
    
    private enum BoardTransition {
        case slide
        case fade
    }
    
    private var stage : Stage?
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init(coder: NSCoder) {
        fatalError("NSCoding not supported")
    }
    
    fileprivate var scoresKey : String { // fileprivate so Stage can see it
        let size = ud.string(forKey: Default.size)
        let stages = ud.integer(forKey: Default.lastStage)
        let key = "\(size!)\(stages)"
        return key
    }
    
    private var betweenStages = false {
        didSet {
            if oldValue != self.betweenStages {
                print("between stages?", self.betweenStages)
            }
        }
    }
    private var didSetUpInitialLayout = false
    private var didObserveActivate = false
    private var comingBackFromBackground = false
    override func viewDidLayoutSubviews() {
        guard !self.didSetUpInitialLayout else { return }
        self.didSetUpInitialLayout = true
        
        // prepare interface, including game setup if needed
        
        // increase font size on triple-resolution screen
        if on3xScreen {
            for lab in [self.scoreLabel!, self.prevLabel!, self.stageLabel!] {
                let f = lab.font!
                lab.font = f.withSize(f.pointSize + 2)
            }
        }
        
        // fix width of hint button to accomodate new labels Show Hint and Hide Hint
        self.hintButton?.possibleTitles = [HintButtonTitle.show, HintButtonTitle.hide] // not working
        self.hintButton?.title = HintButtonTitle.show
        self.hintButton?.width = 100 // forced to take a wild guess 
        // return; // uncomment for launch image screen shot
        
        // have we a state saved?  if so, reconstruct game
        if let stateData = ud.object(forKey: Default.boardData) as? Data,
            let state = try? PropertyListDecoder().decode(State.self, from: stateData) {
            // okay, we've got state! there are two possibilities:
            // it might have been a practice game, or it might have been a timed game between stages
            self.board = state.board
            self.boardView = self.board.view
            self.backgroundView.addSubview(self.boardView!)
            self.boardView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            if !state.timed {
                self.interfaceMode = .practice
            } else {
                self.interfaceMode = .timed
                self.stage = Stage(lsvc: self, score: state.score)
            }
            self.betweenStages = true
            self.animateBoardTransition(.fade)
        } else { // otherwise, create new game from scratch
            self.startNewGame()
        }
        
        // responses to game events and application lifetime events
        
        // sent long-distance by board
        nc.addObserver(forName: Board.gameOver, object: nil, queue: nil) { n in
            self.prepareNewStage(n)
        }
        nc.addObserver(forName: Board.userTappedPath, object: nil, queue: nil) { n in
            // remove hint
            if self.board.showingHint {
                self.toggleHint(nil)
            }
        }
        nc.addObserver(forName: Board.userMoved, object: nil, queue: nil) { n in
            self.betweenStages = false
        }
        nc.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: nil) { _ in
            // remove hint
            if self.board.showingHint {
                self.toggleHint(nil)
            }
            // dismiss popover if any; counts as cancelling, so restore defaults if needed
            self.dismiss(animated: false)
            if let defs = self.oldDefs {
                ud.setValuesForKeys(defs)
                self.oldDefs = nil
            }
            if !self.didObserveActivate {
                self.didObserveActivate = true
                // register for activate notification only after have deactivated for the first time
                nc.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { _ in
                    let comingBack = self.comingBackFromBackground
                    self.comingBackFromBackground = false
                    // show the board view, just in case it was hidden on suspension
                    self.boardView?.isHidden = false
                    if ud.object(forKey: Default.boardData) == nil && !self.betweenStages {
                        self.startNewGame()
                    } else if comingBack {
                        self.animateBoardTransition(.fade)
                    }
                }
            }
        }
        nc.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) { _ in
            self.comingBackFromBackground = true
        }
        nc.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { _ in
            switch self.interfaceMode {
            case .timed:
                if self.betweenStages {
                    fallthrough // save out board state
                }
                // if we background when a stage is ongoing in a timed game, that's it:
                // throw away the board data! this game is over, it's never coming back
                ud.removeObject(forKey: Default.boardData)
                self.boardView?.isHidden = true // so snapshot will capture blank background
            case .practice:
                // save out board state
                let state = State(board: self.board, score: self.stage!.score, timed: self.interfaceMode == .timed)
                let stateData = try! PropertyListEncoder().encode(state)
                ud.set(stateData, forKey:Default.boardData)
            }
        }
    }
    
    private func animateBoardTransition (_ transition: BoardTransition) {
        UIApplication.ui(false) // about to animate, turn off interaction; will turn back on in delegate
        let t = CATransition()
        if transition == .slide { // default is .fade, fade in
            t.type = .moveIn
            t.subtype = .fromLeft
        }
        t.duration = 0.7
        t.beginTime = CACurrentMediaTime() + 0.15 // 0.4 was just too long
        t.fillMode = .backwards
        t.timingFunction = CAMediaTimingFunction(name:.linear)
        t.delegate = self
        t.setValue("boardReplacement", forKey:"name")
        self.boardView?.layer.add(t, forKey:nil)
    }
    
    // delegate from previous, called when animation ends
    // set "stage" label, animate the change, turn on interactivity at end
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        if anim.value(forKey: "name") as? String == "boardReplacement" {
            let s = "Stage \(self.board.stageNumber + 1) " +
            "of \(ud.integer(forKey: Default.lastStage) + 1)"
            self.stageLabel?.text = s
            UIView.transition(with: self.stageLabel!, duration: 0.4,
                              options: .transitionFlipFromLeft, animations: nil,
                              completion: {_ in
                                UIApplication.ui(true)
            })
        }
    }
    
    // called from startNewGame (n is nil)
    // called when we get Board.gameOver (n is Notification, passed along)
    // in latter case, might mean go on to next stage or might mean entire game is over
    @objc private func prepareNewStage (_ n : Any?) {
        UIApplication.ui(false)
        
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
        self.backgroundView.addSubview(self.boardView!)
        self.boardView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        self.board.stageNumber = 0 // default, we might change this in a moment
        // self.board.stage = 8 // testing, comment out!
        
        // there are three possibilities:
        // * startup, or user asked for new game
        // * notification, on to next stage
        // * notification, game is over
        // in all three cases, we will deal out a new board and show it with a transition
        // the "game is over" actually subdivides into two cases: we were playing timed or playing practice
        
        enum WhatToDo {
            case onToNextStage(Int) // next stage number
            case gameOver
            case startFromScratch
        }
        let howWeGotHere : WhatToDo = {
            () -> WhatToDo in
            if let stageNumberFromNotification = (n as? Notification)?.userInfo?["stage"] as? Int {
                if stageNumberFromNotification < ud.integer(forKey: Default.lastStage) {
                    return .onToNextStage(stageNumberFromNotification+1)
                } else {
                    return .gameOver
                }
            }
            return .startFromScratch
        }()
        
        // no matter what, this is what we will do at the end:
        func newBoard(newGame:Bool) {
            if newGame {
                self.stage = Stage(lsvc: self)
                self.interfaceMode = .timed // every new game is a timed game
            } else {
                self.stage = Stage(lsvc: self, score: self.stage!.score) // score carries over
            }
            let boardTransition : BoardTransition = newGame ? .fade : .slide
            self.board.createAndDealDeck()
            self.animateBoardTransition(boardTransition)
        }
        
        // okay, how we proceed depends upon how we got here!
        switch howWeGotHere {
        case .startFromScratch:
            newBoard(newGame:true)
        case .onToNextStage(let nextStage):
            self.board.stageNumber = nextStage
            newBoard(newGame:false)
        case .gameOver:
            if self.interfaceMode == .practice {
                // every new game is a timed game, so just start a new game
                newBoard(newGame:true)
                break
            }
            // okay, if we get here, a timed game just ended completely
            let key = self.scoresKey
            var newHigh = false
            // get dict from defaults, or an empty dict
            var scoresDict = [String:Int]()
            if let d = ud.dictionary(forKey: Default.scores) as? [String:Int] {
                scoresDict = d
            }
            // score is new high score if it is higher than corresponding previous dict entry...
            // ...or if there was no corresponding previous dict entry
            let prev = scoresDict[key]
            if prev == nil || prev! < self.stage!.score {
                newHigh = true
                scoresDict[key] = self.stage!.score
                ud.set(scoresDict, forKey:Default.scores)
            }
            // raise flag that we are between stages
            self.betweenStages = true
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
        }
        self.betweenStages = true
        UIApplication.ui(true)
    }
    
    
    // ============================ toolbar buttons =================================
    
    @IBAction @objc private func toggleHint(_:Any?) { // hintButton
        self.board.unhilite()
        if !self.board.showingHint {
            self.hintButton?.title = HintButtonTitle.hide
            self.stage?.userAskedForHint()
            self.board.hint()
        } else {
            self.hintButton?.title = HintButtonTitle.show
            self.board.unhint()
        }
    }
    
    @IBAction private func doShuffle(_:Any?) {
        if self.board.showingHint {
            self.toggleHint(nil)
        }
        self.stage?.userAskedForShuffle()
        self.board.unhilite()
        self.board.redeal()
    }
    
    @IBAction private func doRestartStage(_:Any?) {
        if self.board.showingHint {
            self.toggleHint(nil)
        }
        self.board.unhilite()
        self.betweenStages = true
        let alert = UIAlertController(title: "Restart Stage", message: "Really restart this stage?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: {
            _ in
            self.board.restartStage()
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
    func presentationController(
        _ controller: UIPresentationController,
        viewControllerForAdaptivePresentationStyle style: UIModalPresentationStyle)
        -> UIViewController? {
            let vc = controller.presentedViewController
            if vc.view is WKWebView {
                let nav = UINavigationController(rootViewController: vc)
                vc.navigationItem.rightBarButtonItem = UIBarButtonItem(
                    title: "Done", style: .plain, target: self, action: #selector(dismissHelp))
                return nav
            }
            return nil
    }
}

extension LinkSameViewController { // buttons in popover
    
    @IBAction private func doNew(_ sender:Any?) {
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
        self.present(nav, animated: true) {
            nav.popoverPresentationController?.passthroughViews = nil
        }
        if let pop = nav.popoverPresentationController, let sender = sender as? UIBarButtonItem {
            pop.permittedArrowDirections = .any
            pop.barButtonItem = sender
            pop.delegate = self
        }
        // save defaults so we can restore them later if user cancels
        self.oldDefs = ud.dictionaryWithValues(forKeys: [Default.style, Default.size, Default.lastStage])
    }
    
    @objc private func cancelNewGame() { // cancel button in new game popover
        UIApplication.ui(false)
        self.dismiss(animated: true, completion: { UIApplication.ui(true) })
        if let d = self.oldDefs {
            ud.setValuesForKeys(d)
            self.oldDefs = nil
        }
    }
    
    @objc private func startNewGame() { // save button in new game popover; can also be called manually at launch
        func whatToDo() {
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
    
    @IBAction private func doTimedPractice(_ : Any) {
        if self.board.showingHint {
            self.toggleHint(nil)
        }
        self.board.unhilite()
        self.interfaceMode = InterfaceMode(rawValue:self.timedPractice.selectedSegmentIndex)!
        // and changing the interface mode changes the interface accordingly
    }
    
    @IBAction private func doHelp(_ sender: Any?) {
        // create help from scratch
        let vc = UIViewController()
        let wv = WKWebView()
        
        wv.backgroundColor = .white // new, fix background
        let path = Bundle.main.path(forResource: "linkhelp", ofType: "html")!
        var s = try! String.init(contentsOfFile: path)
        s = s.replacingOccurrences(of: "FIXME", with: (!onPhone || on3xScreen) ? "12" : "9") // fix text size issue
        wv.loadHTMLString(s, baseURL: nil)
        // print(s)
        vc.view = wv
        vc.modalPresentationStyle = .popover
        vc.preferredContentSize = CGSize(width: 450, height: 800) // setting ppc's popoverContentSize failed
        if let pop = vc.popoverPresentationController {
            pop.delegate = self // adapt! on iPhone, we need a way to dismiss
        }
        self.present(vc, animated: true) {
            vc.popoverPresentationController?.passthroughViews = nil
        }
        if let pop = vc.popoverPresentationController {
            pop.permittedArrowDirections = .any
            if let sender = sender as? UIBarButtonItem {
                pop.barButtonItem = sender
            }
            pop.backgroundColor = UIColor.white // new - fix arrow
        }
    }
    
    @objc private func dismissHelp(_:Any) {
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
        self.present(action, animated: true)
    }
    

}



