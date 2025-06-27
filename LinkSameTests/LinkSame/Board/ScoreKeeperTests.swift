@testable import LinkSame
import Testing
import WaitWhile

@MainActor
struct ScoreKeeperTests {
    let delegate = MockScoreKeeperDelegate()

    init() {
        services.cancelableTimer = MockCancelableTimer.self
    }

    @Test("initializer behaves correctly")
    func initialize() {
        let subject = ScoreKeeper(score: 10, delegate: delegate)
        #expect(subject.score == 10)
        #expect(subject.scoreAtStartOfStage == 10)
        #expect(subject.delegate === delegate)
    }

    @Test("timerTimedOut: makes new timer, decrements score, calls delegate")
    func timerTimedOut() async throws {
        let oldTimer = MockCancelableTimer(interval: 1) {}
        let subject = ScoreKeeper(score: 20, delegate: delegate)
        subject.timer = oldTimer
        #expect(subject.timer === oldTimer)
        await subject.timerTimedOut()
        #expect(subject.timer !== oldTimer)
        let newTimer = try #require(subject.timer as? MockCancelableTimer)
        #expect(await newTimer.interval == 10)
        #expect(subject.score == 19)
        #expect(delegate.methodsCalled == ["scoreChanged(_:)"])
        #expect(delegate.score?.score == subject.score)
        #expect(delegate.score?.direction == .down)
    }

    @Test("stopTimer: cancels timer")
    func stopTimer() async throws {
        let subject = ScoreKeeper(score: 20, delegate: delegate)
        let timer = MockCancelableTimer(interval: 20, timeOutHandler: {})
        subject.timer = timer
        await subject.stopTimer()
        #expect(await timer.methodsCalled == ["cancel()"])
    }

    @Test("userAskedForHint: makes new timer, decreases score by 10, calls delegate")
    func userAskedForHint() async throws {
        let oldTimer = MockCancelableTimer(interval: 1) {}
        let subject = ScoreKeeper(score: 20, delegate: delegate)
        subject.timer = oldTimer
        #expect(subject.timer === oldTimer)
        await subject.userAskedForHint()
        #expect(subject.timer !== oldTimer)
        let newTimer = try #require(subject.timer as? MockCancelableTimer)
        #expect(await newTimer.interval == 10)
        #expect(subject.score == 10)
        #expect(delegate.methodsCalled == ["scoreChanged(_:)"])
        #expect(delegate.score?.score == subject.score)
        #expect(delegate.score?.direction == .down)
    }

    @Test("userAskedForShuffle: makes new timer, decreases score by 20, calls delegate")
    func userAskedForShuffle() async throws {
        let oldTimer = MockCancelableTimer(interval: 1) {}
        let subject = ScoreKeeper(score: 20, delegate: delegate)
        subject.timer = oldTimer
        #expect(subject.timer === oldTimer)
        await subject.userAskedForShuffle()
        #expect(subject.timer !== oldTimer)
        let newTimer = try #require(subject.timer as? MockCancelableTimer)
        #expect(await newTimer.interval == 10)
        #expect(subject.score == 0)
        #expect(delegate.methodsCalled == ["scoreChanged(_:)"])
        #expect(delegate.score?.score == subject.score)
        #expect(delegate.score?.direction == .down)
    }

    

    @Test("userMadeLegalMove: makes new timer, increases score, calls delegate")
    func userMadeLegalMove() async throws {
        let oldTimer = MockCancelableTimer(interval: 1) {}
        let subject = ScoreKeeper(score: 10, delegate: delegate)
        subject.timer = oldTimer
        #expect(subject.timer === oldTimer)
        await subject.userMadeLegalMove()
        #expect(subject.timer !== oldTimer)
        let newTimer = try #require(subject.timer as? MockCancelableTimer)
        #expect(await newTimer.interval == 10)
        #expect(subject.score >= 11)
        #expect(delegate.methodsCalled == ["scoreChanged(_:)"])
        #expect(delegate.score?.score == subject.score)
        #expect(delegate.score?.direction == .up)
    }
}

final class MockScoreKeeperDelegate: ScoreKeeperDelegate {
    var methodsCalled = [String]()
    var score: Score?

    func scoreChanged(_ score: Score) async {
        methodsCalled.append(#function)
        self.score = score
    }
    

}
