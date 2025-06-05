

import UIKit
import Swift
import WebKit

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
// linear interpolation formula
// https://math.stackexchange.com/a/377174
// Quote: If you have numbers x in the range [a,b] and you want to transform them
// to numbers y in the range [c,d], you need to do this:
// y = (x-a)*(d-c)/(b-a)+c
func transform(x:Double, r1lo a:Double, r1hi b:Double, r2lo c:Double, d2hi d:Double) -> Double {
    return (x-a)*(d-c)/(b-a)+c
}
// but see also https://developer.apple.com/documentation/accelerate/vdsp/linear_interpolation_functions/use_linear_interpolation_to_construct_new_data_points
// ok, this is it! arrived at experimentally
// I like the curve and I like the values attainable (i.e. you can pretty easily get 10 but not _too_ easily)
func calcBonus(_ diff: Double) -> Int {
    // There is a rare crash here where `diff` is a nan or infinite. To avoid this, let's try to
    // pick out the crash cases and return some value immediately. I am not actually sure what
    // value to return; should it be zero or 10, the two ends of the scale as it were...?
    if diff.isNaN || diff.isInfinite {
        return 0
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

@MainActor
private final class Stage: NSObject {
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
        if let scoresDict: [String: Int] = services.persistence.loadDictionary(forKey: .scores),
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
        // self.timer?.cancel()
        // nc.removeObserver(self) // probably not needed, but whatever
    }
    // okay, you're never going to believe this one
    // I finally saw how to register for become active without triggering on the first one:
    // register in the first resign active! what a dummy I am not to have realized this
    private var didResign = false
    @objc private func resigningActive() { // notification
        Task {
            await self.timer?.cancel()
        }
        if !self.didResign {
            self.didResign = true
            nc.addObserver(self, selector: #selector(didBecomeActive),
                           name: UIApplication.didBecomeActiveNotification, object: nil)
        }
    }
    private func restartTimer() { // private utility: start counting down from 10
        self.timer = CancelableTimer(interval: 10) { [weak self] in
            await self?.timerTimedOut()
        }
    }

    private func timerTimedOut() {
        // timed out! user failed to move, adjust score, interface
        // this is our main job!
        self.score -= 1
        self.lsvc.scoreLabel?.text = String(self.score)
        self.lsvc.scoreLabel?.textColor = .red
        restartTimer()
    }

    @objc private func didBecomeActive() { // notification
        // okay, so it turns out we can "become active" spuriously when user pulls down notification center
        // however, this is no big deal because we perfectly symmetrical;
        // we will start the timer and then an instant later cancel it again
        self.restartTimer()
    }
    @objc private func gameEnded() { // notification from Board
        Task {
            await self.timer?.cancel()
        }
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

@MainActor
private struct State : Codable {
    let board : Board
    let score : Int
    let timed : Bool
}

final class LinkSameViewController : UIViewController, NewGamePopoverDismissalButtonDelegate {

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
    private var oldDefs : [DefaultKey : Any]?

    weak var coordinator: (any RootCoordinatorType)?

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
        let size = services.persistence.loadString(forKey: .size)
        let stages = services.persistence.loadInt(forKey: .lastStage)
        let key = "\(size)\(stages)"
        return key
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
        self.hintButton?.width = 110 // forced to take a wild guess
        // return; // uncomment for launch image screen shot
        self.restoreGameFromSavedDataOrStartNewGame()
        
        // responses to game events and application lifetime events
        
        // sent long-distance by board
        nc.addObserver(forName: Board.gameOver, object: nil, queue: .main) { notification in
            let notificationStage = notification.userInfo?["stage"] as? Int
            MainActor.assumeIsolated {
                self.prepareNewStage(notificationStage)
            }
        }
        nc.addObserver(forName: Board.userTappedPath, object: nil, queue: .main) { _ in
            // remove hint
            MainActor.assumeIsolated {
                if self.board.showingHint {
                    self.toggleHint(nil)
                }
            }
        }
        nc.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated {
                // remove hint
                if self.board.showingHint {
                    self.toggleHint(nil)
                }
                // dismiss popover if any; counts as cancelling, so restore defaults if needed
                self.dismiss(animated: false)
                if let defs = self.oldDefs {
                    services.persistence.saveIndividually(defs)
                    self.oldDefs = nil
                }
                if !self.didObserveActivate {
                    self.didObserveActivate = true
                    // register for activate notification only after have deactivated for the first time
                    nc.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { _ in
                        // okay, we've got a huge problem: if the user pulls down the notification center...
                        // we will get a spurious didBecomeActive just before we get a spurious second willResign
                        // to work around this and not do all this work at the wrong moment,
                        // we "debounce"
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(0.05))
                            if UIApplication.shared.applicationState == .inactive {
                                return // debounce, this is a spurious notification
                            }
                            // if we get here, it's for real
                            self.didBecomeActive()
                        }
                    }
                }
            }
        }
        nc.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated {
                self.comingBackFromBackground = true
            }
        }
        nc.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated {
                switch self.interfaceMode {
                case .timed:
                    // do not save board state! it was saved when the stage started, and that's where we'll return to
                    // but do hide the board view so snapshot will capture blank background
                    self.boardView?.isHidden = true
                case .practice:
                    // do save out board state! and let the board appear in the snapshot, as it will be the same returning
                    self.saveBoardState()
                }
            }
        }
    }
    
    private func saveBoardState() {
        let state = State(board: self.board, score: self.stage!.score,
                          timed: self.interfaceMode == .timed)
        let stateData = try! PropertyListEncoder().encode(state)
        services.persistence.save(stateData, forKey: .boardData)
    }
    
    private func restoreGameFromSavedDataOrStartNewGame() {
        // have we a state saved?  if so, reconstruct game
        if let stateData = services.persistence.loadData(forKey: .boardData),
            let state = try? PropertyListDecoder().decode(State.self, from: stateData) {
            // okay, we've got state! there are two possibilities:
            // it might have been a practice game, or it might have been a timed game between stages
            self.board = state.board
            self.boardView?.removeFromSuperview()
            self.boardView = self.board.view
            self.backgroundView.addSubview(self.boardView!)
            self.boardView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            // there must _always_ be a Stage, and a practice game just ignores it
            self.stage = Stage(lsvc: self, score: state.score)
            self.interfaceMode = state.timed ? .timed : .practice
            Task {
                await self.animateBoardTransition(.fade)
                self.populateStageLabel() // with no animation
            }
        } else { // otherwise, create new game from scratch
            self.startNewGame()
        }
    }
    
    // this is what we do when we become active, NOT on launch, NOT spurious
    private func didBecomeActive() { // notification
        // show the board view, just in case it was hidden on suspension
        self.boardView?.isHidden = false
        
        // distinguish return from suspension from mere reactivation from deactivation
        let comingBack = self.comingBackFromBackground
        self.comingBackFromBackground = false
        
        // take care of corner case where user saw game over alert but didn't dismiss it
        // (and so it was automatically dismissed when we deactivated)
        if services.persistence.loadBool(forKey: .gameEnded) {
            services.persistence.save(false, forKey: .gameEnded)
            self.startNewGame()
            return
        }
        
        if comingBack { // we were backgrounded
            self.restoreGameFromSavedDataOrStartNewGame()
        }
        // and if merely reactivating from deactive and not between stages,
        // do nothing and let Stage restart timer
    }
    
    private func animateBoardTransition(_ transition: BoardTransition) async {
        guard let boardView = self.boardView else { return }
        boardView.layer.isHidden = true
        UIApplication.userInteraction(false)
        CATransaction.flush() // crucial! interface must settle before transition
        let t = CATransition()
        if transition == .slide { // default is .fade, fade in
            t.type = .moveIn
            t.subtype = .fromLeft
        }
        t.duration = 0.7
        t.beginTime = CACurrentMediaTime() + 0.15
        t.fillMode = .backwards
        t.timingFunction = CAMediaTimingFunction(name:.linear)
        let transitionProvider = TransitionProvider()
        boardView.layer.isHidden = false
        await transitionProvider.performTransition(transition: t, layer: boardView.layer)
        self.populateStageLabel()
        await UIView.transition(with: self.stageLabel, duration: 0.4, options: .transitionFlipFromLeft)
        UIApplication.userInteraction(true)
    }
    
    private func populateStageLabel() {
        let s = """
        Stage \(self.board.stageNumber + 1) \
        of \(services.persistence.loadInt(forKey: .lastStage) + 1)
        """
        self.stageLabel?.text = s
        self.stageLabel?.sizeToFit()
    }

    // called from startNewGame (n is nil), which itself is called by Done button and at launch
    // called when we get Board.gameOver (n is Notification, passed along)
    // in latter case, might mean go on to next stage or might mean entire game is over
    private func prepareNewStage (_ notificationStage: Int?) {
        UIApplication.userInteraction(false)

        // determine layout dimensions
        var (w,h) = Sizes.boardSize(services.persistence.loadString(forKey: .size))
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
            if let notificationStage {
                if notificationStage < services.persistence.loadInt(forKey: .lastStage) {
                    return .onToNextStage(notificationStage + 1)
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
            Task {
                self.board.createAndDealDeck()
                await self.animateBoardTransition(boardTransition)
                self.saveBoardState()
            }
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
            if let d: [String: Int] = services.persistence.loadDictionary(forKey: .scores) {
                scoresDict = d
            }
            // score is new high score if it is higher than corresponding previous dict entry...
            // ...or if there was no corresponding previous dict entry
            let prev = scoresDict[key]
            if prev == nil || prev! < self.stage!.score {
                newHigh = true
                scoresDict[key] = self.stage!.score
                services.persistence.save(scoresDict, forKey: .scores)
            }
            // notify user
            let alert = UIAlertController(
                title: "Congratulations!",
                message: "You have finished the game with a score of \(self.stage!.score)." +
                    (newHigh ? " That is a new high score for this level!" : ""),
                preferredStyle: .alert)
            alert.addAction(UIAlertAction(
                title: "Cool!", style: .cancel, handler:  { _ in
                    services.persistence.save(false, forKey: .gameEnded)
                    newBoard(newGame:true)
            }))
            self.present(alert, animated: true)
            services.persistence.save(true, forKey: .gameEnded)
        }
        UIApplication.userInteraction(true)
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
        let alert = UIAlertController(title: "Restart Stage", message: "Really restart this stage?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: {
            _ in
            do {
                try self.board.restartStage()
                self.stage = Stage(lsvc: self, score: self.stage!.scoreAtStartOfStage)
                Task {
                    await self.animateBoardTransition(.fade)
                    self.saveBoardState()
                }
            } catch { print(error) }
        }))
        self.present(alert, animated: true)
    }
}

