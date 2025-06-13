import Foundation
@testable import LinkSame

@MainActor
final class MockBoardProcessor: BoardProcessorType {

    var methodsCalled = [String]()
    var _stageNumber = -1
    var _view = MockBoardView()

    var stageNumber: Int {
        get {
            return _stageNumber
        }
        set {
            _stageNumber = newValue
        }
    }

    var view: BoardView {
        _view
    }

    func createAndDealDeck() {
        methodsCalled.append(#function)
    }
}
