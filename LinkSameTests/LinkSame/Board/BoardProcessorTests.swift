import UIKit
@testable import LinkSame
import Testing
import WaitWhile

@MainActor
struct BoardProcessorTests {
    let persistence = MockPersistence()
    let boardView = MockReceiverPresenter<BoardEffect, BoardState>()
    let subject = BoardProcessor(gridSize: (columns: 2, rows: 3))
    let gravity = MockGravity()
    let delegate = MockBoardDelegate()

    init() {
        services.persistence = persistence
        subject.presenter = boardView
        subject.gravity = gravity
        subject.delegate = delegate
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
        grid[column: 1, row: 1] = "howdy"
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
    }

    @Test("receive tapped: reaches two hilited pieces, trivially not a match, unhilited")
    func receiveTappedTwoHilitedNoMatch() async throws {
        let piece = PieceReducer(picName: "howdy", column: 0, row: 0)
        subject.state.hilitedPieces = [piece]
        let piece2 = PieceReducer(picName: "yoho", column: 0, row: 0)
        await subject.receive(.tapped(piece2))
        #expect(subject.state.hilitedPieces.isEmpty)
        // first the view is told to hilite both, then it is told to hilite neither
        #expect(boardView.statesPresented.count == 2)
        #expect(boardView.statesPresented.first?.hilitedPieces == [piece, piece2])
        #expect(boardView.statesPresented.last?.hilitedPieces == [])
        #expect(delegate.methodsCalled.isEmpty)
    }

    // okay, now we get into the heart of the app, the logic of board analysis

    @Test("receive tapped: reaches two hilited pieces, topologically not a match, unhilited")
    func receiveTappedTwoHilitedMatchButNotLegalPair() async throws {
        subject.grid[column: 0, row: 0] = "howdy"
        let piece = PieceReducer(picName: "yoho", column: 1, row: 0)
        subject.grid[column: 1, row: 0] = "yoho"
        let piece2 = PieceReducer(picName: "yoho", column: 0, row: 1)
        subject.grid[column: 0, row: 1] = "yoho"
        subject.grid[column: 1, row: 1] = "howdy"
        subject.state.hilitedPieces = [piece]
        await subject.receive(.tapped(piece2))
        // they have the same name, but they are diagonal and blocked, no legal path
        #expect(subject.state.hilitedPieces.isEmpty)
        #expect(boardView.statesPresented.count == 2)
        #expect(boardView.statesPresented.first?.hilitedPieces == [piece, piece2])
        #expect(boardView.statesPresented.last?.hilitedPieces == [])
        #expect(subject.grid[column: 1, row: 0] == piece)
        #expect(subject.grid[column: 0, row: 1] == piece2)
        #expect(delegate.methodsCalled.isEmpty)
    }

    // incidentally test developer double tap, just the once
    @Test(
        "receive tapped: reaches two hilited pieces, topologically a match, two segments, unhilited and removed",
        arguments: [1,2]
    )
    func receiveTappedTwoHilitedMatchLegalPairTwoSegments(which: Int) async throws {
        subject.grid[column: 0, row: 0] = "howdy"
        let piece = PieceReducer(picName: "yoho", column: 1, row: 0)
        subject.grid[column: 1, row: 0] = "yoho"
        let piece2 = PieceReducer(picName: "yoho", column: 0, row: 1)
        subject.grid[column: 0, row: 1] = "yoho"
        if which == 1 { // normal single tap on second piece
            subject.state.hilitedPieces = [piece2]
            await subject.receive(.tapped(piece))
        } else { // developer double-tap
            await subject.hint() // tee-hee, just a sneaky way of generating the legal path
            await subject.receive(.doubleTappedPiece)
        }
        #expect(subject.state.hilitedPieces.isEmpty)
        #expect(boardView.statesPresented.count == 2)
        #expect(boardView.statesPresented.first?.hilitedPieces == [piece2, piece])
        #expect(boardView.statesPresented.last?.hilitedPieces == [])
        #expect(subject.grid[column: 1, row: 0] == nil)
        #expect(subject.grid[column: 0, row: 1] == nil)
        #expect(boardView.thingsReceived.contains(.remove(piece: piece)))
        #expect(boardView.thingsReceived.contains(.remove(piece: piece2)))
        // and we flashed the path
        let expectedPath = [Slot(0, 1), Slot(1, 1), Slot(1, 0)]
        #expect(boardView.thingsReceived.contains(.illuminate(path: expectedPath)))
        #expect(boardView.thingsReceived.contains(.unilluminate))
        #expect(delegate.methodsCalled.isEmpty)
    }

