@testable import LinkSame
import Testing
import Foundation
import Combine
import WaitWhile

@MainActor
struct LifetimeTests {
    let subject = Lifetime()

    @Test("didBecomeActive: sends on the didBecomeActivePublisher")
    func didBecomeActive() async {
        let values = subject.didBecomeActivePublisher.values
        var valueReceived = false
        Task {
            try? await Task.sleep(for: .seconds(0.1))
            subject.didBecomeActive()
        }
        let task = Task.detached {
            for await _ in values {
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
        let values = subject.didEnterBackgroundPublisher.values
        var valueReceived = false
        Task {
            try? await Task.sleep(for: .seconds(0.1))
            subject.didEnterBackground()
        }
        let task = Task.detached {
            for await _ in values {
                valueReceived = true
            }
        }
        #expect(valueReceived == false)
        await #while(valueReceived == false)
        #expect(valueReceived == true)
        task.cancel()
    }
}
