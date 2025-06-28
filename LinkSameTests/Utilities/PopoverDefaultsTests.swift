import Foundation
@testable import LinkSame
import Testing

@MainActor
struct PopoverDefaultsTests {
    @Test("PopoverDefaults struct round trips with popover defaults dictionary")
    func popoverDefaults() throws {
        let subject = PopoverDefaults(defaultsDictionary: [
            .lastStage: 5,
            .style: "Cool",
            .size: "Tiny"
        ])
        #expect(subject.lastStage == 5)
        #expect(subject.style == "Cool")
        #expect(subject.size == "Tiny")
        let dictionary = subject.toDefaultsDictionary
        #expect(dictionary[.lastStage] as? Int == 5)
        #expect(dictionary[.style] as? String == "Cool")
        #expect(dictionary[.size] as? String == "Tiny")
        let popoverDefaults = PopoverDefaults(defaultsDictionary: dictionary)
        #expect(subject == popoverDefaults)
    }

    @Test("PopoverDefaults struct round trips with popover defaults dictionary with nil values")
    func popoverDefaultsNil() throws {
        let subject = PopoverDefaults(defaultsDictionary: [
            .lastStage: 5,
            .style: "Cool",
            .size: Optional<String>.none as Any
        ])
        #expect(subject.lastStage == 5)
        #expect(subject.style == "Cool")
        #expect(subject.size == nil)
        let dictionary = subject.toDefaultsDictionary
        #expect(dictionary[.lastStage] as? Int == 5)
        #expect(dictionary[.style] as? String == "Cool")
        #expect(dictionary[.size] as? String == nil)
        let popoverDefaults = PopoverDefaults(defaultsDictionary: dictionary)
        #expect(subject == popoverDefaults)
    }
}