extension LinkSameViewController { // buttons in popover
    
    @IBAction private func doNew(_ sender: (any UIPopoverPresentationControllerSourceItem)?) {
        if self.board.showingHint {
            self.toggleHint(nil)
        }
        self.board.unhilite()
        coordinator?.showNewGame(
            sourceItem: sender,
            popoverPresentationDelegate: NewGamePopoverDelegate(),
            dismissalDelegate: self
        )
        // save defaults so we can restore them later if user cancels
        self.oldDefs = services.persistence.loadAsDictionary([.style, .size, .lastStage])
    }
    
    func cancelNewGame() { // cancel button in new game popover
        UIApplication.userInteraction(false)
        self.dismiss(animated: true, completion: { UIApplication.userInteraction(true) })
        if let d = self.oldDefs {
            services.persistence.saveIndividually(d)
            self.oldDefs = nil
        }
    }
    
    // Done button in new game popover
    // also, at launch, through layout subviews
    // also when we become active, if we have no board data
    func startNewGame() {
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
    
    @IBAction private func doHelp(_ sender: (any UIPopoverPresentationControllerSourceItem)?) {
        coordinator?.showHelp(
            sourceItem: sender,
            popoverPresentationDelegate: HelpPopoverDelegate()
        )
    }
}

extension LinkSameViewController : UIToolbarDelegate {
    func position(for bar: any UIBarPositioning) -> UIBarPosition {
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



