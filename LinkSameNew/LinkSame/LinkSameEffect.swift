import UIKit

/// Live messages sent from the processor to the presenter.
enum LinkSameEffect: Equatable {
    /// Animate the appearance of the board view, using the given transition type (fade in or slide in).
    case animateBoardTransition(BoardTransition)
    /// Put the given board view into the interface.
    case putBoardViewIntoInterface(BoardView) // TODO: It may be that the coordinator should do this?
    /// Turn user interaction off or on.
    case userInteraction(Bool)
}
