import Foundation
@testable import LinkSame

@MainActor
final class MockBoardProcessor: BoardProcessorType {

    var methodsCalled = [String]()
    var _stageNumber = -1
    var _view = MockBoardView(columns: 1, rows: 1)
    var grid = Grid(columns: 1, rows: 1)
    var deckAtStartOfStage = [PieceReducer]()

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

    func populateFrom(oldGrid: Grid, deckAtStartOfStage: [PieceReducer]) {
        methodsCalled.append(#function)
        self.grid = oldGrid
        self.deckAtStartOfStage = deckAtStartOfStage
    }
}
