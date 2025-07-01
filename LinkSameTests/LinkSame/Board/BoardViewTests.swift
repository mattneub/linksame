import UIKit
@testable import LinkSame
import Testing
import WaitWhile

@MainActor
struct BoardViewTests {
    let subject = BoardView(columns: 2, rows: 2)
    let screen = MockScreen()
    let processor = MockProcessor<BoardAction, BoardState, BoardEffect>()
    let pathView = MockPathView()

    init() {
        services.screen = screen
        services.application = MockApplication()
        MockApplication.methodsCalled.removeAll()
        MockApplication.bools.removeAll()
        services.view = MockUIView.self
    }

    @Test("pieceSize: works as expected")
    func pieceSize() {
        // To see that pieceSize does what we expect, think in reverse: imagine that a piece is
        // 64x64. Then the board must have 32 extra points on all four sides (on 2x iPhone), so that
        // we can draw outside the board and connect the "centers" of the nonexistent pieces there.
        // So if there is just one piece, the overall board size is now 128x128.
        // But in addition we supply 1/8 of a piece on all four sides, i.e. add 16.
        // So the overall board size is now 144x144.
        // Now reverse that: if the board size is 144x144 and there is just one piece,
        // we expect the piece size to be 64x64.
        do {
            screen.traitCollection = UITraitCollection { traits in
                traits.userInterfaceIdiom = .phone
                traits.displayScale = 2
            }
            let subject = BoardView(columns: 1, rows: 1)
            subject.frame = CGRect(origin: .zero, size: .init(width: 144, height: 144))
            #expect(subject.pieceSize == CGSize(width: 64, height: 64))
        }
        // OK, now imagine there are four pieces, a 2x2 grid, of 64x64 pieces. That's 128x128.
        // But we supply 32 extra points on all four sizes; that's 192x192.
        // But we supply 1/8 of a piece on all four sides; that's 16 more, i.e. 208x208.
        // Now reverse that.
        do {
            screen.traitCollection = UITraitCollection { traits in
                traits.userInterfaceIdiom = .phone
                traits.displayScale = 2
            }
            let subject = BoardView(columns: 2, rows: 2)
            subject.frame = CGRect(origin: .zero, size: .init(width: 208, height: 208))
            #expect(subject.pieceSize == CGSize(width: 64, height: 64))
        }
        // Great! But the rules are a little different on iPad or a 3x screen. Here, we can afford
        // to be a little more expansive with our outer margin; instead of half an imaginary row/col
        // round the outside, we have an _entire_ imaginary row/col round the outside.
        // So for our 1x1 grid of a 64x64 piece, the whole board is 192x192, and add 16, that's 208x208.
        do {
            screen.traitCollection = UITraitCollection { traits in
                traits.userInterfaceIdiom = .pad
                traits.displayScale = 2
            }
            let subject = BoardView(columns: 1, rows: 1)
            subject.frame = CGRect(origin: .zero, size: .init(width: 208, height: 208))
            #expect(subject.pieceSize == CGSize(width: 64, height: 64))
        }
        do {
            screen.traitCollection = UITraitCollection { traits in
                traits.userInterfaceIdiom = .phone
                traits.displayScale = 3
            }
            let subject = BoardView(columns: 1, rows: 1)
            subject.frame = CGRect(origin: .zero, size: .init(width: 208, height: 208))
            #expect(subject.pieceSize == CGSize(width: 64, height: 64))
        }
        // Finally, let's do it for a 2x2 grid of 64x64 pieces on iPad. That's 128x128, and with 64
        // extra points on all four sides, that's 256x256. And 16 more, that's 272x272.
        do {
            screen.traitCollection = UITraitCollection { traits in
                traits.userInterfaceIdiom = .pad
                traits.displayScale = 2
            }
            let subject = BoardView(columns: 2, rows: 2)
            subject.frame = CGRect(origin: .zero, size: .init(width: 272, height: 272))
            #expect(subject.pieceSize == CGSize(width: 64, height: 64))
        }
        do {
            screen.traitCollection = UITraitCollection { traits in
                traits.userInterfaceIdiom = .phone
                traits.displayScale = 3
            }
            let subject = BoardView(columns: 2, rows: 2)
            subject.frame = CGRect(origin: .zero, size: .init(width: 272, height: 272))
            #expect(subject.pieceSize == CGSize(width: 64, height: 64))
        }
    }

    @Test("pathView: generates path view")
    func pathViewTest() throws {
        let pathView = subject.pathView
        #expect(pathView.isUserInteractionEnabled == false)
        let tap = try #require(pathView.gestureRecognizers?.first as? MyTapGestureRecognizer)
        #expect(tap.target === subject)
        #expect(tap.action == #selector(subject.tappedPathView))
    }

