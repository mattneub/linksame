import UIKit
@testable import LinkSame

final class MockReceiver<T>: Receiver {
    var thingsReceived: [T] = []

    func receive(_ thingReceived: T) async {
        thingsReceived.append(thingReceived)
    }
}

final class MockReceiverPresenter<T, U>: UIViewController, ReceiverPresenter {
    var statesPresented = [U]()
    var thingsReceived: [T] = []

    func present(_ state: U) async {
        statesPresented.append(state)
    }

    func receive(_ thingReceived: T) async {
        thingsReceived.append(thingReceived)
    }
}

final class MockProcessor<T, U, V>: Processor {
    var thingsReceived: [T] = []

    var presenter: (any ReceiverPresenter<V, U>)?

    func receive(_ thingReceived: T) async {
        thingsReceived.append(thingReceived)
    }
}
