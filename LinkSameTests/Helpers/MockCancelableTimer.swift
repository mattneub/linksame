import Foundation
@testable import LinkSame

actor MockCancelableTimer: CancelableTimerType {
    var interval: Double?
    var methodsCalled = [String]()

    nonisolated(unsafe) var isRunning: Bool = false

    init(interval: Double, timeOutHandler: @escaping @Sendable () async -> ()) {
        self.interval = interval
    }
    
    func cancel() {
        methodsCalled.append(#function)
    }
}
