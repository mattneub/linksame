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
        await MockUIView.animateAsync(withDuration: 0.1, delay: 0.2, options: .curveEaseOut, animations: { view.backgroundColor = .red })
        #expect(MockUIView.duration == 0.1)
        #expect(MockUIView.delay == 0.2)
        #expect(MockUIView.options == .curveEaseOut)
        #expect(view.backgroundColor == .red)
        #expect(MockUIView.completion != nil) // because we inject `continuation(resume:)`
    }

    @Test("transition(withView:): calls base transition(withView:)")
    func transition() async {
        let view = UIView()
        await MockUIView.transitionAsync(with: view, duration: 0.1, options: .transitionCrossDissolve)
        #expect(MockUIView.view === view)
        #expect(MockUIView.duration == 0.1)
        #expect(MockUIView.options == .transitionCrossDissolve)
        #expect(MockUIView.completion != nil) // because we inject `continuation(resume:)`
    }
}