    @Test("receive tapped: reaches two hilited pieces, topologically a match, three segments, unhilited and removed")
    func receiveTappedTwoHilitedMatchLegalPairThreeSegments() async throws {
        let piece = PieceReducer(picName: "yoho", column: 0, row: 0)
        subject.grid[column: 0, row: 0] = "yoho"
        subject.grid[column: 0, row: 1] = "howdy"
        let piece2 = PieceReducer(picName: "yoho", column: 0, row: 2)
        subject.grid[column: 0, row: 2] = "yoho"
        subject.grid[column: 1, row: 1] = "hello"
        subject.state.hilitedPieces = [piece]
        await subject.receive(.tapped(piece2))
        #expect(subject.state.hilitedPieces.isEmpty)
        #expect(boardView.statesPresented.count == 2)
        #expect(boardView.statesPresented.first?.hilitedPieces == [piece, piece2])
        #expect(boardView.statesPresented.last?.hilitedPieces == [])
        #expect(subject.grid[column: 0, row: 0] == nil)
        #expect(subject.grid[column: 0, row: 2] == nil)
        #expect(boardView.thingsReceived.contains(.remove(piece: piece)))
        #expect(boardView.thingsReceived.contains(.remove(piece: piece2)))
        // and we flashed the path — and the path is the shorter path, which goes outside the
        // left grid bounds, rather than going all the way around the piece at (1, 1)
        let expectedPath = [Slot(0, 0), Slot(-1, 0), Slot(-1, 2), Slot(0, 2)]
        #expect(boardView.thingsReceived.contains(.illuminate(path: expectedPath)))
        #expect(boardView.thingsReceived.contains(.unilluminate))
        #expect(delegate.methodsCalled.isEmpty)
    }

    @Test("receive tapped: reaches two hilited pieces, topologically a match, three segments, unhilited and removed")
    func receiveTappedTwoHilitedMatchLegalPairThreeSegments2() async throws {
        // same as the preceding but flipped horizontally
        let piece = PieceReducer(picName: "yoho", column: 1, row: 0)
        subject.grid[column: 1, row: 0] = "yoho"
        subject.grid[column: 0, row: 1] = "howdy"
        let piece2 = PieceReducer(picName: "yoho", column: 1, row: 2)
        subject.grid[column: 1, row: 2] = "yoho"
        subject.grid[column: 1, row: 1] = "hello"
        subject.state.hilitedPieces = [piece]
        await subject.receive(.tapped(piece2))
        #expect(subject.state.hilitedPieces.isEmpty)
        #expect(boardView.statesPresented.count == 2)
        #expect(boardView.statesPresented.first?.hilitedPieces == [piece, piece2])
        #expect(boardView.statesPresented.last?.hilitedPieces == [])
        #expect(subject.grid[column: 1, row: 0] == nil)
        #expect(subject.grid[column: 1, row: 2] == nil)
        #expect(boardView.thingsReceived.contains(.remove(piece: piece)))
        #expect(boardView.thingsReceived.contains(.remove(piece: piece2)))
        // and we flashed the path — and the path is the shorter path, which goes outside the
        // right grid bounds, rather than going all the way around the piece at (0, 1)
        let expectedPath = [Slot(1, 0), Slot(2, 0), Slot(2, 2), Slot(1, 2)]
        #expect(boardView.thingsReceived.contains(.illuminate(path: expectedPath)))
        #expect(boardView.thingsReceived.contains(.unilluminate))
        #expect(delegate.methodsCalled.isEmpty)
    }

