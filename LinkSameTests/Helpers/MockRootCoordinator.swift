@testable import LinkSame
import UIKit

@MainActor
final class MockRootCoordinator: RootCoordinatorType {
    var methodsCalled = [String]()
    weak var window: UIWindow?
    var sourceItem: (any UIPopoverPresentationControllerSourceItem)?
    var dismissalDelegate: (any NewGamePopoverDismissalButtonDelegate)?
    var popoverPresentationDelegate: (any UIPopoverPresentationControllerDelegate)?
    var gridSize: (Int, Int) = (-1, -1)
    var options = [String]()
    var score: Int?

    func createInitialInterface(window: UIWindow) {
        methodsCalled.append(#function)
        self.window = window
    }

    func showNewGame(
        sourceItem: (any UIPopoverPresentationControllerSourceItem)?,
        popoverPresentationDelegate: UIPopoverPresentationControllerDelegate?,
        dismissalDelegate: (any NewGamePopoverDismissalButtonDelegate)?
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

    func makeBoardProcessor(gridSize: (Int, Int), score: Int) {
        methodsCalled.append(#function)
        self.gridSize = gridSize
        self.score = score
    }

    func hideBoardView() {
        methodsCalled.append(#function)
    }

    func showActionSheet(title: String?, options: [String]) async -> String? {
        methodsCalled.append(#function)
        self.options = options
        return options.first
    }


}
