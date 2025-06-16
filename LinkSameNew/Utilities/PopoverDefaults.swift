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
