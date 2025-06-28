import UIKit
@testable import LinkSame
import Testing
import WaitWhile

@MainActor
struct BoardProcessorTests {
    let persistence = MockPersistence()
    let presenter = MockReceiverPresenter<BoardEffect, BoardState>()
    let subject: BoardProcessor!
    let gravity = MockGravity()
    let delegate = MockBoardDelegate()
    let scoreKeeper = MockScoreKeeper()

    init() {
        subject = BoardProcessor(gridSize: (columns: 2, rows: 3), scoreKeeper: scoreKeeper)
        services.persistence = persistence
        subject.presenter = presenter
        subject.gravity = gravity
        subject.delegate = delegate
        subject.scoreKeeper = scoreKeeper
    }

    @Test("initializer: creates grid, sets scoreKeeper")
    func initializer() {
        let subject = BoardProcessor(gridSize: (columns: 2, rows: 3), scoreKeeper: scoreKeeper)
        #expect(subject.grid.columns == 2)
        #expect(subject.grid.rows == 3)
        #expect(subject.columns == 2)
        #expect(subject.rows == 3)
        #expect(subject.grid.grid.flatMap{$0}.count == 6)
        #expect(subject.grid.grid.flatMap{$0}.allSatisfy { $0 == nil })
        #expect(subject.scoreKeeper === scoreKeeper)
    }

    @Test("createAndDealDeck: creates the deck based on persistence and grid size, sends .insert effect for each piece")
    func createAndDealDeck() async throws {
        persistence.values = [.style: "Snacks"]
        let subject = BoardProcessor(gridSize: (2, 18), scoreKeeper: scoreKeeper) // tee-hee
        subject.presenter = presenter
        try await subject.createAndDealDeck()
        #expect(persistence.loads[0] == ("loadString(forKey:)", .style))
        let deck = subject.state.deckAtStartOfStage
        #expect(deck.count == 36)
        #expect(Set(deck).count == 9) // 9 basic images
        #expect(Set(deck) == ["21", "22", "23", "24", "25", "26", "27", "28", "29"])
        for pic in ["21", "22", "23", "24", "25", "26", "27", "28", "29"] {
            #expect(deck.count(where: {$0 == pic}) == 4)
        }
        var gridPieces = [PieceReducer?]()
        // "undeal"!
        for column in 0 <<< 2 {
            for row in 0 <<< 18 {
                gridPieces.append(subject.grid[column: column, row: row])
            }
        }
        #expect(gridPieces.compactMap {$0}.map { $0.picName } == deck.reversed())
        // what we said to the presenter
        #expect(presenter.thingsReceived.count == 36)
        var expectedEffects = [BoardEffect]()
        for column in 0 ..< 2 {
            for row in 0 ..< 18 {
                let piece = subject.grid[column: column, row: row]!
                expectedEffects.append(.insert(piece: piece))
            }
        }
        #expect(expectedEffects.count == 36)
        #expect(presenter.thingsReceived == expectedEffects)
    }

    @Test("createAndDealDeck: creates the deck based on persistence and grid size, sends .insert effect for each piece")
    func createAndDealDeck2() async throws {
        persistence.values = [.style: "Animals"]
        let subject = BoardProcessor(gridSize: (4, 11), scoreKeeper: scoreKeeper)
        subject.presenter = presenter
        try await subject.createAndDealDeck()
        #expect(persistence.loads[0] == ("loadString(forKey:)", .style))
        let deck = subject.state.deckAtStartOfStage
        #expect(deck.count == 44)
        #expect(Set(deck).count == 11) // 9 basic images plus two additional
        #expect(Set(deck) == ["11", "12", "13", "14", "15", "16", "17", "18", "19", "110", "111"])
        for pic in ["11", "12", "13", "14", "15", "16", "17", "18", "19", "110", "111"] {
            #expect(deck.count(where: {$0 == pic}) == 4)
        }
        var gridPieces = [PieceReducer?]()
        // "undeal"!
        for column in 0 <<< 4 {
            for row in 0 <<< 11 {
                gridPieces.append(subject.grid[column: column, row: row])
            }
        }
        #expect(gridPieces.compactMap {$0}.map { $0.picName } == deck.reversed())
        // what we said to the presenter
        #expect(presenter.thingsReceived.count == 44)
        var expectedEffects = [BoardEffect]()
        for column in 0 ..< 4 {
            for row in 0 ..< 11 {
                let piece = subject.grid[column: column, row: row]!
                expectedEffects.append(.insert(piece: piece))
            }
        }
        #expect(expectedEffects.count == 44)
        #expect(presenter.thingsReceived == expectedEffects)
    }

