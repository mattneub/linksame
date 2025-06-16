import Combine

/// Protocol describing the public face of our Lifetime object, so we can mock it for testing.
@MainActor
protocol LifetimeType {
    // Publishers that anyone can subscribe to.
    var didBecomeActivePublisher: PassthroughSubject<Void, Never> {get}
    var didEnterBackgroundPublisher: PassthroughSubject<Void, Never> {get}
    var willEnterForegroundPublisher: PassthroughSubject<Void, Never> {get}
    var willResignActivePublisher: PassthroughSubject<Void, Never> {get}

    // Methods that the scene delegate can call.
    func didBecomeActive()
    func didEnterBackground()
    func willEnterForeground()
    func willResignActive()
}

/// Service that acts as a bridge between scene delegate lifetime events and publishers that anyone
/// can subscribe to. In this way we avoid having to use the notification center to hear about
/// lifetime events.
@MainActor
final class Lifetime {
    let didBecomeActivePublisher = PassthroughSubject<Void, Never>()
    let didEnterBackgroundPublisher = PassthroughSubject<Void, Never>()
    let willEnterForegroundPublisher = PassthroughSubject<Void, Never>()
    let willResignActivePublisher = PassthroughSubject<Void, Never>()

    func didBecomeActive() {
        didBecomeActivePublisher.send()
    }

    func didEnterBackground() {
        didEnterBackgroundPublisher.send()
    }

    func willEnterForeground() {
        willEnterForegroundPublisher.send()
    }

    func willResignActive() {
        willResignActivePublisher.send()
    }
}

extension Lifetime: LifetimeType {}
