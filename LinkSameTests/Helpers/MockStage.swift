import Foundation
@testable import LinkSame

@MainActor
final class MockStage: StageType {
    var score: Int = -1
    var methodsCalled = [String]()

    func didBecomeActive() {
        methodsCalled.append(#function)
    }
}
