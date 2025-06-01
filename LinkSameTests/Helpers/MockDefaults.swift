@testable import LinkSame
import Foundation

final class MockDefaults: DefaultsType {
    var key: String?
    var methodsCalled = [String]()
    var bool: Bool? = nil
    var int: Int? = nil
    var string: String? = nil
    var data: Data? = nil
    var dict: [String: Any]?
    var keys = [String]()
    var any: Any?

    func register(defaults: [String: Any]) {
        methodsCalled.append(#function)
        dict = defaults
    }
    
    func dictionary(forKey: String) -> [String: Any]? {
        methodsCalled.append(#function)
        key = forKey
        return dict
    }
    
    func bool(forKey: String) -> Bool {
        methodsCalled.append(#function)
        key = forKey
        return bool ?? false
    }
    
    func integer(forKey: String) -> Int {
        methodsCalled.append(#function)
        key = forKey
        return int ?? 0
    }
    
    func string(forKey: String) -> String? {
        methodsCalled.append(#function)
        key = forKey
        return string
    }
    
    func data(forKey: String) -> Data? {
        methodsCalled.append(#function)
        key = forKey
        return data
    }
    
    func set(_ value: Any?, forKey: String) {
        methodsCalled.append(#function)
        key = forKey
        self.any = value
    }
    
    func dictionaryWithValues(forKeys keys: [String]) -> [String: Any] {
        methodsCalled.append(#function)
        self.keys = keys
        return dict ?? [:]
    }

    func setValuesForKeys(_ dict: [String: Any]) {
        methodsCalled.append(#function)
        self.dict = dict
    }
}

