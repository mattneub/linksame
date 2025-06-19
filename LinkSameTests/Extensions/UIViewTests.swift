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

    @Test("subviews(ofType:) returns array of type, recursing or not, including hidden or not")
    func subviewsOfType() {
        let view = UIView()
        view.addSubview(UIButton(type: .system))
        view.addSubview(UILabel())
        let otherView = UIView()
        view.addSubview(otherView)
        otherView.isHidden = true
        otherView.addSubview(UITextView())
        let textView = UITextView()
        view.addSubview(textView)
        textView.isHidden = true
        view.addSubview(UIButton(type: .custom))
        #expect(view.subviews(ofType: UISwitch.self).count == 0)
        #expect(view.subviews(ofType: UILabel.self).count == 1)
        #expect(view.subviews(ofType: UITextView.self).count == 0)
        #expect(view.subviews(ofType: UITextView.self, includeHidden: true).count == 2)
        let buttons = view.subviews(ofType: UIButton.self)
        #expect(buttons.count == 2)
        #expect(buttons[0].buttonType == .system)
        #expect(buttons[1].buttonType == .custom)

        let subview = UIView()
        view.addSubview(subview)
        subview.addSubview(UISwitch())
        #expect(view.subviews(ofType: UISwitch.self).count == 1)
        #expect(view.subviews(ofType: UISwitch.self, recursing: false).count == 0)
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
