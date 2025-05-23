@testable import LinkSame
import Testing
import UIKit

@MainActor
struct RangeReplaceableCollectionTests {
    @Test("remove(object:): removes the first equivalent object from itself")
    func remove() {
        var subject = [1, 2, 3, 2]
        subject.remove(object: 2)
        #expect(subject == [1, 3, 2])
    }

    @Test("remove(object:): removes the first equivalent object from itself, using identity")
    func removeIdentity() {
        let v1 = UIView()
        let v2 = UIView()
        let v3 = UIView()
        var subject = [v1, v2, v3, v2]
        subject.remove(object: v2)
        #expect(subject == [v1, v3, v2])
    }

    @Test("remove(object:): does nothing if no equivalent object is present")
    func removeNotPresent() {
        var subject = [1, 2, 3, 2]
        subject.remove(object: 4)
        #expect(subject == [1, 2, 3, 2])
    }
}
