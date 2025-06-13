import Foundation

/// Simple single-action timer. If it times out, it calls the given handler. Alternatively,
/// it can be cancelled in which case all activity just stops dead. A CancelableTimer cannot be
/// reused; if you want to repeat a timer, just make a new timer. Note that releasing a timer reference
/// cancels the timer.
actor CancelableTimer {
    /// The timer workhorse: a task that simply sleeps through the requested `interval` and then
    /// calls back the delegate — unless, of course, the cancelable timer is cancelled.
    private var timerTask: Task<(), any Error>?

    /// Create the timer and start timing.
    /// - Parameter interval: The interval; if the given time (in seconds) elapses without
    /// the timer being cancelled, the timeout handler is called.
    /// - Parameter timeOutHandler: Handler that will be called if the timer times out (completes).
    init(interval: Double, timeOutHandler: @escaping @Sendable () async -> ()) {
        timerTask = Task {
            print("starting timer with interval \(interval)")
            try await Task.sleep(for: .seconds(interval))
            await timeOutHandler()
        }
    }

    /// Cancel the timer.
    func cancel() {
        timerTask?.cancel()
    }

    deinit {
        timerTask?.cancel()
        print("farewell from timer")
    }
}
