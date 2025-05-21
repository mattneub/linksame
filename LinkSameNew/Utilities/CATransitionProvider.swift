import UIKit

@MainActor
final class TransitionProvider: NSObject, @preconcurrency CAAnimationDelegate {
    var continuation: CheckedContinuation<(), Never>?

    func performTransition(transition: CATransition, layer: CALayer) async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            transition.delegate = self
            layer.add(transition, forKey: nil)
        }
    }

    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        continuation?.resume(returning: ())
    }
}
