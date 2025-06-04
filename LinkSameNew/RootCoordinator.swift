import UIKit

@MainActor
protocol RootCoordinatorType: AnyObject {
    func createInitialInterface(window: UIWindow)

    func showNewGameController(
        sourceItem: (any UIPopoverPresentationControllerSourceItem)?,
        dismissalDelegate: (any NewGamePopoverDismissalButtonDelegate)?,
        popoverPresentationDelegate: (any UIPopoverPresentationControllerDelegate)?
    )
}

@MainActor
final class RootCoordinator: RootCoordinatorType {
    var newGameProcessor: (any Processor<NewGameAction, NewGameState, NewGameEffect>)?

    /// Reference to the root view controller of the app.
    weak var rootViewController: UIViewController?

    func createInitialInterface(window: UIWindow) {
        let viewController = LinkSameViewController()
        window.rootViewController = viewController
        self.rootViewController = viewController
        viewController.coordinator = self
        window.backgroundColor = .white
    }

    func showNewGameController(
        sourceItem: (any UIPopoverPresentationControllerSourceItem)?,
        dismissalDelegate: (any NewGamePopoverDismissalButtonDelegate)?,
        popoverPresentationDelegate: (any UIPopoverPresentationControllerDelegate)?
    ) {
        let viewController = NewGameController()
        let processor = NewGameProcessor()
        viewController.processor = processor
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
        rootViewController?.present(navigationController, animated: true) {
            navigationController.popoverPresentationController?.passthroughViews = nil
        }
        if let popoverPresentationController = navigationController.popoverPresentationController, let sourceItem {
            popoverPresentationController.permittedArrowDirections = .any
            popoverPresentationController.sourceItem = sourceItem // a recent innovation! nice
            // TODO: I don't think I like other view controller being the popover delegate, fix up eventually
            popoverPresentationController.delegate = popoverPresentationDelegate
        }
    }
}
