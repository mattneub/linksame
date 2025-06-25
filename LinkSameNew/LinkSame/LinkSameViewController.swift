import UIKit
import Swift
import WebKit

enum BoardTransition {
    case slide
    case fade
}

final class LinkSameViewController: UIViewController, ReceiverPresenter {

    /// Outlets referencing the interface. Some of these don't exist on iPhone!
    @IBOutlet weak var backgroundView : UIView!
    @IBOutlet weak var stageLabel : UILabel!
    @IBOutlet weak var scoreLabel : UILabel!
    @IBOutlet weak var prevLabel : UILabel!
    @IBOutlet weak var hintButton : UIBarButtonItem!
    @IBOutlet weak var timedPractice : UISegmentedControl!
    @IBOutlet weak var restartStageButton : UIBarButtonItem!
    @IBOutlet weak var toolbar : UIToolbar!

    /// Reference to the boardView; we need this because we are responsible for showing and hiding it and for transitioning it with animation.
    var boardView: UIView? { backgroundView.subviews.first as? BoardView }

    /// Reference to the processor, set by the coordinator at module creation time.
    weak var processor: (any Processor<LinkSameAction, LinkSameState, LinkSameEffect>)?

    override var nibName : String {
        get {
            return onPhone ? "LinkSameViewControllerPhone" : "LinkSameViewController"
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // increase font size on triple-resolution screen
        if on3xScreen {
            for lab in [self.scoreLabel!, self.prevLabel!, self.stageLabel!] {
                let f = lab.font!
                lab.font = f.withSize(f.pointSize + 2)
            }
        }

        // fix width of hint button to accomodate new labels Show Hint and Hide Hint
//        self.hintButton?.possibleTitles = [HintButtonTitle.show, HintButtonTitle.hide] // not working
        self.hintButton?.title = LinkSameState.HintButtonTitle.show.rawValue
        self.hintButton?.width = 110 // forced to take a wild guess

        Task {
            await processor?.receive(.viewDidLoad)
        }
    }

    var stage: Stage?
    
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
        Task {
            await processor?.receive(.didInitialLayout)
        }
//        return () // uncomment for launch image screen shot
//
//        self.restoreGameFromSavedDataOrStartNewGame()

        // responses to game events and application lifetime events

        // sent long-distance by board
//        nc.addObserver(forName: BoardProcessor.gameOver, object: nil, queue: .main) { notification in
//            let notificationStage = notification.userInfo?["stage"] as? Int
//            MainActor.assumeIsolated {
//                self.prepareNewStage(notificationStage)
//            }
//        }
//        nc.addObserver(forName: BoardProcessor.userTappedPath, object: nil, queue: .main) { _ in
            // remove hint
//            MainActor.assumeIsolated {
//                if self.board.showingHint {
//                    self.toggleHint(nil)
//                }
//            }
//        }
//        nc.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { _ in
//            MainActor.assumeIsolated {
                // remove hint
//                if self.board.showingHint {
//                    self.toggleHint(nil)
//                }
                // dismiss popover if any; counts as cancelling, so restore defaults if needed
//                Task {
//                    await self.processor?.receive(.cancelNewGame)
//                }
//                self.dismiss(animated: false)
//                if let defs = self.oldDefs {
//                    services.persistence.saveIndividually(defs)
//                    self.oldDefs = nil
//                }
//                if !self.didObserveActivate {
//                    self.didObserveActivate = true
//                    // register for activate notification only after have deactivated for the first time
//                    nc.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { _ in
//                        // okay, we've got a huge problem: if the user pulls down the notification center...
//                        // we will get a spurious didBecomeActive just before we get a spurious second willResign
//                        // to work around this and not do all this work at the wrong moment,
//                        // we "debounce"
//                        Task { @MainActor in
//                            try? await Task.sleep(for: .seconds(0.05))
//                            if UIApplication.shared.applicationState == .inactive {
//                                return // debounce, this is a spurious notification
//                            }
//                            // if we get here, it's for real
//                            self.didBecomeActive()
//                        }
//                    }
//                }
//            }
//        }
//        nc.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { _ in
//            MainActor.assumeIsolated {
//                self.comingBackFromBackground = true
//            }
//        }
    }

    func present(_ state: LinkSameState) async {
        // adjust visibility of board view
        boardView?.isHidden = state.boardViewHidden

        // adjust interface for interface mode (timed or practice)
        let timed: Bool = state.interfaceMode == .timed
        scoreLabel?.isHidden = !timed
        prevLabel?.isHidden = !timed
        timedPractice?.selectedSegmentIndex = state.interfaceMode.rawValue
        timedPractice?.isEnabled = timed
        restartStageButton?.isEnabled = timed

        // stage label
        if state.stageLabelText != stageLabel.text {
            stageLabel.text = state.stageLabelText
            stageLabel.sizeToFit()
        }

        // hint button
        hintButton?.title = state.hintButtonTitle.rawValue
    }

