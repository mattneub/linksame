import Foundation
@testable import LinkSame

@MainActor
final class MockScoreKeeper: ScoreKeeperType {

    var score: Int = -1
    var methodsCalled = [String]()

    func didBecomeActive() {
        methodsCalled.append(#function)
    }

    func userMadeLegalMove() async {
        methodsCalled.append(#function)
    }

}
