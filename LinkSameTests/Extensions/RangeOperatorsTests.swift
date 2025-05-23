@testable import LinkSame
import Testing
import Foundation

@MainActor
struct RangeOperatorsTests {
    @Test(">>>: works")
    func rightTriple() {
        do {
            let subject = 100 >>> 90
            #expect(Array(subject) == [99, 98, 97, 96, 95, 94, 93, 92, 91, 90])
        }
        do {
            let subject = 5 >>> -5
            #expect(Array(subject) == [4, 3, 2, 1, 0, -1, -2, -3, -4, -5])
        }
    }

    @Test("<<<: is a synonym for ..<")
    func leftTriple() {
        let subject = 90 <<< 100
        #expect(Array(subject) == [90, 91, 92, 93, 94, 95, 96, 97, 98, 99])
    }
}
