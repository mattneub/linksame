import UIKit
@testable import LinkSame

final class MockPathView: PathView {
    var thingsReceived = [PathEffect]()

    override func receive(_ effect: PathEffect) async {
        thingsReceived.append(effect)
    }

    override func draw(_ rect: CGRect) {}
}