    func receive(_ effect: LinkSameEffect) async {
        switch effect {
        case .animateBoardTransition(let transition):
            await animateBoardTransition(transition)
        case .animateStageLabel:
            await services.view.transitionAsync(with: self.stageLabel, duration: 0.4, options: .transitionFlipFromLeft)
        case .userInteraction(let onOff):
            type(of: services.application).userInteraction(onOff)
        }
    }

    /*
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
     */

    private func animateBoardTransition(_ transition: BoardTransition) async {
        guard let boardView = self.boardView else { return }
        boardView.layer.isHidden = true
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
        let transitionProvider = services.transitionProviderMaker.makeTransitionProvider()
        boardView.layer.isHidden = false
        await transitionProvider.performTransition(transition: t, layer: boardView.layer)
    }
    
    // called from startNewGame (n is nil), which itself is called by Done button and at launch
    // called when we get Board.gameOver (n is Notification, passed along)
    // in latter case, might mean go on to next stage or might mean entire game is over
    private func prepareNewStage (_ notificationStage: Int?) {
        return ()
        type(of: services.application).userInteraction(false)

        // determine layout dimensions
        var (w,h) = Sizes.boardSize(services.persistence.loadString(forKey: .size))
        if onPhone {
            (w,h) = Sizes.boardSize(Sizes.easy)
        }
        
        // create new board object and configure it
        // self.board = Board(boardFrame:self.backgroundView.bounds, gridSize:(w,h))
        // put its `view` into the interface, replacing the one that may be there already
//        self.boardView?.removeFromSuperview()
//        self.boardView = self.board.view
//        self.backgroundView.addSubview(self.boardView!)
//        self.boardView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
//        self.board.stageNumber = 0 // default, we might change this in a moment
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
            /*
            if newGame {
                self.stage = Stage(lsvc: self)
                // TODO: need to restore this somehow
                // self.interfaceMode = .timed // every new game is a timed game
            } else {
                self.stage = Stage(lsvc: self, score: self.stage!.score) // score carries over
            }
            let boardTransition : BoardTransition = newGame ? .fade : .slide
            Task {
                self.board.createAndDealDeck()
                await self.animateBoardTransition(boardTransition)
                await processor?.receive(.saveBoardState)
            }
             */
        }
        
        // okay, how we proceed depends upon how we got here!
        switch howWeGotHere {
        case .startFromScratch:
            newBoard(newGame:true)
        case .onToNextStage(let nextStage):
//            self.board.stageNumber = nextStage
            newBoard(newGame:false)
        case .gameOver:
//            if self.interfaceMode == .practice {
//                // every new game is a timed game, so just start a new game
//                newBoard(newGame:true)
//                break
//            }
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
        type(of: services.application).userInteraction(true)
    }
    
    
    // ============================ toolbar buttons =================================
    
    @IBAction func toggleHint(_: Any?) { // hintButton
        Task {
            await processor?.receive(.hint)
        }
    }
    
    @IBAction func doShuffle(_: Any?) {
        Task {
            await processor?.receive(.shuffle)
        }
    }
    
    @IBAction private func doRestartStage(_:Any?) {
//        if self.board.showingHint {
//            self.toggleHint(nil)
//        }
//        self.board.unhilite()
        let alert = UIAlertController(title: "Restart Stage", message: "Really restart this stage?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: {
            _ in
            do {
                // try self.board.restartStage()
                // self.stage = Stage(lsvc: self, score: self.stage!.scoreAtStartOfStage)
                Task {
                    await self.animateBoardTransition(.fade)
                    await self.processor?.receive(.saveBoardState)
                }
            } catch { print(error) }
        }))
        self.present(alert, animated: true)
    }
}

extension LinkSameViewController { // buttons in hamburger button alert on iPhone, toolbar on iPad

    @IBAction func doNew(_ sender: (any UIPopoverPresentationControllerSourceItem)?) {
        Task {
            await processor?.receive(.showNewGame(sender: sender))
        }
    }

    @IBAction func doTimedPractice(_ segmentedControl: UISegmentedControl) {
        Task {
            await processor?.receive(.timedPractice(segmentedControl.selectedSegmentIndex))
        }
    }
    
    @IBAction func doHelp(_ sender: (any UIPopoverPresentationControllerSourceItem)?) {
        Task {
            await processor?.receive(.showHelp(sender: sender))
        }
    }
}

extension LinkSameViewController : UIToolbarDelegate {
    func position(for bar: any UIBarPositioning) -> UIBarPosition {
        return .topAttached
    }
}

extension LinkSameViewController { // hamburger button on phone
    @IBAction func doHamburgerButton(_ sender: Any?) {
        Task {
            await processor?.receive(.hamburger) // phone only, so no need for a source view
        }
    }
}



