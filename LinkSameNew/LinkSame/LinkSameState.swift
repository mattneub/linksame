/// State to be presented by the processor to the presenter for visible representation in the interface.
/// Also contains state being maintained by the processor which may be meaningless to the presenter.
struct LinkSameState: Equatable {
    /// Whether the board view should be hidden or displayed.
    var boardViewHidden = false
    /// Temporary copy of the particular defaults that user might change in the new game popover.
    var defaultsBeforeShowingNewGamePopover: PopoverDefaults?
    /// Whether the game mode should be timed or practice.
    var interfaceMode: InterfaceMode = .timed

    /// Possible game modes on iPad; the int values are the respective indexes of the segmented control
    enum InterfaceMode: Int {
        case timed = 0
        case practice = 1
    }
}

/// Reducer that turns a dictionary of popover defaults to a struct and vice versa.
struct PopoverDefaults: Equatable {
    let lastStage: Int
    let size: String
    let style: String
}
extension PopoverDefaults {
    /// Given a defaults dictionary, initialize the struct.
    init?(defaultsDictionary dict: [DefaultKey: Any]) {
        guard let lastStage = dict[.lastStage] as? Int else { return nil }
        guard let size = dict[.size] as? String else { return nil }
        guard let style = dict[.style] as? String else { return nil }
        self.lastStage = lastStage
        self.size = size
        self.style = style
    }

    /// Given the struct, produce a defaults dictionary.
    var toDefaultsDictionary: [DefaultKey: Any] {
        [.lastStage: lastStage, .size: size, .style: style]
    }
}

