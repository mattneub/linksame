@testable import LinkSame
import UIKit

@MainActor
final class MockRootCoordinator: RootCoordinatorType {

    var methodsCalled = [String]()
    weak var window: UIWindow?
    var sourceItem: (any UIPopoverPresentationControllerSourceItem)?
    var dismissalDelegate: (any NewGamePopoverDismissalButtonDelegate)?
    var popoverPresentationDelegate: (any UIPopoverPresentationControllerDelegate)?

    func createInitialInterface(window: UIWindow) {
        methodsCalled.append(#function)
        self.window = window
    }

    func showNewGameController(
        sourceItem: (any UIPopoverPresentationControllerSourceItem)?,
        dismissalDelegate: (any LinkSame.NewGamePopoverDismissalButtonDelegate)?,
        popoverPresentationDelegate: (any UIPopoverPresentationControllerDelegate)?
    ) {
        methodsCalled.append(#function)
        self.sourceItem = sourceItem
        self.dismissalDelegate = dismissalDelegate
        self.popoverPresentationDelegate = popoverPresentationDelegate
    }
}
