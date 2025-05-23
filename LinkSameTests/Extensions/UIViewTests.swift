@testable import LinkSame
import Testing
import UIKit

@MainActor
struct UIViewTests {
    init() {
        MockUIView.duration = 0
        MockUIView.delay = 0
        MockUIView.options = []
        MockUIView.completion = nil
        MockUIView.view = nil
    }

    @Test("animate(withDuration:): calls base animate(withDuration:)")
    func animate() async {
        let view = MockUIView()
        await MockUIView.animate(withDuration: 0.1, delay: 0.2, options: .curveEaseOut, animations: { view.backgroundColor = .red })
        #expect(MockUIView.duration == 0.1)
        #expect(MockUIView.delay == 0.2)
        #expect(MockUIView.options == .curveEaseOut)
        #expect(view.backgroundColor == .red)
        #expect(MockUIView.completion != nil) // because we inject `continuation(resume:)`
    }

    @Test("transition(withView:): calls base transition(withView:)")
    func transition() async {
        let view = UIView()
        await MockUIView.transition(with: view, duration: 0.1, options: .transitionCrossDissolve)
        #expect(MockUIView.view === view)
        #expect(MockUIView.duration == 0.1)
        #expect(MockUIView.options == .transitionCrossDissolve)
        #expect(MockUIView.completion != nil) // because we inject `continuation(resume:)`
    }
}

private final class MockUIView: UIView {
    static var duration: TimeInterval = 0
    static var delay: TimeInterval = 0
    static var options: UIView.AnimationOptions = []
    static var completion: ((Bool) -> Void)? = nil
    static var view: UIView? = nil
    override static func animate(withDuration duration: TimeInterval, delay: TimeInterval, options: UIView.AnimationOptions = [], animations: @escaping () -> Void, completion: ((Bool) -> Void)? = nil) {
        self.duration = duration
        self.delay = delay
        self.options = options
        self.completion = completion
        animations()
        completion?(true)
    }
    override static func transition(with view: UIView, duration: TimeInterval, options: UIView.AnimationOptions = [], animations: (() -> Void)? = nil, completion: ((Bool) -> Void)? = nil) {
        self.view = view
        self.duration = duration
        self.options = options
        self.completion = completion
        completion?(true)
    }
}