    @Test("Initializer sets up the view's subview.")
    func initializer() async throws {
        let subject = BoardView(columns: 1, rows: 1)
        subject.frame = CGRect(origin: .zero, size: .init(width: 100, height: 100))
        subject.layoutIfNeeded()
        let subview = try #require(subject.subviews.first as? PathView)
        #expect(subview.frame == CGRect(origin: .zero, size: .init(width: 100, height: 100)))
        subject.frame = CGRect(origin: .zero, size: .init(width: 200, height: 200))
        subject.layoutIfNeeded()
        #expect(subview.frame == CGRect(origin: .zero, size: .init(width: 200, height: 200)))
    }

    @Test("pieces: reports Piece subviews")
    func pieces() {
        let piece1 = Piece(picName: "piece1", column: 0, row: 0)
        let piece2 = Piece(picName: "piece2", column: 0, row: 0)
        let subject = BoardView(columns: 2, rows: 2)
        #expect(subject.pieces.isEmpty)
        subject.addSubview(piece1)
        subject.addSubview(piece2)
        #expect(subject.pieces.count == 2)
        #expect(subject.pieces.contains(piece1))
        #expect(subject.pieces.contains(piece2))
    }

    @Test("present: obeys state hilited pieces")
    func presentHilited() async {
        let piece1 = Piece(picName: "piece1", column: 0, row: 0)
        let piece2 = Piece(picName: "piece2", column: 0, row: 0)
        let piece3 = Piece(picName: "piece3", column: 0, row: 0)
        let piece4 = Piece(picName: "piece4", column: 0, row: 0)
        subject.addSubview(piece1)
        subject.addSubview(piece2)
        subject.addSubview(piece3)
        subject.addSubview(piece4)
        piece1.toggleHilite()
        piece2.toggleHilite()
        let state = BoardState(hilitedPieces: [piece2.toReducer, piece3.toReducer])
        await subject.present(state)
        #expect(piece1.isHilited == false)
        #expect(piece2.isHilited == true)
        #expect(piece3.isHilited == true)
        #expect(piece4.isHilited == false)
    }

    @Test("present: obeys state path view tappable")
    func presentPathViewTappable() async {
        subject.pathView = pathView
        #expect(pathView.isUserInteractionEnabled == true)
        var state = BoardState(pathViewTappable: false)
        await subject.present(state)
        #expect(pathView.isUserInteractionEnabled == false)
        state = BoardState(pathViewTappable: true)
        await subject.present(state)
        #expect(pathView.isUserInteractionEnabled == true)
    }

    @Test("receive illuminate: sends illuminate to path view, translating slots to center points")
    func illuminate() async {
        screen.traitCollection = UITraitCollection { traits in
            traits.userInterfaceIdiom = .phone
            traits.displayScale = 2
        }
        subject.frame = CGRect(origin: .zero, size: .init(width: 208, height: 208))
        subject.layoutIfNeeded()
        subject.pathView = pathView
        await subject.receive(.illuminate(path: [Slot(column: 1, row: 1)]))
        // see next test to find out how I know where the center is for that slot
        #expect(pathView.thingsReceived.first == .illuminate([CGPoint(x: 136, y: 136)]))
    }

    @Test("Receive insert: inserts piece at expected location")
    func insert() async throws {
        screen.traitCollection = UITraitCollection { traits in
            traits.userInterfaceIdiom = .phone
            traits.displayScale = 2
        }
        subject.frame = CGRect(origin: .zero, size: .init(width: 208, height: 208))
        subject.layoutIfNeeded()
        #expect(subject.pieceSize == CGSize(width: 64, height: 64))
        let subview = try #require(subject.subviews.first)
        let piece = PieceReducer(picName: "howdy", column: 1, row: 1)
        await subject.receive(.insert(piece: piece))
        // pieces are behind the invisible subview, so they are previous in the subviews list
        let realPiece = try #require(subject.subviews[0] as? Piece)
        #expect(realPiece.toReducer == piece)
        #expect(subject.subviews[1] === subview)
        // piece size is 64, so border is 8+32 = 40, so piece at 1,1 is at 104,104
        #expect(realPiece.frame == CGRect(x: 104, y: 104, width: 64, height: 64))
        // piece is tappable
        let tap = try #require(realPiece.gestureRecognizers?.first as? MyTapGestureRecognizer)
        #expect(tap.target as? UIView === subject)
        #expect(tap.action == #selector(subject.tappedPiece))
    }

    @Test("Receive insert: inserts piece at expected location on ipad. Bigger margins, allow room for toolbar.")
    func insertPad() async throws {
        screen.traitCollection = UITraitCollection { traits in
            traits.userInterfaceIdiom = .pad
            traits.displayScale = 2
        }
        subject.frame = CGRect(origin: .zero, size: .init(width: 272, height: 272))
        subject.layoutIfNeeded()
        #expect(subject.pieceSize == CGSize(width: 64, height: 64))
        let subview = try #require(subject.subviews.first)
        let piece = PieceReducer(picName: "howdy", column: 1, row: 1)
        await subject.receive(.insert(piece: piece))
        // pieces are behind the invisible subview, so they are previous in the subviews list
        let realPiece = try #require(subject.subviews[0] as? Piece)
        #expect(realPiece.toReducer == piece)
        #expect(subject.subviews[1] === subview)
        // piece size is 64, so border is 8+64 = 72, so piece at 1,1 is at 136,136, except
        // that it is 32 down from that to allow room for toolbar.
        #expect(realPiece.frame == CGRect(x: 136, y: 136+32, width: 64, height: 64))
        // piece is tappable
        let tap = try #require(realPiece.gestureRecognizers?.first as? MyTapGestureRecognizer)
        #expect(tap.target as? UIView === subject)
        #expect(tap.action == #selector(subject.tappedPiece))
    }

