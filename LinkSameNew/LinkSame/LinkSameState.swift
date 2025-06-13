/// State to be presented by the processor to the presenter for visible representation in the interface.
/// Also contains state being maintained by the processor which may be meaningless to the presenter.
struct LinkSameState {
    /// Whether the board view should be hidden or displayed.
    var boardViewHidden = false
    /// Temporary copy of defaults that user might change in new game popover.
    var defaultsBeforeShowingNewGamePopover: [DefaultKey: Any]? // TODO: This could be a struct easily enough, and then we could be Equatable.
    /// Whether the game mode should be timed or practice.
    var interfaceMode: InterfaceMode = .timed

    /// Possible game modes on iPad; the int values are the respective indexes of the segmented control
    enum InterfaceMode: Int {
        case timed = 0
        case practice = 1
    }
}
