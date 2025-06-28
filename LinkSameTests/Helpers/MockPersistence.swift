@testable import LinkSame
import Foundation

@MainActor
final class MockPersistence: PersistenceType {
    var methodsCalled = [String]()

    var dict: [DefaultKey: Any]? // for both loadAsDictionary and saveIndividually

    // after a load... call, the method called and the key
    var loads = [(String, DefaultKey)]()

    // after a save, the key(s)
    var saveKeys = [DefaultKey]()
    // after a save, the value(s)
    var savedValues = [Any]()

    // the backing store of key-value pairs: we are imitating user defaults here
    var values = [DefaultKey: Any]()

    func register(_ dictionary: [DefaultKey: Any]) {
        methodsCalled.append(#function)
        self.dict = dictionary
    }
    
    func loadDictionary<ValueType>(forKey key: DefaultKey) -> [String: ValueType]? {
        methodsCalled.append(#function)
        loads.append((#function, key))
        return values[key] as? [String: ValueType]
    }
    
    func loadBool(forKey key: DefaultKey) -> Bool {
        methodsCalled.append(#function)
        loads.append((#function, key))
        return values[key] as? Bool ?? false
    }
    
    func loadInt(forKey key: DefaultKey) -> Int {
        methodsCalled.append(#function)
        loads.append((#function, key))
        return values[key] as? Int ?? -1000
    }
    
    func loadString(forKey key: DefaultKey) -> String? {
        methodsCalled.append(#function)
        loads.append((#function, key))
        return values[key] as? String
    }

    func loadData(forKey key: DefaultKey) -> Data? {
        methodsCalled.append(#function)
        loads.append((#function, key))
        return values[key] as? Data
    }
    
    func save(_ value: Any, forKey key: DefaultKey) {
        methodsCalled.append(#function)
        saveKeys.append((key))
        savedValues.append(value)
        values[key] = value
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
