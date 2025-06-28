import Foundation
@testable import LinkSame

@MainActor
final class MockBoardProcessor: BoardProcessorType {

    var methodsCalled = [String]()
    var _stageNumber = -1
    var _view = MockBoardView(columns: 1, rows: 1)
    var grid = Grid(columns: 1, rows: 1)
    var _deckAtStartOfStage = [String]()
    var show: Bool?
    var score: Int = -1

    var view: BoardView {
        _view
    }

    var deckAtStartOfStage: [String] {
        methodsCalled.append(#function)
        return _deckAtStartOfStage
    }

    func createAndDealDeck() {
        methodsCalled.append(#function)
        _deckAtStartOfStage = ["brand new deck"]
    }

    func populateFrom(oldGrid: Grid, deckAtStartOfStage: [String]) {
        methodsCalled.append(#function)
        self.grid = oldGrid
        self._deckAtStartOfStage = deckAtStartOfStage
    }

    func restartStage() async throws {
        methodsCalled.append(#function)
    }

    func showHint(_ show: Bool) async {
        methodsCalled.append(#function)
        self.show = show
    }

    func shuffle() {
        methodsCalled.append(#function)
    }

    func stageNumber() -> Int {
        methodsCalled.append(#function)
        return _stageNumber
    }


    func setStageNumber(_ stageNumber: Int) {
        methodsCalled.append(#function)
        self._stageNumber = stageNumber
    }

    func unhilite() async {
        methodsCalled.append(#function)
    }

}
