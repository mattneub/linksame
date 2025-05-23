import UIKit

extension UIView {
    /// Async version of `animateWithDuration`. There is no completion handler; if there is something to do
    /// after the animation ends, just do it after awaiting the call.
    /// - Parameters:
    ///   - duration: Duration of the animation.
    ///   - delay: Delay before beginning the animation, or 0 to begin immediately.
    ///   - options: Mask of animation options.
    ///   - animations: Function containing animatable changes to commit to the views.
    ///
    static func animate(withDuration duration: Double, delay: Double, options: UIView.AnimationOptions, animations: @escaping () -> Void) async {
        await withCheckedContinuation { continuation in
            Self.animate(withDuration: duration, delay: delay, options: options, animations: animations) { _ in
                continuation.resume(returning: ())
            }
        }
    }

    /// Async version of `transitionWithView`. There is no completion handler; if there is something to do
    /// after the animation ends, just do it after awaiting the call.
    /// - Parameters:
    ///   - view: The view to be animated.
    ///   - duration: Duration of the animation.
    ///   - options: Animation options describing the transition.
    ///
    /// Note that you must _not_ have any `animations` parameter.
    ///
    static func transition(with view: UIView, duration: Double, options: UIView.AnimationOptions) async {
        await withCheckedContinuation { continuation in
            Self.transition(with: view, duration: duration, options: options, animations: {}) { _ in
                continuation.resume(returning: ())
            }
        }
    }
}
