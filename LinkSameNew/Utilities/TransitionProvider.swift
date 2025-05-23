import UIKit

/// Class that embodies an async/await version of performing a CATransition.
/// A CATransition has no completion handler, so this class encapsulates starting a transition
/// and responding when the transition ends by use of an animation delegate, where "responding"
/// means proceeding after `await`.
///
/// Note that an animation retains its delegate, so it is sufficient to create an instance of this
/// class and tell it to `performTransition` all in one breath; the instance will be released after
/// the animation ends, which is all the lifetime it needs.
@MainActor
final class TransitionProvider: NSObject, @preconcurrency CAAnimationDelegate {
    /// The continuation, unfolded from the call that starts the transition so that we can
    /// access it and resume when the transition ends.
    private var continuation: CheckedContinuation<(), Never>?

    /// This is the only public method. Perform the given transition on the given layer and wait
    /// until it is finished.
    /// - Parameters:
    ///   - transition: The desired CATransition.
    ///   - layer: The CALayer to which the transition should be added.
    func performTransition(transition: CATransition, layer: CALayer) async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            transition.delegate = self
            layer.add(transition, forKey: nil)
        }
    }

    /// Callback from the runtime when the animation stops, because we are the animation delegate.
    /// We simply resume the continuation. (Unfortunately cannot be made private.)
    /// - Parameters:
    ///   - anim: The animation. Ignored.
    ///   - flag: Whether the animation completed. Ignored.
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        continuation?.resume(returning: ())
    }
}
