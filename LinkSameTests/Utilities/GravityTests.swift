@testable import LinkSame
import Testing
import Foundation

@MainActor
struct GravityTests {
    let subject = Gravity()

    @Test("gravity down works as expected")
    func gravityDown() {
        let stageNumber = 1 // down
        var grid = Grid(columns: 2, rows: 3)
        grid[column:0, row: 0] = "manny"
        grid[column:0, row: 1] = "moe"
        grid[column:1, row: 0] = "harpo"
        grid[column:1, row: 1] = "groucho"
        grid[column:1, row: 2] = "chico"
        let movenda = subject.exerciseGravity(grid: &grid, stageNumber: stageNumber)
        // the top of the moved column is now vacant
        #expect(grid[Slot(0,0)] == nil)
        // the moved pieces have new correct addresses
        #expect(grid[Slot(0,1)] == PieceReducer(picName: "manny", column: 0, row: 1))
        #expect(grid[Slot(0,2)] == PieceReducer(picName: "moe", column: 0, row: 2))
        // these pieces are unmoved
        #expect(grid[Slot(1,0)] == PieceReducer(picName: "harpo", column: 1, row: 0))
        #expect(grid[Slot(1,1)] == PieceReducer(picName: "groucho", column: 1, row: 1))
        #expect(grid[Slot(1,2)] == PieceReducer(picName: "chico", column: 1, row: 2))
        // movenda describes the actual moves performed, in the order in which they must be performed
        #expect(movenda == [
            .init(piece: .init(picName: "moe", column: 0, row: 1), newSlot: .init(0, 2)),
            .init(piece: .init(picName: "manny", column: 0, row: 0), newSlot: .init(0, 1)),
        ])
    }
}
