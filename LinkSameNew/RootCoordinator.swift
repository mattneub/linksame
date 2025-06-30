import UIKit

@MainActor
protocol RootCoordinatorType: AnyObject {
    func createInitialInterface(window: UIWindow)

    func showNewGame(
        sourceItem: (any UIPopoverPresentationControllerSourceItem)?,
        popoverPresentationDelegate: (any UIPopoverPresentationControllerDelegate)?,
        dismissalDelegate: (any NewGamePopoverDismissalButtonDelegate)?
    )

    func showHelp (
        sourceItem: (any UIPopoverPresentationControllerSourceItem)?,
        popoverPresentationDelegate: (any UIPopoverPresentationControllerDelegate)?
    )

    func dismiss()

    func makeBoardProcessor(gridSize: (Int, Int), score: Int)

    func hideBoardView()

    func showGameOver(state: GameOverState)
}

@MainActor
final class RootCoordinator: RootCoordinatorType {
    var linkSameProcessor: (any Processor<LinkSameAction, LinkSameState, LinkSameEffect>)?
    var newGameProcessor: (any Processor<NewGameAction, NewGameState, NewGameEffect>)?
    var helpProcessor: (any Processor<HelpAction, HelpState, Void>)?
    var gameOverProcessor: (any Processor<GameOverAction, GameOverState, Void>)?

    /// Reference to the root view controller of the app.
    weak var rootViewController: UIViewController?

    func createInitialInterface(window: UIWindow) {
        let viewController = LinkSameViewController()
        let processor = LinkSameProcessor()
        viewController.processor = processor
        processor.presenter = viewController
        self.linkSameProcessor = processor
        window.rootViewController = viewController
        self.rootViewController = viewController
        processor.coordinator = self
        window.backgroundColor = .white
    }

    func showNewGame(
        sourceItem: (any UIPopoverPresentationControllerSourceItem)?,
        popoverPresentationDelegate: (any UIPopoverPresentationControllerDelegate)?,
        dismissalDelegate: (any NewGamePopoverDismissalButtonDelegate)?
    ) {
        let viewController = NewGameViewController()
        let processor = NewGameProcessor()
        viewController.processor = processor
        viewController.popoverPresentationDelegate = popoverPresentationDelegate
        processor.presenter = viewController
        newGameProcessor = processor
        processor.dismissalDelegate = dismissalDelegate

        viewController.isModalInPresentation = true // must be before presentation to work
        let navigationController = UINavigationController(rootViewController: viewController)
        let navigationBar = navigationController.navigationBar
        navigationBar.scrollEdgeAppearance = navigationBar.standardAppearance
        navigationBar.compactScrollEdgeAppearance = navigationBar.compactAppearance
        navigationController.modalPresentationStyle = .popover
        if onPhone {
            navigationController.transitioningDelegate = viewController
            navigationController.modalPresentationStyle = .custom
        }
        if let presentationController = navigationController.popoverPresentationController {
            presentationController.delegate = viewController.popoverPresentationDelegate
        }
        rootViewController?.present(navigationController, animated: unlessTesting(true)) {
            navigationController.popoverPresentationController?.passthroughViews = nil
        }
        if let presentationController = navigationController.popoverPresentationController, let sourceItem {
            presentationController.permittedArrowDirections = .any
            presentationController.sourceItem = sourceItem // a recent innovation! nice
        }
    }

    func showHelp (
        sourceItem: (any UIPopoverPresentationControllerSourceItem)?,
        popoverPresentationDelegate: (any UIPopoverPresentationControllerDelegate)?
    ) {
        let viewController = HelpViewController()
        let processor = HelpProcessor()
        viewController.processor = processor
        viewController.popoverPresentationDelegate = popoverPresentationDelegate
        processor.presenter = viewController
        self.helpProcessor = processor
        processor.coordinator = self

        viewController.modalPresentationStyle = .popover
        viewController.preferredContentSize = CGSize(width: 450, height: 800) // setting ppc's popoverContentSize failed
        if let presentationController = viewController.popoverPresentationController {
            presentationController.delegate = viewController.popoverPresentationDelegate
        }
        rootViewController?.present(viewController, animated: unlessTesting(true)) {
            viewController.popoverPresentationController?.passthroughViews = nil
        }
        if let presentationController = viewController.popoverPresentationController {
            presentationController.permittedArrowDirections = .any
            if let sourceItem {
                presentationController.sourceItem = sourceItem
            }
            presentationController.backgroundColor = UIColor.white
        }
    }

    func dismiss() {
        rootViewController?.dismiss(animated: unlessTesting(true))
    }

    func makeBoardProcessor(gridSize: (Int, Int), score: Int) {
        let scoreKeeper = ScoreKeeper(score: score, delegate: linkSameProcessor as? any ScoreKeeperDelegate)
        let boardProcessor = BoardProcessor(gridSize: gridSize, scoreKeeper: scoreKeeper)
        (linkSameProcessor as? LinkSameProcessor)?.boardProcessor = boardProcessor
        let boardView = BoardView(columns: gridSize.0, rows: gridSize.1)
        boardProcessor.presenter = boardView
        boardView.layer.opacity = 0 // NB The board view is born invisible! See `animateBoardTransition`
        boardProcessor.delegate = linkSameProcessor as? any BoardDelegate
        boardView.processor = boardProcessor
        if let viewController = rootViewController as? LinkSameViewController {
            viewController.backgroundView.subviews.forEach { $0.removeFromSuperview() }
            viewController.backgroundView.addSubview(boardView)
            boardView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                viewController.backgroundView.topAnchor.constraint(equalTo: boardView.topAnchor),
                viewController.backgroundView.bottomAnchor.constraint(equalTo: boardView.bottomAnchor),
                viewController.backgroundView.leadingAnchor.constraint(equalTo: boardView.leadingAnchor),
                viewController.backgroundView.trailingAnchor.constraint(equalTo: boardView.trailingAnchor),
            ])
            // important: we need the boardView to attain its actual size, immediately
            viewController.backgroundView.layoutIfNeeded()
        }
    }

    func hideBoardView() {
        // TODO: I am not dealing with the rule that says only to do this if interface mode is timed
        // and indeed I might not even bother
        rootViewController?.view.subviews(ofType: BoardView.self).first?.layer.opacity = 0
    }

    func showGameOver(state: GameOverState) {
        let processor = GameOverProcessor()
        let viewController = GameOverViewController()
        processor.state = state
        processor.presenter = viewController
        processor.coordinator = self
        viewController.processor = processor
        self.gameOverProcessor = processor
        viewController.transitioningDelegate = viewController
        viewController.modalPresentationStyle = .custom
        rootViewController?.present(viewController, animated: unlessTesting(true))
        if let presentationController = viewController.presentationController as? GameOverPresentationController {
            presentationController.coordinator = self
        }
    }
}
