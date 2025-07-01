import UIKit

/// Transient messages sent from the processor to the presenter.
enum LinkSameEffect: Equatable {
    /// Animate the appearance of the board view, using the given transition type (fade in or slide in).
    case animateBoardTransition(BoardTransition)
    /// Animate the stage label.
    case animateStageLabel
    /// Set the hamburger button's menu; called exactly once, at launch.
    case setHamburgerMenu(UIMenu)
    /// Turn user interaction off or on.
    case userInteraction(Bool)
}
