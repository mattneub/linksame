@testable import LinkSame
import Testing
import Foundation

@MainActor
struct PersistenceTests {
    let subject = Persistence()
    let defaults = MockDefaults()

    init() {
        Persistence.defaults = defaults
    }

    @Test("register: translates keys to strings and calls defaults register")
    func register() throws {
        subject.register([.size: "big"])
        #expect(defaults.methodsCalled == ["register(defaults:)"])
        #expect(defaults.dict?["Size"] as? String == "big")
        #expect(defaults.dict?.keys.count == 1)
    }

    @Test("loadDictionary: calls dictionaryForKey, return dict if exists as dictionary of given type, nil if not")
    func loadDictionary() {
        defaults.dict = ["hey": "ho"]
        let result: [String: String]? = subject.loadDictionary(forKey: .gameEnded)
        #expect(result == ["hey": "ho"])
        #expect(defaults.key == "gameEnded")
        #expect(defaults.methodsCalled == ["dictionary(forKey:)"])
        // wrong type
        defaults.dict = ["hey": 1]
        let result2: [String: String]? = subject.loadDictionary(forKey: .gameEnded)
        #expect(result2 == nil)
    }

    @Test("loadBool: calls boolForKey, returns bool value")
    func loadBool() {
        defaults.bool = true
        let result = subject.loadBool(forKey: .gameEnded)
        #expect(result == true)
        #expect(defaults.key == "gameEnded")
        #expect(defaults.methodsCalled == ["bool(forKey:)"])
    }

    @Test("loadInt: calls integerForKey, returns int value")
    func loadInt() {
        defaults.int = 42
        let result = subject.loadInt(forKey: .gameEnded)
        #expect(result == 42)
        #expect(defaults.key == "gameEnded")
        #expect(defaults.methodsCalled == ["integer(forKey:)"])
    }

    @Test("loadString: calls stringForKey, returns string value; if nil, returns empty string")
    func loadString() {
        defaults.string = "yoho"
        let result = subject.loadString(forKey: .gameEnded)
        #expect(result == "yoho")
        #expect(defaults.key == "gameEnded")
        #expect(defaults.methodsCalled == ["string(forKey:)"])
        // nil
        defaults.string = nil
        let result2 = subject.loadString(forKey: .gameEnded)
        #expect(result2 == "")
    }

    @Test("loadData: calls dataForKey, returns data value")
    func loadData() throws {
        defaults.data = "howdy".data(using: .utf8)
        let result = try #require(subject.loadData(forKey: .gameEnded))
        #expect(String(data: result, encoding: .utf8) == "howdy")
        #expect(defaults.key == "gameEnded")
        #expect(defaults.methodsCalled == ["data(forKey:)"])
        // nil
        defaults.data = nil
        let result2 = subject.loadData(forKey: .gameEnded)
        #expect(result2 == nil)
    }

    @Test("save: calls setForKey")
    func save() {
        subject.save(42, forKey: .gameEnded)
        #expect(defaults.key == "gameEnded")
        #expect(defaults.any as? Int == 42)
        #expect(defaults.methodsCalled == ["set(_:forKey:)"])
    }

    @Test("loadAsDictionary: calls dictionaryWithValuesForKeys")
    func loadAsDictionary() {
        defaults.dict = ["gameEnded": true, "boardDatav2": 42]
        let result = subject.loadAsDictionary([.gameEnded, .boardData])
        #expect(defaults.keys.contains(["gameEnded"]))
        #expect(defaults.keys.contains(["boardDatav2"]))
        #expect(defaults.keys.count == 2)
        #expect(defaults.methodsCalled == ["dictionaryWithValues(forKeys:)"])
        #expect(result[.gameEnded] as? Bool == true)
        #expect(result[.boardData] as? Int == 42)
        #expect(result.keys.count == 2)
    }

    @Test("loadAsDictionary: uses .badKey if string key has no match")
    func loadAsDictionaryBadKey() {
        defaults.dict = ["whatIsThis": true]
        let result = subject.loadAsDictionary([.gameEnded, .boardData])
        #expect(result[.badKey] as? Bool == true)
        #expect(result.keys.count == 1)
    }

    @Test("saveIndividually: calls setValuesForKeys")
    func saveIndividually() {
        subject.saveIndividually([.gameEnded: true, .boardData: 42])
        #expect(defaults.methodsCalled == ["setValuesForKeys(_:)"])
        #expect(defaults.dict?["gameEnded"] as? Bool == true)
        #expect(defaults.dict?["boardDatav2"] as? Int == 42)
        #expect(defaults.dict?.keys.count == 2)
    }
}

