@testable import LinkSame
import Testing
import UIKit

@MainActor
struct PieceTests {
    @Test("equality between two pieces")
    func equalityPiecePiece() {
        let piece1 = Piece(picName: "hey", column: 1, row: 1)
        let piece2 = Piece(picName: "hey", column: 2, row: 2)
        let piece3 = Piece(picName: "hey", column: 1, row: 1)
        #expect(piece1 == piece3)
        #expect(piece1 != piece2)
        #expect(piece2 != piece3)
    }

    @Test("equality between piece reducer and piece")
    func equalityPieceReducerPiece() {
        let piece1 = PieceReducer(picName: "hey", column: 1, row: 1)
        let piece2 = Piece(picName: "hey", column: 2, row: 2)
        let piece3 = Piece(picName: "hey", column: 1, row: 1)
        #expect(piece1 == piece3)
        #expect(!(piece1 == piece2)) // interestingly, != doesn't exist merely because == does
    }

    @Test("equality between piece and piece reducer")
    func equalityPiecePieceReducer() {
        let piece1 = Piece(picName: "hey", column: 1, row: 1)
        let piece2 = PieceReducer(picName: "hey", column: 2, row: 2)
        let piece3 = PieceReducer(picName: "hey", column: 1, row: 1)
        #expect(piece1 == piece3)
        #expect(!(piece1 == piece2)) // ditto
    }

    @Test("Piece is correctly initialized from reducer")
    func reducerToPiece() {
        let piece = Piece(piece: .init(picName: "hey", column: 1, row: 2))
        #expect(piece.picName == "hey")
        #expect(piece.column == 1)
        #expect(piece.row == 2)
    }

    @Test("Piece toReducer correctly generates reducer")
    func pieceToReducer() {
        let piece = Piece(picName: "hey", column: 1, row: 2).toReducer
        #expect(piece.picName == "hey")
        #expect(piece.column == 1)
        #expect(piece.row == 2)
    }
}
