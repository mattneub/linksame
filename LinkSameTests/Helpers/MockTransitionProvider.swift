import UIKit
@testable import LinkSame

@MainActor
final class MockTransitionProvider: NSObject, TransitionProviderType {
    var transition: CATransition?
    var layer: CALayer?
    var methodsCalled = [String]()

    func performTransition(transition: CATransition, layer: CALayer) async {
        methodsCalled.append(#function)
        self.transition = transition
        self.layer = layer
    }
}

@MainActor
final class MockTransitionProviderMaker: TransitionProviderMaker {
    var mockTransitionProvider = MockTransitionProvider()

    override func makeTransitionProvider() -> any TransitionProviderType {
        self.mockTransitionProvider
    }
}
