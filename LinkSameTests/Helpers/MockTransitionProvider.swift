import UIKit
@testable import LinkSame

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

final class MockTransitionProviderMaker: TransitionProviderMaker {
    var mockTransitionProvider = MockTransitionProvider()

    override func makeTransitionProvider() -> any TransitionProviderType {
        self.mockTransitionProvider
    }
}
