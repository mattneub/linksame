import Observation

/// Protocol describing the public face of our Lifetime object, so we can mock it for testing.
protocol LifetimeType {
    // Publishers that anyone can subscribe to.
    var didBecomeActivePublisher: Void? { get }
    var didEnterBackgroundPublisher: Void? { get }
    var willEnterForegroundPublisher: Void? { get }
    var willResignActivePublisher: Void? { get }

    // Methods that the scene delegate can call.
    func didBecomeActive()
    func didEnterBackground()
    func willEnterForeground()
    func willResignActive()
}

/// Service that acts as a bridge between scene delegate lifetime events and publishers that anyone
/// can subscribe to. In this way we avoid having to use the notification center to hear about
/// lifetime events.
@Observable
final class Lifetime {
    var didBecomeActivePublisher: Void?
    var didEnterBackgroundPublisher: Void?
    var willEnterForegroundPublisher: Void?
    var willResignActivePublisher: Void?

    func didBecomeActive() {
        didBecomeActivePublisher = ()
    }

    func didEnterBackground() {
        didEnterBackgroundPublisher = ()
    }

    func willEnterForeground() {
        willEnterForegroundPublisher = ()
    }

    func willResignActive() {
        willResignActivePublisher = ()
    }
}

extension Lifetime: LifetimeType {}
