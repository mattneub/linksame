import UIKit

/// Messages sent from the presenter to the processor.
enum LinkSameAction: Equatable {
    /// The New Game popover was showing and the user wants to cancel without saving any settings made there.
    case cancelNewGame
    /// Sent once at the crucial moment where we first have our dimensions, ready to populate the board interface.
    case didInitialLayout
    /// The user tapped the hamburger button (on iPhone).
    case hamburger
    /// The user tapped the hint button. This could mean show the hint or hide the hint.
    case hint
    /// The user has asked to restart this stage.
    case restartStage
    /// Save state.
    case saveBoardState
    /// Display the Help popover.
    case showHelp(sender: (any UIPopoverPresentationControllerSourceItem)?)
    /// Display the New Game popover.
    case showNewGame(sender: (any UIPopoverPresentationControllerSourceItem)?)
    /// The user has asked to shuffle the pieces.
    case shuffle
    /// The user has asked to start a new game at the beginning, e.g. by saying Done in the New Game popover.
    case startNewGame
    /// The user tapped the timed/practice segmented control.
    case timedPractice(Int)
    /// The presenter (view controller) has its view; perform initial launch tasks.
    case viewDidLoad
}

extension LinkSameAction {
    // It seems we have to implement equality manually to make our enum Equatable,
    // because UIPopoverPresentationControllerSourceItem is not Equatable.
    static func ==(lhs: LinkSameAction, rhs: LinkSameAction) -> Bool {
        switch (lhs, rhs) {
        case (.cancelNewGame, .cancelNewGame): return true
        case (.didInitialLayout, .didInitialLayout): return true
        case (.hamburger, .hamburger): return true
        case (.hint, .hint): return true
        case (.restartStage, .restartStage): return true
        case (.saveBoardState, .saveBoardState): return true
        case (let .showHelp(sender), let .showHelp(sender2)): return sender === sender2
        case (let .showNewGame(sender), let .showNewGame(sender2)): return sender === sender2
        case (.shuffle, .shuffle): return true
        case (.startNewGame, .startNewGame): return true
        case (let .timedPractice(segment), let .timedPractice(segment2)): return segment == segment2
        case (.viewDidLoad, .viewDidLoad): return true
        default: return false
        }
    }
}
