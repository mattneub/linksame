@testable import LinkSame
import Testing
import UIKit

@MainActor
struct AppDelegateTests {
    @Test("bootstrap: registers expected defaults")
    func bootstrap() throws {
        let persistence = MockPersistence()
        services.persistence = persistence
        let subject = try #require(UIApplication.shared.delegate as? AppDelegate)
        subject.bootstrap()
        #expect(persistence.methodsCalled == ["register(_:)"])
        #expect(persistence.dict?[.size] as? String == "Easy")
        #expect(persistence.dict?[.style] as? String == "Snacks")
        #expect(persistence.dict?[.lastStage] as? Int == 8)
        #expect(persistence.dict?.keys.count == 3)
    }
}
