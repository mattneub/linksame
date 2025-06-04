@testable import LinkSame
import Testing
import UIKit

@MainActor
struct RootCoordinatorTests {
    let subject = RootCoordinator()

    @Test("createInitialInterface: sets up the initial interface in the given window")
    func createInitialInterface() throws {
        let window = makeWindow()
        subject.createInitialInterface(window: window)
        let viewController = try #require(window.rootViewController as? LinkSameViewController)
        #expect(subject.rootViewController === viewController)
        #expect(window.backgroundColor == .white)
    }

    @Test("showNewGameController: sets up module, shows view controller as popover")
    func showNewGameController() throws {
        let rootViewController = ViewController()
        makeWindow(viewController: rootViewController)
        subject.rootViewController = rootViewController
        let view = UIView()
        let dismissalDelegate = MockDismissalDelegate()
        subject.showNewGameController(
            sourceItem: view,
            dismissalDelegate: dismissalDelegate,
            popoverPresentationDelegate: rootViewController
        )
        let processor = try #require(subject.newGameProcessor as? NewGameProcessor)
        let navigationController = try #require(rootViewController.presentedViewController as? UINavigationController)
        let viewController = try #require(navigationController.children.first as? NewGameController)
        #expect(viewController.processor === processor)
        #expect(processor.presenter === viewController)
        // TODO: test for dismissal button delegate
        #expect(navigationController.isModalInPresentation)
        #expect(navigationController.modalPresentationStyle == .popover)
        let presentationController = try #require(navigationController.popoverPresentationController)
        #expect(presentationController.sourceItem === view)
        #expect(presentationController.permittedArrowDirections == .any)
        let presentationDelegate = try #require(presentationController.delegate)
        #expect(presentationDelegate === rootViewController)
        #expect(viewController.newGamePopoverDismissalButtonDelegate === dismissalDelegate)
    }
}

private class ViewController: UIViewController, UIPopoverPresentationControllerDelegate {}
