import UIKit

/// Class that acts as popover presentation delegate.
@MainActor
final class NewGamePopoverDelegate: NSObject, UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(
        for controller: UIPresentationController,
        traitCollection: UITraitCollection
    ) -> UIModalPresentationStyle {
        traitCollection.userInterfaceIdiom == .phone ? .fullScreen : .none
    }
}
