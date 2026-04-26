@testable import LinkSame
import Observation

@Observable
final class MockLifetime: LifetimeType {

    var willResignActivePublisher: Void?
    var didBecomeActivePublisher: Void?
    var didEnterBackgroundPublisher: Void?
    var willEnterForegroundPublisher: Void?
    var methodsCalled = [String]()

    func didBecomeActive() {
        methodsCalled.append(#function)
    }
    
    func didEnterBackground() {
        methodsCalled.append(#function)
    }

    func willEnterForeground() {
        methodsCalled.append(#function)
    }

    func willResignActive() {
        methodsCalled.append(#function)
    }
}