    @Test("deckAtStartOfStage: fetches state deckAtStartOfStage")
    func deckAtStartOfState() {
        subject.state.deckAtStartOfStage = ["howdy"]
        #expect(subject.deckAtStartOfStage == ["howdy"])
    }

    @Test("populate: populates grid from old grid, sets deckAtStartOfStage")
    func populate() async throws {
        let subject = BoardProcessor(gridSize: (2,3), scoreKeeper: scoreKeeper)
        subject.presenter = presenter
        var grid = Grid(columns: 2, rows: 3)
        let piece = PieceReducer(picName: "howdy", column: 1, row: 1)
        grid[column: 1, row: 1] = "howdy"
        await subject.populateFrom(oldGrid: grid, deckAtStartOfStage: ["hello"])
        let gridPiece = try #require(subject.grid[column: 1, row: 1])
        #expect(gridPiece.picName == "howdy")
        #expect(gridPiece.column == 1) // has proper knowledge of position
        #expect(gridPiece.row == 1)
        #expect(presenter.thingsReceived.count == 1)
        #expect(presenter.thingsReceived.first == .insert(piece: piece))
        #expect(subject.grid[column: 0, row: 0] == nil) // good enough, no need to check them all
        #expect(subject.state.deckAtStartOfStage == ["hello"])
    }

    @Test("receive tapped: if hilitedPieces contains piece, it is removed; present state")
    func receiveTappedHilited() async throws {
        let piece = PieceReducer(picName: "howdy", column: 0, row: 0)
        subject.state.hilitedPieces = [piece]
        await subject.receive(.tapped(piece))
        #expect(presenter.statesPresented.count == 1)
        #expect(presenter.statesPresented[0].hilitedPieces.isEmpty)
        await #while(presenter.thingsReceived.count < 2)
        #expect(presenter.thingsReceived.count == 2)
        #expect(presenter.thingsReceived[0] == .userInteraction(false))
        #expect(presenter.thingsReceived[1] == .userInteraction(true))
    }

    @Test("receive tapped: if hilitedPieces does not contain piece, it is added; present state")
    func receiveTappedNotHilited() async throws {
        let piece = PieceReducer(picName: "howdy", column: 0, row: 0)
        subject.state.hilitedPieces = []
        await subject.receive(.tapped(piece))
        #expect(presenter.statesPresented.count == 1)
        #expect(presenter.statesPresented[0].hilitedPieces[0] == piece)
        await #while(presenter.thingsReceived.count < 2)
        #expect(presenter.thingsReceived.count == 2)
        #expect(presenter.thingsReceived[0] == .userInteraction(false))
        #expect(presenter.thingsReceived[1] == .userInteraction(true))
    }

    @Test("receive tapped: reaches two hilited pieces, trivially not a match, unhilited")
    func receiveTappedTwoHilitedNoMatch() async throws {
        let piece = PieceReducer(picName: "howdy", column: 0, row: 0)
        subject.state.hilitedPieces = [piece]
        let piece2 = PieceReducer(picName: "yoho", column: 0, row: 0)
        await subject.receive(.tapped(piece2))
        #expect(subject.state.hilitedPieces.isEmpty)
        // first the view is told to hilite both, then it is told to hilite neither
        #expect(presenter.statesPresented.count == 2)
        #expect(presenter.statesPresented.first?.hilitedPieces == [piece, piece2])
        #expect(presenter.statesPresented.last?.hilitedPieces == [])
        #expect(delegate.methodsCalled.isEmpty)
        #expect(scoreKeeper.methodsCalled.isEmpty)
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
        #expect(presenter.statesPresented.count == 2)
        #expect(presenter.statesPresented.first?.hilitedPieces == [piece, piece2])
        #expect(presenter.statesPresented.last?.hilitedPieces == [])
        #expect(subject.grid[column: 1, row: 0] == piece)
        #expect(subject.grid[column: 0, row: 1] == piece2)
        #expect(delegate.methodsCalled.isEmpty)
        #expect(scoreKeeper.methodsCalled.isEmpty)
    }

