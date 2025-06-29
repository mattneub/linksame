import UIKit

/// Presentation controller for displaying the game over view.
final class GameOverPresentationController: UIPresentationController {
    weak var coordinator: (any RootCoordinatorType)?

    /// The presented view is 400 points wide and 370 high.
    override var frameOfPresentedViewInContainerView: CGRect {
        if let containerViewBounds = containerView?.bounds {
            let widthDiff = containerViewBounds.width - 400
            let heightDiff = containerViewBounds.height - 370
            return CGRect(x: widthDiff/2, y: heightDiff/2, width: 400, height: 370)
        }
        return super.frameOfPresentedViewInContainerView
    }

    /// The presentation is accompanied by dimming of what's behind it.
    override func presentationTransitionWillBegin() {
        if let containerView {
            let shadow = UIView(frame: containerView.bounds)
            shadow.backgroundColor = UIColor(white: 0, alpha: 0.4)
            shadow.alpha = 0
            containerView.insertSubview(shadow, at: 0)
            // make the shadow view tappable, so user can tap anywhere to dismiss
            let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(doTap))
            shadow.addGestureRecognizer(tapGestureRecognizer)
            // animate the appearance of the dimming
            if let coordinator = presentedViewController.transitionCoordinator {
                coordinator.animate { _ in
                    shadow.alpha = 1
                }
            }
        }
    }

    /// As the presentation is dismissed, the dimming is removed.
    override func dismissalTransitionWillBegin() {
        if let containerView {
            if let shadow = containerView.subviews.first {
                if let coordinator = presentedViewController.transitionCoordinator {
                    coordinator.animate { _ in
                        shadow.alpha = 0
                    }
                }
            }
        }
    }

    @objc func doTap() { // user tapped; dismiss
        coordinator?.dismiss()
    }
}
