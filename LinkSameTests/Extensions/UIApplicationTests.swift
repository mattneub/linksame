@testable import LinkSame
import Testing
import UIKit

@MainActor
struct UIApplicationTests {
    @Test("userInteraction: turns window user interaction off and on as expected")
    func userInteraction() {
        let window = makeWindow()
        UIApplication.interactionLevel = 0 // because you never know what previous tests have done
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
