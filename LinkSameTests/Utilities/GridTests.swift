@testable import LinkSame
import Testing
import Foundation

@MainActor
struct GridTests {
    @Test("initializer: sets columns, rows, and empty (nil) two dimensional array of correct dimensions")
    func initializer() {
        let subject = Grid(columns: 2, rows: 3)
        #expect(subject.columns == 2)
        #expect(subject.rows == 3)
        #expect(subject.grid.count == 2)
        for column in subject.grid {
            #expect(column.count == 3)
        }
    }

    @Test("subscript: correctly addresses piece")
    func subscripting() throws {
        var subject = Grid(columns: 2, rows: 3)
        for (columnIndex, column) in subject.grid.enumerated() {
            for (rowIndex, piece) in column.enumerated() {
                #expect(piece == nil)
                subject[column: columnIndex, row: rowIndex] = PieceReducer(picName: "\(columnIndex) \(rowIndex)", column: 1, row: 1)
            }
        }
        for columnIndex in 0..<2 {
            for rowIndex in 0..<3 {
                let piece = try #require(subject[column: columnIndex, row: rowIndex])
                let name = piece.picName.split(separator: " ")
                #expect(name.count == 2)
                #expect(name[0] == String(columnIndex))
                #expect(name[1] == String(rowIndex))
            }
        }
    }
}
