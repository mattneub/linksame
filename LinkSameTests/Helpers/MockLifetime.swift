@testable import LinkSame
import Combine

@MainActor
final class MockLifetime: LifetimeType {
    var didBecomeActivePublisher = PassthroughSubject<Void, Never>()
    var didEnterBackgroundPublisher = PassthroughSubject<Void, Never>()
    var methodsCalled = [String]()

    func didBecomeActive() {
        methodsCalled.append(#function)
    }
    
    func didEnterBackground() {
        methodsCalled.append(#function)
    }
    
}
