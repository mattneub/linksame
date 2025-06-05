import UIKit

/// Class that acts as popover presentation delegate.
@MainActor
final class HelpPopoverDelegate: NSObject, UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(
        for controller: UIPresentationController,
        traitCollection: UITraitCollection
    ) -> UIModalPresentationStyle {
        traitCollection.userInterfaceIdiom == .phone ? .fullScreen : .none
    }

    func presentationController(
        _ controller: UIPresentationController,
        viewControllerForAdaptivePresentationStyle style: UIModalPresentationStyle)
    -> UIViewController? {
        if style == .fullScreen {
            let viewController = controller.presentedViewController
            return UINavigationController(rootViewController: viewController)
        }
        return nil // but the truth is that this method won't even be called on iPad
    }
}
