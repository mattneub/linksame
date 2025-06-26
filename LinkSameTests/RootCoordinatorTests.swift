@testable import LinkSame
import Testing
import UIKit
import WaitWhile

@MainActor
struct RootCoordinatorTests {
    let subject = RootCoordinator()
    let screen = MockScreen()
    let scoreKeeper = MockScoreKeeper()

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
        #expect(processor.dismissalDelegate === dismissalDelegate)
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

    @Test("dismiss: dismisses view controller presented on root view controller, resumes and nilifies continuation")
    func dismiss() async {
        let rootViewController = UIViewController()
        makeWindow(viewController: rootViewController)
        subject.rootViewController = rootViewController
        let presentedViewController = UIViewController()
        rootViewController.present(presentedViewController, animated: false)
        #expect(rootViewController.presentedViewController != nil)
        // test for proper continuation management, in case we are presenting action sheet
        var result: String? = "yoho"
        Task {
            result = await withCheckedContinuation { continuation in
                subject.actionSheetContinuation = continuation
            }
        }
        await #while(subject.actionSheetContinuation == nil)
        #expect(subject.actionSheetContinuation != nil)
        // That was prep, here comes the test
        subject.dismiss()
        await #while(rootViewController.presentedViewController != nil)
        #expect(rootViewController.presentedViewController == nil)
        #expect(presentedViewController.presentingViewController == nil)
        // if there is an action sheet continuation, subject resumes it with nil and nilifies it
        #expect(subject.actionSheetContinuation == nil)
        #expect(result == nil)
    }

    @Test("makeBoardProcessor: creates Board module, configures board processor")
    func makeBoardProcessor() async throws {
        let window = makeWindow()
        subject.createInitialInterface(window: window)
        subject.makeBoardProcessor(gridSize: (3, 2), score: 42)
        let linkSameProcessor = try #require(subject.linkSameProcessor as? LinkSameProcessor)
        let boardProcessor = try #require(linkSameProcessor.boardProcessor as? BoardProcessor)
        let boardView = try #require(boardProcessor.presenter as? BoardView)
        #expect(boardView.processor === boardProcessor)
        let boardProcessorDelegate = try #require(boardProcessor.delegate)
        #expect(boardProcessorDelegate === linkSameProcessor)
        let scoreKeeper = try #require(boardProcessor.scoreKeeper as? ScoreKeeper)
        let scoreKeeperDelegate = try #require(scoreKeeper.delegate)
        #expect(scoreKeeperDelegate === linkSameProcessor)
        let linkSameViewController = try #require(subject.rootViewController as? LinkSameViewController)
        #expect(boardView.translatesAutoresizingMaskIntoConstraints == false)
        let constraints = linkSameViewController.backgroundView.constraints.filter { $0.secondItem as? UIView === boardView }
        #expect(constraints.count == 4)
        #expect(constraints.allSatisfy { $0.firstItem as? UIView === linkSameViewController.backgroundView })
        #expect(constraints.allSatisfy { $0.secondItem as? UIView === boardView })
        let firsts = constraints.map { $0.firstAttribute }
        let expected: [NSLayoutConstraint.Attribute] = [.top, .bottom, .leading, .trailing]
        #expect(Set(firsts) == Set(expected))
        #expect(constraints.allSatisfy { $0.firstAttribute == $0.secondAttribute })
        let grid = boardProcessor.grid
        #expect(grid.columns == 3)
        #expect(grid.rows == 2)
        #expect(boardView.columns == 3)
        #expect(boardView.rows == 2)
        #expect(boardProcessor.scoreKeeper === scoreKeeper)
    }

    @Test("hideBoardView: hides board view")
    func hideBoardView() throws {
        let window = makeWindow()
        subject.createInitialInterface(window: window)
        subject.makeBoardProcessor(gridSize: (3, 2), score: 42)
        let linkSameProcessor = try #require(subject.linkSameProcessor as? LinkSameProcessor)
        let boardProcessor = try #require(linkSameProcessor.boardProcessor as? BoardProcessor)
        let boardView = try #require(boardProcessor.presenter as? BoardView)
        #expect(boardView.isHidden == false)
        subject.hideBoardView()
        #expect(boardView.isHidden == true)
    }

    @Test("showActionSheet: shows action sheet")
    func showActionSheet() async throws {
        let rootViewController = UIViewController()
        makeWindow(viewController: rootViewController)
        subject.rootViewController = rootViewController
        #expect(subject.actionSheetContinuation == nil)
        var result: String?
        Task {
            result = await subject.showActionSheet(title: "title", options: ["hey", "ho"])
        }
        await #while(rootViewController.presentedViewController == nil)
        let alert = try #require(rootViewController.presentedViewController as? UIAlertController)
        #expect(alert.title == "title")
        #expect(alert.actions.count == 3)
        #expect(alert.actions[0].title == "hey")
        #expect(alert.actions[1].title == "ho")
        #expect(alert.actions[2].title == "Cancel")
        #expect(alert.preferredStyle == .actionSheet)
        #expect(subject.actionSheetContinuation != nil)
        // test that `showActionSheet` returns the tapped button's title to the caller
        alert.tapButton(atIndex: 0)
        await #while(result == nil)
        #expect(result == "hey")
        #expect(subject.actionSheetContinuation == nil)
    }
}
