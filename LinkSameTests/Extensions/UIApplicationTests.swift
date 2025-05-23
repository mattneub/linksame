@testable import LinkSame
import Testing
import UIKit

@MainActor
struct UIApplicationTests {
    @Test("userInteraction: turns window user interaction off and on as expected")
    func userInteraction() {
        let window = makeWindow()
        #expect(window.isUserInteractionEnabled == true)
        UIApplication.userInteraction(false)
        #expect(window.isUserInteractionEnabled == false)
        UIApplication.userInteraction(false)
        #expect(window.isUserInteractionEnabled == false)
        UIApplication.userInteraction(true)
        #expect(window.isUserInteractionEnabled == false)
        UIApplication.userInteraction(true)
        #expect(window.isUserInteractionEnabled == true)
    }
}
