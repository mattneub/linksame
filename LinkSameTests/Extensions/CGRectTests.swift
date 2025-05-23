@testable import LinkSame
import Testing
import Foundation

@MainActor
struct CGRectTests {
    @Test("center: returns center point")
    func center() {
        let subject = CGRect(x: 10, y: 10, width: 30, height: 40)
        let result = subject.center
        #expect(result == CGPoint(x: 25, y: 30))
    }

    @Test("centeredRectOfSize: returns rect with same center and given size")
    func centeredRectOfSize() {
        let subject = CGRect(x: 10, y: 10, width: 30, height: 40)
        let desiredSize = CGSize(width: 20, height: 10)
        let result = subject.centeredRectOfSize(desiredSize)
        #expect(result.center == subject.center)
        #expect(result.size == desiredSize)
    }

    @Test("centeredRectOfSize: returns rect with same center and given size when given size is bigger")
    func centeredRectOfSizeBigger() {
        let subject = CGRect(x: 10, y: 10, width: 30, height: 40)
        let desiredSize = CGSize(width: 200, height: 100)
        let result = subject.centeredRectOfSize(desiredSize)
        #expect(result.center == subject.center)
        #expect(result.size == desiredSize)
    }
}
