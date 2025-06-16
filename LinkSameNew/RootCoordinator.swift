import UIKit

@MainActor
protocol RootCoordinatorType: AnyObject {
    // Exposed because the scene delegate needs to talk to it directly.
    var linkSameProcessor: (any Processor<LinkSameAction, LinkSameState, LinkSameEffect>)? { get }

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

    func makeBoardProcessor(gridSize: (Int, Int)) -> any BoardProcessorType
}

@MainActor
final class RootCoordinator: RootCoordinatorType {
    var linkSameProcessor: (any Processor<LinkSameAction, LinkSameState, LinkSameEffect>)?
    var newGameProcessor: (any Processor<NewGameAction, NewGameState, NewGameEffect>)?
    var helpProcessor: (any Processor<HelpAction, HelpState, Void>)?

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
        // TODO: I doubt that this is the right delegate, should probably be the processor
        viewController.newGamePopoverDismissalButtonDelegate = dismissalDelegate

        viewController.isModalInPresentation = true // must be before presentation to work
        let navigationController = UINavigationController(rootViewController: viewController)
        let navigationBar = navigationController.navigationBar
        navigationBar.scrollEdgeAppearance = navigationBar.standardAppearance
        navigationBar.compactScrollEdgeAppearance = navigationBar.compactAppearance
        navigationController.modalPresentationStyle = .popover
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

    func makeBoardProcessor(gridSize: (Int, Int)) -> any BoardProcessorType {
        BoardProcessor(gridSize: gridSize)
    }

}
