@testable import LinkSame
import Foundation

@MainActor
final class MockPersistence: PersistenceType {
    var methodsCalled = [String]()
    var dict: [DefaultKey: Any]?

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
        return 0
    }
    
    func loadString(forKey key: DefaultKey) -> String {
        methodsCalled.append(#function)
        return ""
    }
    
    func loadData(forKey key: DefaultKey) -> Data? {
        methodsCalled.append(#function)
        return nil
    }
    
    func save(_ value: Any, forKey key: DefaultKey) {
        methodsCalled.append(#function)
    }
    
    func loadAsDictionary(_ keys: [DefaultKey]) -> [DefaultKey: Any] {
        methodsCalled.append(#function)
        return [:]
    }
    
    func saveIndividually(_ dictionary: [DefaultKey: Any]) {
        methodsCalled.append(#function)
    }
    

}
