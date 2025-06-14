import UIKit
@testable import LinkSame

final class MockUIView: UIView {
    static var duration: TimeInterval = 0
    static var delay: TimeInterval = 0
    static var options: UIView.AnimationOptions = []
    static var completion: ((Bool) -> Void)? = nil
    static var view: UIView? = nil
    static var methodsCalled = [String]()

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
    override static func animateAsync(withDuration duration: Double, delay: Double, options: UIView.AnimationOptions, animations: @escaping () -> Void) async {
        methodsCalled.append(#function)
        await super.animateAsync(withDuration: duration, delay: delay, options: options, animations: animations)
    }
    override static func transitionAsync(with view: UIView, duration: Double, options: UIView.AnimationOptions) async {
        methodsCalled.append(#function)
        await super.transitionAsync(with: view, duration: duration, options: options)
    }
}
