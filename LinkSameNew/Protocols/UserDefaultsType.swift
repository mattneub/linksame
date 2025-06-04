import Foundation

/// Protocol listing the UserDefaults methods used by the Persistence struct.
/// Exists so that UserDefaults can be mocked.
protocol UserDefaultsType {
    func register(defaults: [String: Any])

    func dictionary(forKey: String) -> [String: Any]?

    func bool(forKey: String) -> Bool

    func integer(forKey: String) -> Int

    func string(forKey: String) -> String?

    func data(forKey: String) -> Data?

    func set(_: Any?, forKey: String)

    func dictionaryWithValues(forKeys: [String]) -> [String: Any]

    func setValuesForKeys(_: [String: Any])
}

/// Extension that conforms UserDefaults to the UserDefaultsType protocol.
extension UserDefaults: UserDefaultsType {}

