import UIKit
@testable import LinkSame
import Testing

@MainActor
struct NewGamePopoverDelegateTests {
    let subject = NewGamePopoverDelegate()

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
}
