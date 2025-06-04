@testable import LinkSame

final class MockDismissalDelegate: NewGamePopoverDismissalButtonDelegate {
    var methodsCalled = [String]()

    func cancelNewGame() {
        methodsCalled.append(#function)
    }
    func startNewGame() {
        methodsCalled.append(#function)
    }
}
