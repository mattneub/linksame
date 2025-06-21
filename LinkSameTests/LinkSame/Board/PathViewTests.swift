import UIKit
@testable import LinkSame
import Testing
import WaitWhile
import SnapshotTesting

@MainActor
struct PathViewTests {
    let subject = PathView()

    @Test("receive illuminate: sets points")
    func illuminate() async {
        await subject.receive(.illuminate([CGPoint(x: 2, y: 2)]))
        #expect(subject.points == [CGPoint(x: 2, y: 2)])
    }

    @Test("receive unilluminate: empties points")
    func unilluminate() async {
        subject.points = [CGPoint(x: 2, y: 2)]
        await subject.receive(.unilluminate)
        #expect(subject.points.isEmpty)
    }

    @Test("drawing looks correct")
    func draw() async {
        subject.backgroundColor = .yellow
        subject.frame = CGRect(x: 0, y: 0, width: 300, height: 300)
        await subject.receive(.illuminate(
            [CGPoint(x: 100, y: 100), CGPoint(x: 200, y: 100), CGPoint(x: 200, y: 200)]
        ))
        assertSnapshot(of: subject, as: .image)
    }
}
