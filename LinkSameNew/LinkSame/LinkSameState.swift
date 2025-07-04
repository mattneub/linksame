/// State to be presented by the processor to the presenter for visible representation in the interface.
/// Also contains state being maintained by the processor which may be meaningless to the presenter.
struct LinkSameState: Equatable {
    /// Temporary copy of the particular defaults that user might change in the new game popover.
    var defaultsBeforeShowingNewGamePopover: PopoverDefaults?
    /// Title to be displayed by the hint button.
    var hintButtonTitle = HintButtonTitle.show
    /// Whether a hint is currently being displayed. Source of truth.
    var hintShowing = false
    /// Content of the high score label (called `prevLabel` for historical reasons).
    var highScore = ""
    /// Whether the game mode should be timed or practice.
    var interfaceMode: InterfaceMode = .timed
    /// Score to display in the score label.
    var score: Score = Score(score: 0, direction: .up)
    /// Content of the stage label.
    var stageLabelText = ""

    /// Game modes; the int values are the respective indexes of the segmented control on iPad.
    enum InterfaceMode: Int {
        case timed = 0
        case practice = 1
    }

    /// Titles for the hint button on iPad.
    enum HintButtonTitle: String {
        case show = "Show Hint"
        case hide = "Hide Hint"
    }
}
