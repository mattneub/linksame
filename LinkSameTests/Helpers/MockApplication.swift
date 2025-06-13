import UIKit
@testable import LinkSame

@MainActor
final class MockApplication: ApplicationType {
    static var methodsCalled = [String]()
    static var bools = [Bool]()

    static func userInteraction(_ interactionOn: Bool) {
        methodsCalled.append(#function)
        bools.append(interactionOn)
    }
}
