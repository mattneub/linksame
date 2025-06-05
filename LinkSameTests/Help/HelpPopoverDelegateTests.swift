import UIKit
@testable import LinkSame
import Testing

@MainActor
struct HelpPopoverDelegateTests {
    let subject = HelpPopoverDelegate()

    @Test("adapts to fullscreen on phone")
    func adaptivePresentationStyle() {
        let presentationController = UIPresentationController(
            presentedViewController: UIViewController(),
            presenting: UIViewController()
        )
        var result = subject.adaptivePresentationStyle(
            for: presentationController,
            traitCollection: UITraitCollection(userInterfaceIdiom: .phone)
        )
        #expect(result == .fullScreen)
        result = subject.adaptivePresentationStyle(
            for: presentationController,
            traitCollection: UITraitCollection(userInterfaceIdiom: .pad)
        )
        #expect(result == .none)
    }

    @Test("wraps view controller in a navigation controller on phone")
    func viewController() throws {
        let presented = UIViewController()
        let presentationController = UIPresentationController(
            presentedViewController: presented,
            presenting: UIViewController()
        )
        var result: UIViewController? = subject.presentationController(
            presentationController,
            viewControllerForAdaptivePresentationStyle: .fullScreen
        )
        let navigationController = try #require(result as? UINavigationController)
        #expect(navigationController.children.first === presented)
        result = subject.presentationController(
            presentationController,
            viewControllerForAdaptivePresentationStyle: .none
        )
        #expect(result == nil)
    }
}

