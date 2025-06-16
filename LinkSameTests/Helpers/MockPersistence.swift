@testable import LinkSame
import Foundation

@MainActor
final class MockPersistence: PersistenceType {
    var methodsCalled = [String]()
    var dict: [DefaultKey: Any]?
    var int = 0
    var string: [String] = []
    var loadKeys = [DefaultKey]()
    var saveKeys = [DefaultKey]()
    var values = [Any]()
    var data: Data?
    var bool = false

    func register(_ dictionary: [DefaultKey: Any]) {
        methodsCalled.append(#function)
        self.dict = dictionary
    }
    
    func loadDictionary<ValueType>(forKey key: DefaultKey) -> [String: ValueType]? {
        methodsCalled.append(#function)
        self.loadKeys.append(key)
        return nil
    }
    
    func loadBool(forKey key: DefaultKey) -> Bool {
        methodsCalled.append(#function)
        self.loadKeys.append(key)
        return bool
    }
    
    func loadInt(forKey key: DefaultKey) -> Int {
        methodsCalled.append(#function)
        self.loadKeys.append(key)
        return int
    }
    
    func loadString(forKey key: DefaultKey) -> String {
        methodsCalled.append(#function)
        self.loadKeys.append(key)
        if self.string.count > 0 {
            return self.string.removeFirst()
        } else {
            return ""
        }
    }
    
    func loadData(forKey key: DefaultKey) -> Data? {
        methodsCalled.append(#function)
        self.loadKeys.append(key)
        return self.data
    }
    
    func save(_ value: Any, forKey key: DefaultKey) {
        methodsCalled.append(#function)
        self.values.append(value)
        self.saveKeys.append(key)
    }
    
    func loadAsDictionary(_ keys: [DefaultKey]) -> [DefaultKey: Any] {
        methodsCalled.append(#function)
        return dict ?? [:]
    }
    
    func saveIndividually(_ dictionary: [DefaultKey: Any]) {
        methodsCalled.append(#function)
        self.dict = dictionary
    }
}
