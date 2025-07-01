import Foundation

protocol CancelableTimerType: Actor {
    init(interval: Double, timeOutHandler: @escaping @Sendable () async -> ())
    var isRunning: Bool { get }
    func cancel()
}

/// Simple single-action timer. If it times out, it calls the given handler. Alternatively,
/// it can be cancelled in which case all activity just stops dead. A CancelableTimer cannot be
/// reused; if you want to repeat a timer, just make a new timer. Note that releasing a timer reference
/// cancels the timer.
actor CancelableTimer: CancelableTimerType {
    /// The timer workhorse: a task that simply sleeps through the requested `interval` and then
    /// calls back the delegate — unless, of course, the cancelable timer is cancelled.
    var timerTask: Task<(), any Error>?

    /// Whether the timer is running. A nil timer is not running, and a cancelled timer is not running.
    var isRunning: Bool {
        timerTask?.isCancelled == false
    }

    /// Create the timer and start timing.
    /// - Parameter interval: The interval; if the given time (in seconds) elapses without
    /// the timer being cancelled, the timeout handler is called.
    /// - Parameter timeOutHandler: Handler that will be called if the timer times out (completes).
    init(interval: Double, timeOutHandler: @escaping @Sendable () async -> ()) {
        timerTask = Task {
            print("starting timer with interval \(interval)")
            try await Task.sleep(for: .seconds(interval))
            print("timer calling timeOutHander")
            await timeOutHandler()
        }
    }

    /// Cancel the timer.
    func cancel() {
        timerTask?.cancel()
        print("timer stopped")
    }

    /// Nilify the timer; this exists purely for testing purposes.
    func nilify() {
        timerTask?.cancel()
        timerTask = nil
    }

    deinit { // A released timer cancels its task, and thus tears down in good order.
        timerTask?.cancel()
        print("timer stopped, farewell from timer")
    }
}