    // incidentally test developer double tap, just the once
    @Test(
        "receive tapped: reaches two hilited pieces, topologically a match, two segments, unhilited and removed, tell scoreKeeper",
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
            subject.state.hintPath = [Slot(0, 1), Slot(1, 1), Slot(1, 0)]
            await subject.receive(.doubleTappedPiece)
        }
        #expect(subject.state.hilitedPieces.isEmpty)
        #expect(presenter.statesPresented.count == 2)
        #expect(presenter.statesPresented.first?.hilitedPieces == [piece2, piece])
        #expect(presenter.statesPresented.last?.hilitedPieces == [])
        #expect(subject.grid[column: 1, row: 0] == nil)
        #expect(subject.grid[column: 0, row: 1] == nil)
        #expect(presenter.thingsReceived.contains(.remove(piece: piece)))
        #expect(presenter.thingsReceived.contains(.remove(piece: piece2)))
        // and we flashed the path
        let expectedPath = [Slot(0, 1), Slot(1, 1), Slot(1, 0)]
        #expect(presenter.thingsReceived.contains(.illuminate(path: expectedPath)))
        #expect(presenter.thingsReceived.contains(.unilluminate))
        #expect(delegate.methodsCalled.isEmpty)
        // and we told the scorekeeper about it
        #expect(scoreKeeper.methodsCalled == ["userMadeLegalMove()"])
    }

    @Test("receive tapped: reaches two hilited pieces, topologically a match, three segments, unhilited and removed, tell scoreKeeper")
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
        #expect(presenter.statesPresented.count == 2)
        #expect(presenter.statesPresented.first?.hilitedPieces == [piece, piece2])
        #expect(presenter.statesPresented.last?.hilitedPieces == [])
        #expect(subject.grid[column: 0, row: 0] == nil)
        #expect(subject.grid[column: 0, row: 2] == nil)
        #expect(presenter.thingsReceived.contains(.remove(piece: piece)))
        #expect(presenter.thingsReceived.contains(.remove(piece: piece2)))
        // and we flashed the path — and the path is the shorter path, which goes outside the
        // left grid bounds, rather than going all the way around the piece at (1, 1)
        let expectedPath = [Slot(0, 0), Slot(-1, 0), Slot(-1, 2), Slot(0, 2)]
        #expect(presenter.thingsReceived.contains(.illuminate(path: expectedPath)))
        #expect(presenter.thingsReceived.contains(.unilluminate))
        #expect(delegate.methodsCalled.isEmpty)
        // and we told the scorekeeper about it
        #expect(scoreKeeper.methodsCalled == ["userMadeLegalMove()"])
    }

    @Test("receive tapped: reaches two hilited pieces, topologically a match, three segments, unhilited and removed, tell scoreKeeper")
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
        #expect(presenter.statesPresented.count == 2)
        #expect(presenter.statesPresented.first?.hilitedPieces == [piece, piece2])
        #expect(presenter.statesPresented.last?.hilitedPieces == [])
        #expect(subject.grid[column: 1, row: 0] == nil)
        #expect(subject.grid[column: 1, row: 2] == nil)
        #expect(presenter.thingsReceived.contains(.remove(piece: piece)))
        #expect(presenter.thingsReceived.contains(.remove(piece: piece2)))
        // and we flashed the path — and the path is the shorter path, which goes outside the
        // right grid bounds, rather than going all the way around the piece at (0, 1)
        let expectedPath = [Slot(1, 0), Slot(2, 0), Slot(2, 2), Slot(1, 2)]
        #expect(presenter.thingsReceived.contains(.illuminate(path: expectedPath)))
        #expect(presenter.thingsReceived.contains(.unilluminate))
        #expect(delegate.methodsCalled.isEmpty)
        // and we told the scorekeeper about it
        #expect(scoreKeeper.methodsCalled == ["userMadeLegalMove()"])
    }

    @Test("receive tapped: reaches two hilited pieces, match, last pair! unhilited, removed, call delegate stageEnded, tell scorekeeper")
    func receiveTappedTwoHilitedMatchLegalPairLastPair() async throws {
        // same as the preceding but no other pieces except tapped pieces
        let piece = PieceReducer(picName: "yoho", column: 1, row: 0)
        subject.grid[column: 1, row: 0] = "yoho"
        let piece2 = PieceReducer(picName: "yoho", column: 1, row: 2)
        subject.grid[column: 1, row: 2] = "yoho"
        subject.state.hilitedPieces = [piece]
        await subject.receive(.tapped(piece2))
        #expect(subject.state.hilitedPieces.isEmpty)
        #expect(presenter.statesPresented.count == 2)
        #expect(presenter.statesPresented.first?.hilitedPieces == [piece, piece2])
        #expect(presenter.statesPresented.last?.hilitedPieces == [])
        #expect(subject.grid[column: 1, row: 0] == nil)
        #expect(subject.grid[column: 1, row: 2] == nil)
        #expect(presenter.thingsReceived.contains(.remove(piece: piece)))
        #expect(presenter.thingsReceived.contains(.remove(piece: piece2)))
        let expectedPath = [Slot(1, 0), Slot(1, 2)]
        #expect(presenter.thingsReceived.contains(.illuminate(path: expectedPath)))
        #expect(presenter.thingsReceived.contains(.unilluminate))
        #expect(delegate.methodsCalled == ["stageEnded()"]) // *
        // and we told the scorekeeper about it
        #expect(scoreKeeper.methodsCalled == ["userMadeLegalMove()", "stopTimer()"])
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
        #expect(presenter.thingsReceived.contains(.move(movenda)))
    }

    @Test("receive tappedPathView: calls delegate userTappedPathView")
    func receiveTappedPathView() async {
        await subject.receive(.tappedPathView)
        #expect(delegate.methodsCalled == ["userTappedPathView()"])
    }

    @Test("restartStage: replaces the grid with deckAtStartOfStage, tells presenter to remove old pieces and insert new ones, tells scorekeeper")
    func restartStage() async throws {
        var deck = [String]()
        var oldPieces = [PieceReducer?]()
        for column in 0 ..< subject.columns {
            for row in 0 ..< subject.rows {
                subject.grid[column: column, row: row] = "old\(column)\(row)"
                oldPieces.append(subject.grid[column: column, row: row])
                deck.append("new\(column)\(row)")
            }
        }
        subject.state.deckAtStartOfStage = deck
        try await subject.restartStage()
        var newPieces = [PieceReducer?]()
        for column in 0 ..< subject.columns {
            for row in 0 ..< subject.rows {
                newPieces.append(subject.grid[column: column, row: row])
            }
        }
        var expected = [BoardEffect]()
        for pieces in zip(oldPieces.compactMap{$0}, newPieces.compactMap{$0}) {
            expected.append(.remove(piece: pieces.0))
            expected.append(.insert(piece: pieces.1))
        }
        #expect(presenter.thingsReceived == expected)
        #expect(scoreKeeper.methodsCalled == ["userRestartedStage()"])
    }

    @Test("showHint(false): removes hilite, sets path view tappable to false, unilluminates presenter")
    func showHintFalse() async {
        subject.state.hilitedPieces = [.init(picName: "hey")]
        subject.state.pathViewTappable = true
        await subject.showHint(false)
        #expect(subject.state.hilitedPieces == [])
        #expect(subject.state.pathViewTappable == false)
        #expect(presenter.statesPresented.first?.hilitedPieces == [])
        #expect(presenter.statesPresented.first?.pathViewTappable == false)
        #expect(presenter.thingsReceived == [.unilluminate])
    }

    @Test("showHint(true): removes hilite, sets path view tappable to true, illuminates hint path, tells scorekeeper")
    func showHintTrue() async {
        subject.grid[column: 0, row: 0] = "howdy"
        let piece = PieceReducer(picName: "yoho", column: 1, row: 0)
        subject.grid[column: 1, row: 0] = "yoho"
        let piece2 = PieceReducer(picName: "yoho", column: 0, row: 1)
        subject.grid[column: 0, row: 1] = "yoho"
        subject.state.hilitedPieces = [piece, piece2]
        subject.state.pathViewTappable = false
        await subject.showHint(true) // calculates hint path
        #expect(subject.state.hilitedPieces == [])
        #expect(subject.state.pathViewTappable == true)
        #expect(presenter.statesPresented.last?.hilitedPieces == [])
        #expect(presenter.statesPresented.last?.pathViewTappable == true)
        #expect(presenter.thingsReceived == [.illuminate(path: [Slot(0, 1), Slot(1, 1), Slot(1, 0)])])
        #expect(scoreKeeper.methodsCalled == ["userAskedForHint()"])
    }

    @Test("showHint(true): if there is _already_ a hint path (and there should be), just uses it, tells scorekeeper")
    func showHintTrueLegalPathExists() async {
        subject.state.hintPath = [Slot(0, 1)]
        subject.state.pathViewTappable = false
        await subject.showHint(true)
        #expect(subject.state.pathViewTappable == true)
        #expect(presenter.statesPresented.last?.pathViewTappable == true)
        #expect(presenter.thingsReceived == [.illuminate(path: [Slot(0, 1)])])
        #expect(scoreKeeper.methodsCalled == ["userAskedForHint()"])
    }

    @Test("score: access scorekeeper's score")
    func score() {
        subject.scoreKeeper.score = 42
        #expect(subject.score == 42)
    }

    @Test("stageNumber and setStageNumber: accesses the state stageNumber")
    func stageNumber() {
        subject.state.stageNumber = 7
        subject.setStageNumber(8)
        #expect(subject.state.stageNumber == 8)
        #expect(subject.stageNumber() == 8)
    }

    @Test("shuffle: unhilites and presents, unilluminates, turns user interaction off and on, rewrites grid, sends corresponding transition, tells scorekeeper")
    func shuffle() async throws {
        subject.grid[column: 1, row: 0] = "yoho"
        subject.grid[column: 0, row: 1] = "yoho"
        subject.grid[column: 1, row: 2] = "teehee"
        subject.grid[column: 1, row: 1] = "teehee"
        subject.state.hilitedPieces = [PieceReducer(picName: "yoho", column: 1, row: 0)]
        await subject.shuffle()
        #expect(subject.state.hilitedPieces == [])
        #expect(presenter.statesPresented.first?.hilitedPieces == [])
        #expect(presenter.thingsReceived.first == .unilluminate)
        let gridPieces = subject.grid.grid.flatMap {$0}.compactMap {$0}
        #expect(gridPieces.count == 4)
        let picNames = gridPieces.map { $0.picName }
        let slots = gridPieces.map { Slot(column: $0.column, row: $0.row) }
        #expect(picNames.sorted() == ["teehee", "teehee", "yoho", "yoho"])
        #expect(Set(slots) == [Slot(column: 1, row: 0), Slot(column: 0, row: 1), Slot(column: 1, row: 2), Slot(column: 1, row: 1)])
        #expect(presenter.thingsReceived.count == 7)
        #expect(presenter.thingsReceived.contains(.userInteraction(false)))
        #expect(presenter.thingsReceived.contains(.userInteraction(true)))
        var effectPieces = [PieceReducer]()
        var effectPix = [String]()
        for thing in presenter.thingsReceived {
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
        #expect(scoreKeeper.methodsCalled == ["userAskedForShuffle()"])
    }
}

final class MockBoardDelegate: BoardDelegate {
    var methodsCalled = [String]()

    func stageEnded() {
        methodsCalled.append(#function)
    }

    func userTappedPathView() {
        methodsCalled.append(#function)
    }
}
