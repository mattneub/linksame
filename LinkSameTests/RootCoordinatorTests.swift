@testable import LinkSame
import Testing
import UIKit
import WaitWhile

@MainActor
struct RootCoordinatorTests {
    let subject = RootCoordinator()
    let screen = MockScreen()

    init() {
        services.screen = screen
        screen.traitCollection = .init(userInterfaceIdiom: .pad)
    }

    @Test("createInitialInterface: sets up the initial interface in the given window")
    func createInitialInterface() throws {
        let window = makeWindow()
        subject.createInitialInterface(window: window)
        let viewController = try #require(window.rootViewController as? LinkSameViewController)
        #expect(subject.rootViewController === viewController)
        #expect(window.backgroundColor == .white)
    }

    @Test("showNewGame: sets up module, shows view controller as popover")
    func showNewGameController() throws {
        let rootViewController = UIViewController()
        makeWindow(viewController: rootViewController)
        subject.rootViewController = rootViewController
        let view = UIView()
        let dismissalDelegate = MockDismissalDelegate()
        let popoverDelegate = MockPopoverPresentationDelegate()
        subject.showNewGame(
            sourceItem: view,
            popoverPresentationDelegate: popoverDelegate,
            dismissalDelegate: dismissalDelegate
        )
        let processor = try #require(subject.newGameProcessor as? NewGameProcessor)
        let navigationController = try #require(rootViewController.presentedViewController as? UINavigationController)
        let viewController = try #require(navigationController.children.first as? NewGameViewController)
        #expect(viewController.processor === processor)
        #expect(processor.presenter === viewController)
        #expect(navigationController.isModalInPresentation)
        #expect(navigationController.modalPresentationStyle == .popover)
        let presentationController = try #require(navigationController.popoverPresentationController)
        #expect(presentationController.passthroughViews == nil)
        #expect(presentationController.sourceItem === view)
        #expect(presentationController.permittedArrowDirections == .any)
        let presentationDelegate = try #require(presentationController.delegate)
        #expect(presentationDelegate === popoverDelegate)
        #expect(viewController.popoverPresentationDelegate === popoverDelegate)
        #expect(viewController.newGamePopoverDismissalButtonDelegate === dismissalDelegate)
    }

    @Test("showHelp: sets up module, shows view controller as popover")
    func showHelp() throws {
        let rootViewController = UIViewController()
        makeWindow(viewController: rootViewController)
        subject.rootViewController = rootViewController
        let view = UIView()
        let popoverDelegate = MockPopoverPresentationDelegate()
        subject.showHelp(
            sourceItem: view,
            popoverPresentationDelegate: popoverDelegate
        )
        let processor = try #require(subject.helpProcessor as? HelpProcessor)
        let viewController = try #require(rootViewController.presentedViewController as? HelpViewController)
        #expect(viewController.processor === processor)
        #expect(processor.presenter === viewController)
        #expect(processor.coordinator === subject)
        #expect(viewController.isModalInPresentation == false) // can tap outside to dismiss
        #expect(viewController.modalPresentationStyle == .popover)
        #expect(viewController.preferredContentSize == CGSize(width: 450, height: 800))
        let presentationController = try #require(viewController.popoverPresentationController)
        #expect(presentationController.passthroughViews == nil)
        #expect(presentationController.sourceItem === view)
        #expect(presentationController.permittedArrowDirections == .any)
        #expect(presentationController.backgroundColor == .white)
        let presentationDelegate = try #require(presentationController.delegate)
        #expect(presentationDelegate === popoverDelegate)
        #expect(viewController.popoverPresentationDelegate === popoverDelegate)
    }

    @Test("dismiss: dismisses view controller presented on root view controller")
    func dismiss() async {
        let rootViewController = UIViewController()
        makeWindow(viewController: rootViewController)
        subject.rootViewController = rootViewController
        let presentedViewController = UIViewController()
        rootViewController.present(presentedViewController, animated: false)
        #expect(rootViewController.presentedViewController != nil)
        // That was prep, here comes the test
        subject.dismiss()
        await #while(rootViewController.presentedViewController != nil)
        #expect(rootViewController.presentedViewController == nil)
        #expect(presentedViewController.presentingViewController == nil)
    }
}
