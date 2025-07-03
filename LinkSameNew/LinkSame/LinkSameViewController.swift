import UIKit
import Swift
import WebKit

/// Types of transition we can perform when showing the board.
enum BoardTransition {
    case slide
    case fade
}

final class LinkSameViewController: UIViewController, ReceiverPresenter {

    /// Outlets referencing the interface.
    @IBOutlet weak var backgroundView: UIView!
    @IBOutlet weak var stageLabel: UILabel!
    @IBOutlet weak var scoreLabel: UILabel!
    @IBOutlet weak var prevLabel: UILabel!

    /// More outlets. These don't exist on the iPhone, so they are true Optionals so we don't crash.
    @IBOutlet weak var hintButton: UIBarButtonItem?
    @IBOutlet weak var timedPractice: UISegmentedControl?
    @IBOutlet weak var restartStageButton: UIBarButtonItem?

    /// Even more outlets. These exist only on the iPhone, not on iPad.
    @IBOutlet weak var hamburgerButton: UIButton?
    @IBOutlet weak var practiceLabel: UILabel?

    /// Reference to the boardView; we need this because we are responsible for showing it by
    /// transitioning it with animation.
    var boardView: BoardView? { backgroundView.subviews.first as? BoardView }

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
            for label in [self.scoreLabel, self.prevLabel, self.stageLabel, self.practiceLabel] {
                if let font = label?.font {
                    label?.font = font.withSize(font.pointSize + 2)
                }
            }
        }

        // fix width of hint button to accomodate new labels Show Hint and Hide Hint
        /*
        self.hintButton?.possibleTitles = [
            LinkSameState.HintButtonTitle.show.rawValue,
            LinkSameState.HintButtonTitle.hide.rawValue,
        ] // not working
         */
        self.hintButton?.title = LinkSameState.HintButtonTitle.show.rawValue
        self.hintButton?.width = 110 // forced to take a wild guess

        // have to configure this in code, there is no storyboard analogue
        hamburgerButton?.addTarget(self, action: #selector(doHamburgerButton), for: .menuActionTriggered)
        hamburgerButton?.preferredMenuElementOrder = .fixed

        Task {
            await processor?.receive(.viewDidLoad)
        }
    }

    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init(coder: NSCoder) {
        fatalError("NSCoding not supported")
    }
    
    private var didSetUpInitialLayout = false
    override func viewDidLayoutSubviews() {
        guard !self.didSetUpInitialLayout else { return }
        self.didSetUpInitialLayout = true
        Task {
            await processor?.receive(.didInitialLayout)
        }
    }

    func present(_ state: LinkSameState) async {
        // adjust interface for interface mode (timed or practice)
        let timed: Bool = state.interfaceMode == .timed
        scoreLabel.isHidden = !timed
        prevLabel.isHidden = !timed
        timedPractice?.selectedSegmentIndex = state.interfaceMode.rawValue
        timedPractice?.isEnabled = timed
        practiceLabel?.isHidden = timed

        // stage label
        if state.stageLabelText != stageLabel.text {
            stageLabel.text = state.stageLabelText
            stageLabel.sizeToFit()
        }

        // high score label
        prevLabel.text = state.highScore

        // score label
        scoreLabel.text = String(state.score.score)
        scoreLabel.textColor = state.score.direction == .up ? .black : .red

        // hint button
        hintButton?.title = state.hintButtonTitle.rawValue
    }

    func receive(_ effect: LinkSameEffect) async {
        switch effect {
        case .animateBoardTransition(let transition):
            await animateBoardTransition(transition)
        case .animateStageLabel:
            await services.view.transitionAsync(with: self.stageLabel, duration: 0.4, options: .transitionFlipFromLeft)
        case .setHamburgerMenu(let menu):
            hamburgerButton?.menu = menu
        case .userInteraction(let onOff):
            type(of: services.application).userInteraction(onOff)
        }
    }

    /// Show the board view, using the specified transition type.
    /// **This is the only legal way to show the board view.**
    /// - Parameter transitionType: Type of transition to use.
    private func animateBoardTransition(_ transitionType: BoardTransition) async {
        guard let boardView = self.boardView else { return }
        // In the case of a fade, esp. during restart stage where we fade from one board full of
        // pieces to another, it looks much better if the old board remains visible as a sort of
        // ground behind the new one that fades in. Hence this snapshot.
        let snapshot = boardView.snapshotView(afterScreenUpdates: false) ?? UIView()
        if transitionType == .fade {
            backgroundView.insertSubview(snapshot, belowSubview: boardView)
        }
        // Okay, here we go!
        boardView.layer.opacity = 0
        CATransaction.flush() // crucial! interface must settle before transition
        let transition = CATransition()
        if transitionType == .slide { // default is .fade, fade in
            transition.type = .moveIn
            transition.subtype = .fromLeft
        }
        transition.duration = 0.7
        try? await unlessTesting {
            try? await Task.sleep(for: .seconds(0.15))
        }
        transition.timingFunction = CAMediaTimingFunction(name:.linear)
        let transitionProvider = services.transitionProviderMaker.makeTransitionProvider()
        boardView.layer.opacity = 1
        await transitionProvider.performTransition(transition: transition, layer: boardView.layer)
        snapshot.removeFromSuperview()
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
    
    @IBAction func doRestartStage(_: Any?) {
        Task {
            await processor?.receive(.restartStage)
        }
    }

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
