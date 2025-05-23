@testable import LinkSame
import Testing
import UIKit
import SnapshotTesting

@MainActor
struct MyRightLabelTests {
    @Test("MyRightLabel looks correct")
    func myRightLabel() {
        let subject = MyRightLabel()
        subject.frame = CGRect(origin: .zero, size: .init(width: 200, height: 100))
        subject.backgroundColor = .yellow
        subject.text = "TESTING"
        subject.textAlignment = .right
        assertSnapshot(of: subject, as: .image(traits: .init(userInterfaceStyle: .light)))
    }
}
