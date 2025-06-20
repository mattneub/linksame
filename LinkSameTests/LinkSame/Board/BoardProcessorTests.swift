import UIKit
@testable import LinkSame
import Testing
import WaitWhile

@MainActor
struct BoardProcessorTests {
    let persistence = MockPersistence()
    let boardView = MockReceiverPresenter<BoardEffect, BoardState>()
    let subject = BoardProcessor(gridSize: (columns: 2, rows: 3))

    init() {
        services.persistence = persistence
        subject.presenter = boardView
    }

    @Test("initializer: creates grid")
    func initializer() {
        let subject = BoardProcessor(gridSize: (columns: 2, rows: 3))
        #expect(subject.grid.columns == 2)
        #expect(subject.grid.rows == 3)
        #expect(subject.columns == 2)
        #expect(subject.rows == 3)
        #expect(subject.grid.grid.flatMap{$0}.count == 6)
        #expect(subject.grid.grid.flatMap{$0}.allSatisfy { $0 == nil })
    }

    @Test("createAndDealDeck: creates the deck based on persistence and grid size, sends .insert effect for each piece")
    func createAndDealDeck() async throws {
        persistence.string = ["Snacks"]
        let subject = BoardProcessor(gridSize: (2, 18)) // tee-hee
        subject.presenter = boardView
        try await subject.createAndDealDeck()
        #expect(persistence.methodsCalled == ["loadString(forKey:)"])
        #expect(persistence.loadKeys == [.style])
        let deck = subject.deckAtStartOfStage
        #expect(deck.count == 36)
        let pix = deck.map { $0.picName }
        #expect(Set(pix).count == 9) // 9 basic images
        #expect(Set(pix) == ["21", "22", "23", "24", "25", "26", "27", "28", "29"])
        for pic in ["21", "22", "23", "24", "25", "26", "27", "28", "29"] {
            #expect(pix.count(where: {$0 == pic}) == 4)
        }
        var gridPieces = [PieceReducer?]()
        // "undeal"!
        for column in 0 <<< 2 {
            for row in 0 <<< 18 {
                gridPieces.append(subject.grid[column: column, row: row])
            }
        }
        #expect(gridPieces.compactMap {$0}.map { $0.picName } == deck.map { $0.picName }.reversed())
        // every grid piece knows its own position
        for column in 0 ..< 2 {
            for row in 0 ..< 18 {
                let piece = subject.grid[column: column, row: row]!
                #expect((piece.column, piece.row) == (column, row))
            }
        }
        // what we said to the presenter
        #expect(boardView.thingsReceived.count == 36)
        var expectedEffects = [BoardEffect]()
        for column in 0 ..< 2 {
            for row in 0 ..< 18 {
                let piece = subject.grid[column: column, row: row]!
                expectedEffects.append(.insert(piece: piece))
            }
        }
        #expect(expectedEffects.count == 36)
        #expect(boardView.thingsReceived == expectedEffects)
    }

    @Test("createAndDealDeck: creates the deck based on persistence and grid size, sends .insert effect for each piece")
    func createAndDealDeck2() async throws {
        persistence.string = ["Animals"]
        let subject = BoardProcessor(gridSize: (4, 11))
        subject.presenter = boardView
        try await subject.createAndDealDeck()
        #expect(persistence.methodsCalled == ["loadString(forKey:)"])
        #expect(persistence.loadKeys == [.style])
        let deck = subject.deckAtStartOfStage
        #expect(deck.count == 44)
        let pix = deck.map { $0.picName }
        #expect(Set(pix).count == 11) // 9 basic images plus two additional
        #expect(Set(pix) == ["11", "12", "13", "14", "15", "16", "17", "18", "19", "110", "111"])
        for pic in ["11", "12", "13", "14", "15", "16", "17", "18", "19", "110", "111"] {
            #expect(pix.count(where: {$0 == pic}) == 4)
        }
        var gridPieces = [PieceReducer?]()
        // "undeal"!
        for column in 0 <<< 4 {
            for row in 0 <<< 11 {
                gridPieces.append(subject.grid[column: column, row: row])
            }
        }
        #expect(gridPieces.compactMap {$0}.map { $0.picName } == deck.map { $0.picName}.reversed())
        // every grid piece knows its own position
        for column in 0 ..< 4 {
            for row in 0 ..< 11 {
                let piece = subject.grid[column: column, row: row]!
                #expect((piece.column, piece.row) == (column, row))
            }
        }
        // what we said to the presenter
        #expect(boardView.thingsReceived.count == 44)
        var expectedEffects = [BoardEffect]()
        for column in 0 ..< 4 {
            for row in 0 ..< 11 {
                let piece = subject.grid[column: column, row: row]!
                expectedEffects.append(.insert(piece: piece))
            }
        }
        #expect(expectedEffects.count == 44)
        #expect(boardView.thingsReceived == expectedEffects)
    }

    @Test("populate: populates grid from old grid, sets deckAtStartOfStage")
    func populate() async throws {
        let subject = BoardProcessor(gridSize: (2,3))
        subject.presenter = boardView
        var grid = Grid(columns: 2, rows: 3)
        let piece = PieceReducer(picName: "howdy", column: 1, row: 1)
        grid[column: 1, row: 1] = piece
        await subject.populateFrom(oldGrid: grid, deckAtStartOfStage: [.init(picName: "hello")])
        let gridPiece = try #require(subject.grid[column: 1, row: 1])
        #expect(gridPiece.picName == "howdy")
        #expect(gridPiece.column == 1) // has proper knowledge of position
        #expect(gridPiece.row == 1)
        #expect(boardView.thingsReceived.count == 1)
        #expect(boardView.thingsReceived.first == .insert(piece: piece))
        #expect(subject.grid[column: 0, row: 0] == nil) // good enough, no need to check them all
        #expect(subject.deckAtStartOfStage == [.init(picName: "hello")])
    }

    @Test("receive tapped: if hilitedPieces contains piece, it is removed; present state")
    func receiveTappedHilited() async throws {
        let piece = PieceReducer(picName: "howdy", column: 0, row: 0)
        subject.state.hilitedPieces = [piece]
        await subject.receive(.tapped(piece))
        #expect(boardView.statesPresented.count == 1)
        #expect(boardView.statesPresented[0].hilitedPieces.isEmpty)
        await #while(boardView.thingsReceived.count < 2)
        #expect(boardView.thingsReceived.count == 2)
        #expect(boardView.thingsReceived[0] == .userInteraction(false))
        #expect(boardView.thingsReceived[1] == .userInteraction(true))
    }

    @Test("receive tapped: if hilitedPieces does not contain piece, it is added; present state")
    func receiveTappedNotHilited() async throws {
        let piece = PieceReducer(picName: "howdy", column: 0, row: 0)
        subject.state.hilitedPieces = []
        await subject.receive(.tapped(piece))
        #expect(boardView.statesPresented.count == 1)
        #expect(boardView.statesPresented[0].hilitedPieces[0] == piece)
        await #while(boardView.thingsReceived.count < 2)
        #expect(boardView.thingsReceived.count == 2)
        #expect(boardView.thingsReceived[0] == .userInteraction(false))
        #expect(boardView.thingsReceived[1] == .userInteraction(true))
        // TODO: test that if we now contain two hilited pieces, we do a pair check
    }
}