    @Test("receive tapped: reaches two hilited pieces, match, last pair! unhilited, removed, call delegate stageEnded")
    func receiveTappedTwoHilitedMatchLegalPairLastPair() async throws {
        // same as the preceding but no other pieces except tapped pieces
        let piece = PieceReducer(picName: "yoho", column: 1, row: 0)
        subject.grid[column: 1, row: 0] = "yoho"
        let piece2 = PieceReducer(picName: "yoho", column: 1, row: 2)
        subject.grid[column: 1, row: 2] = "yoho"
        subject.state.hilitedPieces = [piece]
        await subject.receive(.tapped(piece2))
        #expect(subject.state.hilitedPieces.isEmpty)
        #expect(boardView.statesPresented.count == 2)
        #expect(boardView.statesPresented.first?.hilitedPieces == [piece, piece2])
        #expect(boardView.statesPresented.last?.hilitedPieces == [])
        #expect(subject.grid[column: 1, row: 0] == nil)
        #expect(subject.grid[column: 1, row: 2] == nil)
        #expect(boardView.thingsReceived.contains(.remove(piece: piece)))
        #expect(boardView.thingsReceived.contains(.remove(piece: piece2)))
        let expectedPath = [Slot(1, 0), Slot(1, 2)]
        #expect(boardView.thingsReceived.contains(.illuminate(path: expectedPath)))
        #expect(boardView.thingsReceived.contains(.unilluminate))
        #expect(delegate.methodsCalled == ["stageEnded()"])
    }

    @Test("receive tapped: exercises gravity, calls presenter move")
    func receiveTappedGravity() async {
        let piece = PieceReducer(picName: "yoho", column: 1, row: 0)
        subject.grid[column: 1, row: 0] = "yoho"
        subject.grid[column: 0, row: 1] = "howdy"
        let piece2 = PieceReducer(picName: "yoho", column: 1, row: 2)
        subject.grid[column: 1, row: 2] = "yoho"
        subject.grid[column: 1, row: 1] = "hello"
        let movenda: [Movendum] = [.init(piece: .init(picName: "movenda", column: 0, row: 1), newSlot: .init(0,2))]
        gravity.movenda = movenda
        subject.state.hilitedPieces = [piece]
        await subject.receive(.tapped(piece2))
        #expect(gravity.methodsCalled == ["exerciseGravity(grid:stageNumber:)"])
        #expect(boardView.thingsReceived.contains(.move(movenda)))
    }

    @Test("shuffle: unhilites and presents, unilluminates, turns user interaction off and on, rewrites grid, sends corresponding transition")
    func shuffle() async throws {
        subject.grid[column: 1, row: 0] = "yoho"
        subject.grid[column: 0, row: 1] = "yoho"
        subject.grid[column: 1, row: 2] = "teehee"
        subject.grid[column: 1, row: 1] = "teehee"
        subject.state.hilitedPieces = [PieceReducer(picName: "yoho", column: 1, row: 0)]
        await subject.shuffle()
        #expect(subject.state.hilitedPieces == [])
        #expect(boardView.statesPresented.first?.hilitedPieces == [])
        #expect(boardView.thingsReceived.first == .unilluminate)
        let gridPieces = subject.grid.grid.flatMap {$0}.compactMap {$0}
        #expect(gridPieces.count == 4)
        let picNames = gridPieces.map { $0.picName }
        let slots = gridPieces.map { Slot(column: $0.column, row: $0.row) }
        #expect(picNames.sorted() == ["teehee", "teehee", "yoho", "yoho"])
        #expect(Set(slots) == [Slot(column: 1, row: 0), Slot(column: 0, row: 1), Slot(column: 1, row: 2), Slot(column: 1, row: 1)])
        #expect(boardView.thingsReceived.count == 7)
        #expect(boardView.thingsReceived.contains(.userInteraction(false)))
        #expect(boardView.thingsReceived.contains(.userInteraction(true)))
        var effectPieces = [PieceReducer]()
        var effectPix = [String]()
        for thing in boardView.thingsReceived {
            if case .transition(let piece, let picName) = thing {
                effectPieces.append(piece)
                effectPix.append(picName)
            }
        }
        #expect(effectPieces.count == 4)
        #expect(effectPix.count == 4)
        #expect(Set(effectPieces) == [
            PieceReducer(picName: "yoho", column: 1, row: 0),
            PieceReducer(picName: "yoho", column: 0, row: 1),
            PieceReducer(picName: "teehee", column: 1, row: 2),
            PieceReducer(picName: "teehee", column: 1, row: 1),
        ])
        let resultantPieces = zip(effectPieces, effectPix).map {
            PieceReducer(picName: $1, column: $0.column, row: $0.row)
        }
        #expect(Set(resultantPieces) == Set(gridPieces))
    }
}

final class MockBoardDelegate: BoardDelegate {
    var methodsCalled = [String]()

    func stageEnded() {
        methodsCalled.append(#function)
    }
}
