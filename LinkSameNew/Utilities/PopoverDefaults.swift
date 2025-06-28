/// Reducer that turns a dictionary of popover defaults to a struct and vice versa.
struct PopoverDefaults: Equatable {
    let lastStage: Int?
    let size: String?
    let style: String?
}
extension PopoverDefaults {
    /// Given a defaults dictionary, initialize the struct.
    init(defaultsDictionary dict: [DefaultKey: Any]) {
        self.lastStage = dict[.lastStage] as? Int
        self.size = dict[.size] as? String
        self.style = dict[.style] as? String
    }

    /// Given the struct, produce a defaults dictionary.
    var toDefaultsDictionary: [DefaultKey: Any] {
        [.lastStage: lastStage as Any, .size: size as Any, .style: style as Any]
    }
}
