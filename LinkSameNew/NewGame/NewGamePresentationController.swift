import UIKit

/// Class that configures the appearance of the new game view on iPhone.
final class NewGamePresentationController: UIPresentationController {
    /// The presented view is only 320 points wide.
    override var frameOfPresentedViewInContainerView: CGRect {
        if let containerViewBounds = containerView?.bounds {
            let widthDiff = containerViewBounds.width - 320
            return CGRect(x: widthDiff/2, y: 0, width: 320, height: containerViewBounds.height)
        }
        return super.frameOfPresentedViewInContainerView
    }

    /// The presented view has rounded corners.
    override var presentedView: UIView? {
        if let presentedView = super.presentedView {
            presentedView.layer.cornerRadius = 6
            presentedView.layer.masksToBounds = true
            return presentedView
        }
        return super.presentedView
    }

    /// The presentation is accompanied by dimming of what's behind it.
    override func presentationTransitionWillBegin() {
        if let containerView {
            let shadow = UIView(frame: containerView.bounds)
            shadow.backgroundColor = UIColor(white: 0, alpha: 0.4)
            containerView.insertSubview(shadow, at: 0)
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
}
