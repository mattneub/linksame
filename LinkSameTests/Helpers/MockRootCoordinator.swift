@testable import LinkSame
import UIKit

@MainActor
final class MockRootCoordinator: RootCoordinatorType {

    var methodsCalled = [String]()
    weak var window: UIWindow?
    var sourceItem: (any UIPopoverPresentationControllerSourceItem)?
    var dismissalDelegate: (any NewGamePopoverDismissalButtonDelegate)?
    var popoverPresentationDelegate: (any UIPopoverPresentationControllerDelegate)?
    var gridSize: (Int, Int)?

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
        self.popoverPresentationDelegate = popoverPresentationDelegate
    }

    func showHelp(
        sourceItem: (any UIPopoverPresentationControllerSourceItem)?,
        popoverPresentationDelegate: UIPopoverPresentationControllerDelegate?
    ) {
        methodsCalled.append(#function)
        self.sourceItem = sourceItem
        self.popoverPresentationDelegate = popoverPresentationDelegate
    }

    func dismiss() {
        methodsCalled.append(#function)
    }

    func makeBoardProcessor(gridSize: (Int, Int)) -> any BoardProcessorType {
        methodsCalled.append(#function)
        self.gridSize = gridSize
        return MockBoardProcessor()
    }

}
