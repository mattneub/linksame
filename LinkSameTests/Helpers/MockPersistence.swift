@testable import LinkSame
import Foundation

@MainActor
final class MockPersistence: PersistenceType {
    var methodsCalled = [String]()
    var dict: [DefaultKey: Any]?
    var int = 0
    var string: [String] = []
    var keys = [DefaultKey]()
    var value: Any?

    func register(_ dictionary: [DefaultKey: Any]) {
        methodsCalled.append(#function)
        self.dict = dictionary
    }
    
    func loadDictionary<ValueType>(forKey key: DefaultKey) -> [String: ValueType]? {
        methodsCalled.append(#function)
        return nil
    }
    
    func loadBool(forKey key: DefaultKey) -> Bool {
        methodsCalled.append(#function)
        return false
    }
    
    func loadInt(forKey key: DefaultKey) -> Int {
        methodsCalled.append(#function)
        self.keys.append(key)
        return int
    }
    
    func loadString(forKey key: DefaultKey) -> String {
        methodsCalled.append(#function)
        self.keys.append(key)
        if self.string.count > 0 {
            return self.string.removeFirst()
        } else {
            return ""
        }
    }
    
    func loadData(forKey key: DefaultKey) -> Data? {
        methodsCalled.append(#function)
        return nil
    }
    
    func save(_ value: Any, forKey key: DefaultKey) {
        methodsCalled.append(#function)
        self.value = value
        self.keys.append(key)
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