    @Test("receive move: moves the specified piece(s) to the specified location(s), rewrites their column and row")
    func move() async throws {
        screen.traitCollection = UITraitCollection { traits in
            traits.userInterfaceIdiom = .pad
            traits.displayScale = 2
        }
        subject.frame = CGRect(origin: .zero, size: .init(width: 272, height: 272))
        subject.layoutIfNeeded()
        let piece1 = Piece(picName: "hey", column: 0, row: 0)
        let piece2 = Piece(picName: "ho", column: 1, row: 0)
        subject.addSubview(piece1)
        subject.addSubview(piece2)
        let movenda: [Movendum] = [
            .init(piece: piece1.toReducer, newSlot: .init(0,1)),
            .init(piece: piece2.toReducer, newSlot: .init(0,2)),
        ]
        await subject.receive(.move(movenda))
        #expect(piece1.column == 0)
        #expect(piece1.row == 1)
        #expect(piece2.column == 0)
        #expect(piece2.row == 2)
        #expect(piece1.frame.origin == CGPoint(x: 72, y: 136+32))
        #expect(piece2.frame.origin == CGPoint(x: 72, y: 136+64+32))
    }

    @Test("receive remove: removes corresponding piece from interface")
    func remove() async {
        let piece1 = Piece(picName: "hey", column: 1, row: 1)
        let piece2 = Piece(picName: "ho", column: 2, row: 2)
        subject.addSubview(piece1)
        subject.addSubview(piece2)
        #expect(subject.pieces.count == 2)
        await subject.receive(.remove(piece: .init(picName: "hey", column: 2, row: 2))) // no match
        #expect(subject.pieces.count == 2)
        await subject.receive(.remove(piece: .init(picName: "ho", column: 2, row: 2))) // matches piece2
        #expect(subject.pieces.count == 1)
        #expect(subject.pieces[0].picName == "hey")
    }

    @Test("receive transition: calls view transition with expected arguments, changing picture of piece")
    func transition() async throws {
        MockUIView.methodsCalled = []
        let piece1 = Piece(picName: "hey", column: 1, row: 1)
        let piece2 = Piece(picName: "ho", column: 2, row: 2)
        subject.addSubview(piece1)
        subject.addSubview(piece2)
        await subject.receive(.transition(piece: piece2.toReducer, toPicture: "yoho"))
        #expect(MockUIView.methodsCalled == ["transition(with:duration:options:animations:completion:)"])
        #expect(MockUIView.view === piece2)
        #expect(MockUIView.duration == 0.7)
        #expect(MockUIView.options == [.transitionFlipFromLeft])
        #expect(piece2.picName == "ho")
        MockUIView.animations?()
        #expect(piece2.picName == "yoho")
    }

    @Test("receive unilluminate: sends unilluminate to path view")
    func unilluminate() async {
        subject.pathView = pathView
        await subject.receive(.unilluminate)
        #expect(pathView.thingsReceived.first == .unilluminate)
    }

    @Test("receive userInteraction: calls application userInteraction")
    func userInteraction() async {
        await subject.receive(.userInteraction(false))
        #expect(MockApplication.methodsCalled == ["userInteraction(_:)"])
        #expect(MockApplication.bools == [false])
        await subject.receive(.userInteraction(true))
        #expect(MockApplication.methodsCalled == ["userInteraction(_:)", "userInteraction(_:)"])
        #expect(MockApplication.bools == [false, true])
    }

    @Test("tappedPiece: send processor .tapped(piece)")
    func tappedPiece() async throws {
        subject.frame = CGRect(origin: .zero, size: .init(width: 272, height: 272))
        subject.layoutIfNeeded()
        subject.processor = processor
        let piece = PieceReducer(picName: "howdy", column: 1, row: 1)
        await subject.receive(.insert(piece: piece))
        let gestureRecognizer = try #require(subject.pieces.first?.gestureRecognizers?.first as? MyTapGestureRecognizer)
        subject.perform(gestureRecognizer.action, with: gestureRecognizer) // whew!
        await #while(processor.thingsReceived.isEmpty)
        #expect(processor.thingsReceived.first == .tapped(piece))
    }

    @Test("tappedPathView: send processor .tappedPathView")
    func tappedPathView() async {
        subject.processor = processor
        subject.tappedPathView()
        await #while(processor.thingsReceived.isEmpty)
        #expect(processor.thingsReceived.last == .tappedPathView)
    }
}
