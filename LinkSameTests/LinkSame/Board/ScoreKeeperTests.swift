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
    func initialize() async {
        let subject = ScoreKeeper(score: 10, delegate: delegate)
        #expect(subject.score == 10)
        #expect(subject.scoreAtStartOfStage == 10)
        #expect(subject.delegate === delegate)
        await #while(delegate.methodsCalled.isEmpty)
        #expect(delegate.methodsCalled == ["scoreChanged(_:)"])
        #expect(delegate.score?.score == subject.score)
        #expect(delegate.score?.direction == .up)
    }

    @Test("timerTimedOut: makes new timer, decrements score, calls delegate")
    func timerTimedOut() async throws {
        let oldTimer = MockCancelableTimer(interval: 1) {}
        let subject = ScoreKeeper(score: 20, delegate: delegate)
        await #while(delegate.methodsCalled.isEmpty)
        delegate.methodsCalled = []
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
        await #while(delegate.methodsCalled.isEmpty)
        delegate.methodsCalled = []
        let timer = MockCancelableTimer(interval: 20, timeOutHandler: {})
        subject.timer = timer
        await subject.stopTimer()
        #expect(await timer.methodsCalled == ["cancel()"])
    }

    @Test("userAskedForHint: makes new timer, decreases score by 10, calls delegate")
    func userAskedForHint() async throws {
        let oldTimer = MockCancelableTimer(interval: 1) {}
        let subject = ScoreKeeper(score: 20, delegate: delegate)
        await #while(delegate.methodsCalled.isEmpty)
        delegate.methodsCalled = []
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
        await #while(delegate.methodsCalled.isEmpty)
        delegate.methodsCalled = []
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
        await #while(delegate.methodsCalled.isEmpty)
        delegate.methodsCalled = []
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

    @Test("userRestartedStage: stops the timer, resets the score, calls delegate")
    func userRestartedStage() async throws {
        let subject = ScoreKeeper(score: 20, delegate: delegate)
        await #while(delegate.methodsCalled.isEmpty)
        delegate.methodsCalled = []
        let timer = MockCancelableTimer(interval: 20, timeOutHandler: {})
        subject.timer = timer
        subject.scoreAtStartOfStage = 200
        await subject.userRestartedStage()
        #expect(await timer.methodsCalled == ["cancel()"])
        #expect(subject.score == 200)
        #expect(delegate.methodsCalled == ["scoreChanged(_:)"])
        #expect(delegate.score?.score == subject.score)
        #expect(delegate.score?.direction == .up)
    }

    @Test("pauseTimer: stops the timer and records whether it was running")
    func pauseTimer() async {
        do { // no timer
            let subject = ScoreKeeper(score: 20, delegate: nil)
            subject.timer = nil
            await subject.pauseTimer()
            #expect(subject.timer == nil)
            #expect(subject.timerWasRunning == false)
        }
        do { // timer is not running
            let subject = ScoreKeeper(score: 20, delegate: nil)
            let timer = MockCancelableTimer(interval: 10, timeOutHandler: {})
            subject.timer = timer
            timer.isRunning = false
            await subject.pauseTimer()
            #expect(await timer.methodsCalled == ["cancel()"])
            #expect(subject.timer === timer)
            #expect(subject.timerWasRunning == false)
        }
        do { // timer is running
            let subject = ScoreKeeper(score: 20, delegate: nil)
            let timer = MockCancelableTimer(interval: 10, timeOutHandler: {})
            subject.timer = timer
            timer.isRunning = true
            await subject.pauseTimer()
            #expect(await timer.methodsCalled == ["cancel()"])
            #expect(subject.timer === timer)
            #expect(subject.timerWasRunning == true)
        }
    }

    @Test("restartTimerIfPaused: restarts the timer, but only if it was running")
    func restartTimerIfPaused() async throws {
        do { // timer was not running
            let oldTimer = MockCancelableTimer(interval: 1) {}
            let subject = ScoreKeeper(score: 20, delegate: nil)
            subject.timer = oldTimer
            subject.timerWasRunning = false
            await subject.restartTimerIfPaused()
            #expect(subject.timer === oldTimer)
            #expect(await oldTimer.methodsCalled.isEmpty)
        }
        do { // timer was running
            let oldTimer = MockCancelableTimer(interval: 1) {}
            let subject = ScoreKeeper(score: 20, delegate: nil)
            subject.timer = oldTimer
            subject.timerWasRunning = true
            await subject.restartTimerIfPaused()
            #expect(subject.timer !== oldTimer)
            let newTimer = try #require(subject.timer as? MockCancelableTimer)
            #expect(await newTimer.interval == 10)
        }
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
