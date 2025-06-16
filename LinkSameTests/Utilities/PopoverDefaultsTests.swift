import Foundation
@testable import LinkSame
import Testing

@MainActor
struct PopoverDefaultsTests {
    @Test("PopoverDefaults struct round trips with popover defaults dictionary")
    func popoverDefaults() throws {
        let subject = try #require(PopoverDefaults(defaultsDictionary: [
            .lastStage: 5,
            .style: "Cool",
            .size: "Tiny"
        ]))
        #expect(subject.lastStage == 5)
        #expect(subject.style == "Cool")
        #expect(subject.size == "Tiny")
        let dictionary = subject.toDefaultsDictionary
        #expect(dictionary[.lastStage] as? Int == 5)
        #expect(dictionary[.style] as? String == "Cool")
        #expect(dictionary[.size] as? String == "Tiny")
    }
}
