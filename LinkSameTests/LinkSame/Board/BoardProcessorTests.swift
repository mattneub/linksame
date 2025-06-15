import UIKit
@testable import LinkSame
import Testing
import WaitWhile

@MainActor
struct BoardProcessorTests {
    @Test("populate: populates grid from old grid, sets deckAtStartOfStage")
    func populate() throws {
        let subject = BoardProcessor(gridSize: (2,3))
        var grid = Grid(columns: 2, rows: 3)
        let piece = Piece(picName: "howdy", frame: .zero)
        grid[column: 1, row: 1] = piece
        subject.populateFrom(oldGrid: grid, deckAtStartOfStage: ["hello"])
        let gridPiece = try #require(subject.grid[column: 1, row: 1])
        #expect(gridPiece.picName == "howdy")
        #expect(gridPiece.x == 1) // has proper knowledge of position
        #expect(gridPiece.y == 1)
        #expect(subject.grid[column: 0, row: 0] == nil) // good enough, no need to check them all
        #expect(subject.deckAtStartOfStage == ["hello"])
    }
}
