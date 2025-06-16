import UIKit
@testable import LinkSame

@MainActor
final class MockApplication: ApplicationType {
    var applicationState: UIApplication.State = .active
    static var methodsCalled = [String]()
    static var bools = [Bool]()

    static func userInteraction(_ interactionOn: Bool) {
        methodsCalled.append(#function)
        bools.append(interactionOn)
    }
}
