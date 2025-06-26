import Foundation
@testable import LinkSame

actor MockCancelableTimer: CancelableTimerType {
    var interval: Double?
    var methodsCalled = [String]()

    init(interval: Double, timeOutHandler: @escaping @Sendable () async -> ()) {
        self.interval = interval
    }
    
    func cancel() {
        methodsCalled.append(#function)
    }
}
