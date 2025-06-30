@testable import LinkSame
import Testing
import UIKit

@MainActor
struct TransitionProviderTests {
    @Test("perform: adds the given transition to the given layer")
    func perform() async {
        let subject = TransitionProvider()
        let transition = CATransition()
        let layer = MyLayer()
        await subject.performTransition(transition: transition, layer: layer)
        // and the fact that we get here at all proves that we resumed the continuation
        #expect(layer.animation === transition)
        #expect(layer.key == "transition")
    }
}

private final class MyLayer: CALayer {
    var animation: CAAnimation?
    var key: String?

    override func add(_ anim: CAAnimation, forKey key: String?) {
        self.animation = anim
        self.key = key
        super.add(anim, forKey: key)
    }
}
