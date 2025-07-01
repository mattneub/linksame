import Foundation
@testable import LinkSame

@MainActor
final class MockScoreKeeper: ScoreKeeperType {

    var delegate: (any LinkSame.ScoreKeeperDelegate)?

    var score: Int = -1
    var methodsCalled = [String]()

    func didBecomeActive() {
        methodsCalled.append(#function)
    }

    func userMadeLegalMove() async {
        methodsCalled.append(#function)
    }

    func userAskedForShuffle() async {
        methodsCalled.append(#function)
    }

    func userAskedForHint() async {
        methodsCalled.append(#function)
    }

    func userRestartedStage() async {
        methodsCalled.append(#function)
    }

    func stopTimer() async {
        methodsCalled.append(#function)
    }

    func pauseTimer() async {
        methodsCalled.append(#function)
    }

    func restartTimerIfPaused() async {
        methodsCalled.append(#function)
    }
}
