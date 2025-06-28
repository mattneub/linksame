import Foundation

/// Keys used by the app to express the name of a default. The first three are also text that appears
/// to the user in the interface.
enum DefaultKey: String {
    case size = "Size"
    case style = "Style"
    case lastStage = "Stages"
    case scores = "Scoresv2"
    case boardData = "boardDatav2"
    // exists only in case `.init(rawValue:)` cannot return any real value
    case badKey = "this should never happen!"
}

/// Protocol expressing the public face of our Persistence struct. To the public, all keys are DefaultKey cases.
/// Exists so that Persistence can be mocked.
@MainActor
protocol PersistenceType {
    /// Enter the given pairs into the registration domain, to be used in case no value exists for the key.
    func register(_ dictionary: [DefaultKey: Any])

    /// Fetch the value for the given key, on the assumption that it is a dictionary of the given type.
    /// If it isn't, return nil.
    func loadDictionary<ValueType>(forKey key: DefaultKey) -> [String: ValueType]?

    /// Fetch the value for the given key, on the assumption that it is a Bool. If not, will be false.
    func loadBool(forKey key: DefaultKey) -> Bool

    /// Fetch the value for the given key, on the assumption that it is an Int. If not, will be zero.
    func loadInt(forKey key: DefaultKey) -> Int

    /// Fetch the value for the given key, on the assumption that it is a String. If not, will be nil.
    func loadString(forKey key: DefaultKey) -> String?

    /// Fetch the value for the given key, on the assumption that it is a Data. If not, will be nil.
    func loadData(forKey key: DefaultKey) -> Data?

    /// Store the given value under the given key. The value needs to be a type that can be stored
    /// in UserDefaults (a property list type).
    func save(_ value: Any, forKey key: DefaultKey)

    /// Fetch multiple values by the given keys, and assemble them into a dictionary.
    func loadAsDictionary(_ keys: [DefaultKey]) -> [DefaultKey: Any]

    /// Save multiple key/value pairs as individual defaults.
    func saveIndividually(_ dictionary: [DefaultKey: Any])
}

/// Gateway to persistent storage.
@MainActor
struct Persistence: PersistenceType {
    /// The UserDefaultsType object to talk to when fetching and storing. A mock can be injected here
    /// when testing.
    static var defaults: any UserDefaultsType = UserDefaults.standard

    func register(_ dictionary: [DefaultKey: Any]) {
        Self.defaults.register(defaults: dictionary.mapKeys { $0.rawValue })
    }

    func loadDictionary<ValueType>(forKey key: DefaultKey) -> [String: ValueType]? {
        Self.defaults.dictionary(forKey: key.rawValue) as? [String: ValueType]
    }

    func loadBool(forKey key: DefaultKey) -> Bool {
        Self.defaults.bool(forKey: key.rawValue)
    }

    func loadInt(forKey key: DefaultKey) -> Int {
        Self.defaults.integer(forKey: key.rawValue)
    }

    func loadString(forKey key: DefaultKey) -> String? {
        Self.defaults.string(forKey: key.rawValue)
    }

    func loadData(forKey key: DefaultKey) -> Data? {
        Self.defaults.data(forKey: key.rawValue)
    }

    func save(_ value: Any, forKey key: DefaultKey) {
        Self.defaults.set(value, forKey: key.rawValue)
    }

    func loadAsDictionary(_ keys: [DefaultKey]) -> [DefaultKey: Any] {
        let dictionary = Self.defaults.dictionaryWithValues(forKeys: keys.map { $0.rawValue })
        return dictionary.mapKeys { .init(rawValue: $0) ?? .badKey }
    }

    func saveIndividually(_ dictionary: [DefaultKey: Any]) {
        Self.defaults.setValuesForKeys(dictionary.mapKeys { $0.rawValue })
    }
}
