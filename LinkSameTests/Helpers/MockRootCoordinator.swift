@testable import LinkSame
import UIKit

@MainActor
final class MockRootCoordinator: RootCoordinatorType {

    var methodsCalled = [String]()
    weak var window: UIWindow?
    var sourceItem: (any UIPopoverPresentationControllerSourceItem)?
    var dismissalDelegate: (any NewGamePopoverDismissalButtonDelegate)?

    func createInitialInterface(window: UIWindow) {
        methodsCalled.append(#function)
        self.window = window
    }

    func showNewGame(
        sourceItem: (any UIPopoverPresentationControllerSourceItem)?,
        popoverPresentationDelegate: UIPopoverPresentationControllerDelegate?,
        dismissalDelegate: (any LinkSame.NewGamePopoverDismissalButtonDelegate)?
    ) {
        methodsCalled.append(#function)
        self.sourceItem = sourceItem
        self.dismissalDelegate = dismissalDelegate
    }

    func showHelp(
        sourceItem: (any UIPopoverPresentationControllerSourceItem)?,
        popoverPresentationDelegate: UIPopoverPresentationControllerDelegate?
    ) {
        methodsCalled.append(#function)
    }

    func dismiss() {
        methodsCalled.append(#function)
    }
}
