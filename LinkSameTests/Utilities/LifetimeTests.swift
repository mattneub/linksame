@testable import LinkSame
import Testing
import Foundation
import WaitWhile

struct LifetimeTests {
    let subject = Lifetime()

    @Test("didBecomeActive: sends on the didBecomeActivePublisher")
    func didBecomeActive() async {
        var valueReceived = false
        Task {
            try? await Task.sleep(for: .seconds(0.1))
            subject.didBecomeActive()
        }
        let values = Observations { subject.didBecomeActivePublisher }
        let task = Task {
            for await _ in values.dropFirst() {
                valueReceived = true
            }
        }
        #expect(valueReceived == false)
        await #while(valueReceived == false)
        #expect(valueReceived == true)
        task.cancel()
    }

    @Test("didEnterBackground: sends on the didEnterBackgroundPublisher")
    func didEnterBackground() async {
        var valueReceived = false
        Task {
            try? await Task.sleep(for: .seconds(0.1))
            subject.didEnterBackground()
        }
        let values = Observations { subject.didEnterBackgroundPublisher }
        let task = Task {
            for await _ in values.dropFirst() {
                valueReceived = true
            }
        }
        #expect(valueReceived == false)
        await #while(valueReceived == false)
        #expect(valueReceived == true)
        task.cancel()
    }

    @Test("willEnterForeground: sends on the willEnterForegroundPublisher")
    func willEnterForeground() async {
        var valueReceived = false
        Task {
            try? await Task.sleep(for: .seconds(0.1))
            subject.willEnterForeground()
        }
        let values = Observations { subject.willEnterForegroundPublisher }
        let task = Task {
            for await _ in values.dropFirst() {
                valueReceived = true
            }
        }
        #expect(valueReceived == false)
        await #while(valueReceived == false)
        #expect(valueReceived == true)
        task.cancel()
    }

    @Test("willResignActive: sends on the willResignActivePublisher")
    func willResignActive() async {
        var valueReceived = false
        Task {
            try? await Task.sleep(for: .seconds(0.1))
            subject.willResignActive()
        }
        let values = Observations { subject.willResignActivePublisher }
        let task = Task {
            for await _ in values.dropFirst() {
                valueReceived = true
            }
        }
        #expect(valueReceived == false)
        await #while(valueReceived == false)
        #expect(valueReceived == true)
        task.cancel()
    }
}
