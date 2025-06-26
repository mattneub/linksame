@testable import LinkSame
import Testing
import Foundation
import WaitWhile

@MainActor
final class CancelableTimerTests {
    var subject: CancelableTimer?

    @Test("timer that times out calls the timeout handler")
    func timeOut() async {
        nonisolated(unsafe) var timedOut = false
        @Sendable func setTimedOut() async {
            timedOut = true
        }
        subject = CancelableTimer(interval: 0.1, timeOutHandler: setTimedOut)
        try? await Task.sleep(for: .seconds(0.3))
        #expect(timedOut == true)
    }

    @Test("cancel: cancels the timer task")
    func cancel() async {
        subject = CancelableTimer(interval: 10, timeOutHandler: {})
        try? await Task.sleep(for: .seconds(0.3))
        await subject?.cancel()
        #expect(await subject?.timerTask?.isCancelled == true)
    }
}
