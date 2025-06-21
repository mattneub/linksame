
import UIKit
import QuartzCore

// TODO: NOTE - I might change this to communicate via an action enum; let's see how things go.
/// Public face of the BoardProcessor, so we can mock it for testing. This defines the messages
/// that the LinkSameProcessor can send to the BoardProcessor.
@MainActor
protocol BoardProcessorType: AnyObject {
    var stageNumber: Int { get set }
    var grid: Grid { get }
    var deckAtStartOfStage: [PieceReducer] { get }
    func createAndDealDeck() async throws
    func populateFrom(oldGrid: Grid, deckAtStartOfStage: [PieceReducer]) async
    func shuffle() async
}

// TODO: eventually get rid of this comment
/*
 Board has strong reference to View
 Board has strong reference to Grid

 Grid has strong reference to Pieces (qua array)
 View has strong reference to Pieces (qua subviews)
 
 Board has strong reference to PathView
 View has strong reference to PathView (qua subview)
 
 PathView has weak reference to LegalPathShower
 LegalPathShower has unowned reference to Board
 Board has strong reference to LegalPathShower
 */

/// The BoardProcessor serves the LinkSameProcessor. It doesn't know how the whole game works,
/// but it does know how the game is _played_: it understands the physical mechanism of the game
/// (taps on pieces), and it understands the notion of a legal move and what happens in response.
/// Most important, it maintains the Grid which is the source of truth for where the pieces are.
/// Its presenter is the view where the pieces are actually drawn.
@MainActor
final class BoardProcessor: BoardProcessorType, Processor {

//    static let gameOver = Notification.Name("gameOver")
//    static let userMoved = Notification.Name("userMoved")
//    static let userTappedPath = Notification.Name("userTappedPath")

    /// Reference to the presenter; set by the coordinator on creation.
    weak var presenter: (any ReceiverPresenter<BoardEffect, BoardState>)?

    /// State to be presented to the presenter for display in the interface.
    var state = BoardState()

    var stageNumber = 0

    // TODO: find another way of expressing this one
    // var showingHint : Bool { return self.legalPathShower.isIlluminating }

    /// The Grid, acting as the source of truth for where the pieces are.
    /// We always have one; its dimensions are determined at creation time.
    var grid: Grid

    /// Shortcut for accessing the dimensions of the grid.
    var columns: Int { grid.columns }
    var rows: Int { grid.rows }

    private var hintPath: Path?

    /// Variable where we maintain the contents of the "deck" at the start of each stage,
    /// in case we are asked to restart the stage. The "deck" consists of just a list of pictures,
    /// because we know where the corresponding pieces go: just fill the grid.
    var deckAtStartOfStage = [PieceReducer]()

    /// Initializer.
    /// - Parameter gridSize: The size of our grid, which will be created, empty, at initialization.
    ///   We cannot live without a grid, and a grid cannot live without a size, which is immutable.
    init(gridSize: (columns: Int, rows: Int)) {
        self.grid = Grid(columns: gridSize.columns, rows: gridSize.rows)
    }

    func receive(_ action: BoardAction) async {
        switch action {
        case .tapped(let piece):
            await userTapped(piece: piece)
        }
    }

    /// The "deck" here is just a list of picture names. Create it based on the style and the size
    /// of the grid, shuffle it, save a copy in case we have to restart the stage,
    /// deal it into the grid, and make every piece appear in the interface.
    func createAndDealDeck() async throws {
        // determine which pieces to use
        let (start1, start2) = Styles.pieces(services.persistence.loadString(forKey: .style))
        // base set of pictures, always used in its entirety
        var deck = [String]()
        // four copies of each picture
        for _ in 0..<4 {
            for i in start1 ..< start1 + 9 {
                deck += [String(i)]
            }
        }
        // determine which additional pieces to use, finish deck of piece names
        let howmany = ((columns * rows) / 4) - 9 // total separate images needed, minus the 9 base images
        for _ in 0..<4 {
            for i in start2 ..< start2 + howmany {
                deck += [String(i)]
            }
        }
        // done! shuffle
        for _ in 0..<4 {
            deck.shuffle()
        }
        // store a copy so we can restart the stage if we have to
        self.deckAtStartOfStage = deck.map { PieceReducer(picName: $0) }
        // create actual pieces and we're all set!
        for column in 0 ..< columns {
            for row in 0 ..< rows {
                guard !deck.isEmpty else {
                    throw DeckSizeError.oops
                }
                await addPieceAt(Slot(column: column, row: row), withPicture: deck.removeLast())
            }
        }
        self.hintPath = self.legalPath() // generate initial hint
    }

    /// Given a grid and a deck, make our grid look like the old grid, making all the same
    /// pieces appear in the interface, and keep a copy of the deck in case we have to restart
    /// the stage.
    func populateFrom(oldGrid: Grid, deckAtStartOfStage oldDeck: [PieceReducer]) async {
        for column in 0 ..< oldGrid.columns {
            for row in 0 ..< oldGrid.rows {
                if let oldPiece = oldGrid[column: column, row: row] {
                    await addPieceAt(Slot(column: column, row: row), withPicture: oldPiece.picName)
                } // and otherwise it will just be nil
                // TODO: seem to be just assuming that the physical layout is empty
            }
        }
        self.deckAtStartOfStage = oldDeck
        self.hintPath = self.legalPath() // generate initial hint
    }

    func restartStage() async throws {
        // deal stored deck; remove existing pieces as we go
        // attempt to deal with crashes, hard to see what could be crashing except maybe removeLast
        guard deckAtStartOfStage.count == columns * rows else {
            throw DeckSizeError.oops
        }
        var deck = deckAtStartOfStage // do not change deckAtStartOfStage, we might need it again!
        for column in 0 ..< self.columns {
            for row in 0 ..< self.rows {
                // TODO: This looks like it should be otiose: addPiece should remove if a piece is already slotted in
                if let oldPiece = self.piece(at: Slot(column: column, row: row)) {
                    await self.removePiece(oldPiece)
                }
                guard !deck.isEmpty else {
                    throw DeckSizeError.oops
                }
                await addPieceAt(Slot(column: column, row: row), withPicture: deck.removeLast().picName)
            }
        }
        self.hintPath = self.legalPath() // generate initial hint
    }

    /// Shuffle existing pieces; could be because user asked to shuffle,
    /// could be we're out of legal moves. Gather up all displayed pieces (as picture names),
    /// shuffle them, deal them into the currently occupied slots.
    func redeal() async {
        repeat {
            await presenter?.receive(.userInteraction(false))
            var deck = [String]()
            for column in 0 ..< columns {
                for row in 0 ..< rows {
                    if let piece = self.piece(at: Slot(column: column, row: row)) {
                        deck.append(piece.picName)
                    }
                }
            }
            deck.shuffle()
            deck.shuffle()
            deck.shuffle()
            deck.shuffle()
            for column in 0 ..< columns {
                for row in 0 ..< rows {
                    if let originalPiece = grid[column: column, row: row] {
                        let picture = deck.removeLast()
                        grid[column: column, row: row] = PieceReducer(picName: picture, column: column, row: row)
                        await presenter?.receive(.transition(piece: originalPiece, toPicture: picture))
                    }
                }
            }
            await presenter?.receive(.userInteraction(true))
        } while self.legalPath() == nil // both creates and tests for existence of legal path
        self.hintPath = self.legalPath() // generate initial hint
    }

    /// Report the piece at a slot of the grid, except that adjacent to the real grid there is
    /// an imaginary extension on all sides, consisting of empty slots, where path drawing can
    /// take place.
    /// - Parameter slot: The specified slot of the grid.
    /// - Returns: A piece reducer describing the piece that is in that slot of the grid.
    private func piece(at slot: Slot) -> PieceReducer? {
        // TODO: Consider moving this to grid, i.e. just make it part of the subscripting.
        let (column, row) = (slot.column, slot.row)
        // it is legal to ask for piece one slot outside boundaries, but not further
        assert(column >= -1 && column <= self.columns, "Piece requested out of bounds (column)")
        assert(row >= -1 && row <= self.rows, "Piece requested out of bounds (row)")
        // immediately outside boundaries, report slot as empty
        if (column == -1 || column == self.columns) { return nil }
        if (row == -1 || row == self.rows) { return nil }
        // inside boundaries, report actual contents of slot
        return grid[column: column, row: row]
    }
    
    /// Create a piece and put it into a given slot _and the interface_.
    /// It is crucial to keep these in sync.
    /// - Parameters:
    ///   - slot: The slot where the piece should go.
    ///   - picTitle: The name of the picture for the piece.
    private func addPieceAt(_ slot: Slot, withPicture picTitle: String) async {
        let (column, row) = (slot.column, slot.row)
        let piece = PieceReducer(picName: picTitle, column: column, row: row)
        grid[column: column, row: row] = piece
        await presenter?.receive(.insert(piece: piece))
    }
    
    // as pieces are highlighted, we store them in an ivar
    // thus, to unhighlight all highlighted pieces, we just run thru that list
    // now public, because controller might need to cancel existing highlight
    // make no assumptions about how many are in list!
    
    func unhilite() async {
        state.hilitedPieces = []
        await presenter?.present(state)
    }
    
    // utility to determine whether the line from p1 to p2 consists entirely of nil
    
    private func lineIsClearFrom(_ p1: Slot, to p2: Slot) -> Bool {
        if !(p1.column == p2.column || p1.row == p2.row) {
            return false // they are not even on the same line
        }
        // determine which dimension they share, then which way they are ordered
        var start: Slot, end: Slot
        if p1.column == p2.column {
            if p1.row < p2.row {
                (start, end) = (p1, p2)
            } else {
                (start, end) = (p2, p1)
            }
            for row in start.row + 1 ..< end.row {
                if self.piece(at: Slot(p1.column, row)) != nil {
                    return false
                }
            }
        } else { // p1.row == p2.row
            if p1.column < p2.column {
                (start, end) = (p1, p2)
            } else {
                (start, end) = (p2, p1)
            }
            for column in start.column + 1 ..< end.column {
                if self.piece(at: Slot(column, p1.row)) != nil {
                    return false
                }
            }
        }
        return true
    }
    
    /// Remove a piece from the grid and the interface.
    /// - Parameter piece: The piece to remove.
    private func removePiece(_ piece: PieceReducer) async {
        self.grid[column: piece.column, row: piece.row] = nil
        await presenter?.receive(.remove(piece: piece))
    }
    
    // utility to learn whether the grid is empty, indicating that the game is over
    
    private func gameOver () -> Bool {
        // return true // testing game end
        for column in 0..<self.columns {
            for row in 0..<self.rows {
                if self.piece(at: Slot(column, row)) != nil {
                    return false
                }
            }
        }
        return true
    }
        
    private func reallyRemovePair() async {
        var movenda = [PieceReducer]() // we will maintain a list of all pieces that need to animate a position change
        // utility to prepare pieces for position change
        // configure the piece internally and grid-wise for its new position, 
        // but keep it physically in the old position
        // store it in movenda so we can animate it into its new position at the end of this method
        func movePiece(_ piece: PieceReducer, to newSlot: Slot) async {
            assert(self.piece(at: newSlot) == nil, "Slot to move piece to must be empty")
            // move the piece within the *grid*
            let picName = piece.picName
            // TODO: restore
            // let oldFrame = piece.frame
            await self.removePiece(piece)
            await addPieceAt(newSlot, withPicture: picName)
            // however, we are not yet redrawn, so now...
            // return piece to its previous position! but add to movenda
            // later we will animate it into correct position
            let pnew = self.piece(at: newSlot)!
            // TODO: restore
            // pnew.frame = oldFrame
            movenda += [pnew]
        }

        type(of: services.application).userInteraction(false)
        // notify (so score can be incremented)
        // nc.post(name: BoardProcessor.userMoved, object: self)
        // actually remove the pieces (we happen to know there must be exactly two)
        for piece in state.hilitedPieces {
            await self.removePiece(piece)
        }
        state.hilitedPieces.removeAll()
        // game over? if so, notify along with current stage and we're out of here!
        if self.gameOver() {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.1)) // nicer with a little delay
                type(of: services.application).userInteraction(true)
                // nc.post(name: BoardProcessor.gameOver, object: self, userInfo: ["stage":self.stageNumber])
            }
            return
        }
        // close up! depends on what stage we are in
        // the following code is really ugly and repetitive, every case being modelled on the same template
        // but it works and I'm not touching it!
        switch self.stageNumber {
        case 0: // no gravity, do nothing
            // fallthrough // debugging later cases
            break
        case 1: // gravity down
            // fallthrough // debugging later cases
            // for (var x = 0; x < self.xct; x++) {
            for x in 0..<self.columns {
                // for (var y = self.yct - 1; y > 0; y--) {
                for y in self.rows>>>0 { // not an exact match for my original C version, but simpler
                    let piece = self.piece(at: Slot(x,y))
                    if piece == nil {
                        // for (var yt = y-1; yt >= 0; yt--) {
                        for yt in y>>>0 {
                            let piece2 = self.piece(at: Slot(x,yt))
                            if piece2 == nil {
                                continue
                            }
                            await movePiece(piece2!, to: Slot(x,y))
                            break
                        }
                    }
                }
            }
        case 2: // gravity right
            // fallthrough // debugging later cases
            // for (var y = 0; y < self.yct; y++) {
            for y in 0..<self.rows {
                // for (var x = self.xct - 1; x > 0; x--) {
                for x in self.columns>>>0 {
                    let piece = self.piece(at: Slot(x,y))
                    if piece == nil {
                        // for (var xt = x-1; xt >= 0; xt--) {
                        for xt in x>>>0 {
                            let piece2 = self.piece(at: Slot(xt,y))
                            if piece2 == nil {
                                continue
                            }
                            await movePiece(piece2!, to: Slot(x,y))
                            break
                        }
                    }
                }
            }
        case 3: // gravity toward central horiz line
            // fallthrough // debugging later cases
            let center = self.rows/2 // integer div, deliberate
            // exactly like 1 except we have to do it twice in two directions
            // for (var x = 0; x < self.xct; x++) {
            for x in 0..<self.columns {
                // for (var y = center - 1; y > 0; y--) {
                for y in center>>>0 {
                    let piece = self.piece(at: Slot(x,y))
                    if piece == nil {
                        // for (var yt = y-1; yt >= 0; yt--) {
                        for yt in y>>>0 {
                            let piece2 = self.piece(at: Slot(x,yt))
                            if piece2 == nil {
                                continue
                            }
                            await movePiece(piece2!, to: Slot(x,y))
                            break
                        }
                    }
                }
                // for (var y = center; y <= self.yct - 1; y++) {
                for y in center..<self.rows {
                    let piece = self.piece(at: Slot(x,y))
                    if piece == nil {
                        // for (var yt = y+1; yt < self.yct; yt++) {
                        for yt in y+1..<self.rows {
                            let piece2 = self.piece(at: Slot(x,yt))
                            if piece2 == nil {
                                continue
                            }
                            await movePiece(piece2!, to: Slot(x,y))
                            break
                        }
                    }
                }
            }
        case 4: // gravity toward central vertical line
            // fallthrough // debugging later cases
            // exactly like 3 except the other orientation
            let center = self.columns/2 // integer div, deliberate
            // for (var y = 0; y < self.yct; y++) {
            for y in 0..<self.rows {
                // for (var x = center-1; x > 0; x--) {
                for x in center>>>0 {
                    let piece = self.piece(at: Slot(x,y))
                    if piece == nil {
                        // for (var xt = x-1; xt >= 0; xt--) {
                        for xt in x>>>0 {
                            let piece2 = self.piece(at: Slot(xt,y))
                            if piece2 == nil {
                                continue
                            }
                            await movePiece(piece2!, to: Slot(x,y))
                            break
                        }
                    }
                }
                // for (var x = center; x <= self.xct - 1; x++) {
                for x in center..<self.columns {
                    let piece = self.piece(at: Slot(x,y))
                    if piece == nil {
                        // for (var xt = x+1; xt < self.xct; xt++) {
                        for xt in x+1..<self.columns {
                            let piece2 = self.piece(at: Slot(xt,y))
                            if piece2 == nil {
                                continue
                            }
                            await movePiece(piece2!, to: Slot(x,y))
                            break
                        }
                    }
                }
            }
        case 5: // gravity away from central horiz line
            // fallthrough // debugging later cases
            // exactly like 3 except we walk from the outside to the center
            let center = self.rows/2 // integer div, deliberate
            // for (var x = 0; x < self.xct; x++) {
            for x in 0..<self.columns {
                // for (var y = self.yct-1; y > center; y--) {
                for y in self.rows>>>center { // not identical to C loop, moved pivot
                    let piece = self.piece(at: Slot(x,y))
                    if piece == nil {
                        // for (var yt = y-1; yt >= center; yt--) {
                        for yt in y>>>center {
                            let piece2 = self.piece(at: Slot(x,yt))
                            if piece2 == nil {
                                continue
                            }
                            await movePiece(piece2!, to: Slot(x,y))
                            break
                        }
                    }
                }
                // for (var y = 0; y < center-1; y++) {
                for y in 0..<center {
                    let piece = self.piece(at: Slot(x,y))
                    if piece == nil {
                        // for (var yt = y+1; yt < center; yt++) {
                        for yt in y+1..<center {
                            let piece2 = self.piece(at: Slot(x,yt))
                            if piece2 == nil {
                                continue
                            }
                            await movePiece(piece2!, to: Slot(x,y))
                            break
                        }
                    }
                }
            }
        case 6: // gravity away from central vertical line
            // fallthrough // debugging later cases
            // exactly like 4 except we start at the outside
            let center = self.columns/2 // integer div, deliberate
            // for (var y = 0; y < self.yct; y++) {
            for y in 0..<self.rows {
                // for (var x = self.xct-1; x > center; x--) {
                for x in self.columns>>>center {
                    let piece = self.piece(at: Slot(x,y))
                    if piece == nil {
                        // for (var xt = x-1; xt >= center; xt--) {
                        for xt in x>>>center {
                            let piece2 = self.piece(at: Slot(xt,y))
                            if piece2 == nil {
                                continue
                            }
                            await movePiece(piece2!, to: Slot(x,y))
                            break
                        }
                    }
                }
                // for (var x = 0; x < center-1; x++) {
                for x in 0..<center {
                    let piece = self.piece(at: Slot(x,y))
                    if piece == nil {
                        // for (var xt = x+1; xt < center; xt++) {
                        for xt in x..<center { // not identical
                            let piece2 = self.piece(at: Slot(xt,y))
                            if piece2 == nil {
                                continue
                            }
                            await movePiece(piece2!, to: Slot(x,y))
                            break
                        }
                    }
                }
            }
        case 7: // gravity down in one half, gravity up in the other half
            // fallthrough // debugging later cases
            // like doing 1 in two pieces with the second piece in reverse direction
            let center = self.columns/2;
            // for (var x = 0; x < center; x++) {
            for x in 0..<center {
                // for (var y = self.yct - 1; y > 0; y--) {
                for y in self.rows>>>0 {
                    let piece = self.piece(at: Slot(x,y))
                    if piece == nil {
                        // for (var yt = y-1; yt >= 0; yt--) {
                        for yt in y>>>0 {
                            let piece2 = self.piece(at: Slot(x,yt))
                            if piece2 == nil {
                                continue
                            }
                            await movePiece(piece2!, to: Slot(x,y))
                            break
                        }
                    }
                }
            }
            // for (var x = center; x < self.xct; x++) {
            for x in center..<self.columns {
                // for (var y = 0; y < self.yct-1; y++) {
                for y in 0..<self.rows {
                    let piece = self.piece(at: Slot(x,y))
                    if piece == nil {
                        // for (var yt = y+1; yt < self.yct; yt++) {
                        for yt in y..<self.rows {
                            let piece2 = self.piece(at: Slot(x,yt))
                            if piece2 == nil {
                                continue
                            }
                            await movePiece(piece2!, to: Slot(x,y))
                            break
                        }
                    }
                }
            }
        case 8: // gravity left in one half, gravity right in other half
            // like doing 2 in two pieces with second in reverse direction
            let center = self.rows/2
            // for (var y = 0; y < center; y++) {
            for y in 0..<center {
                // for (var x = self.xct - 1; x > 0; x--) {
                for x in self.columns>>>0 {
                    let piece = self.piece(at: Slot(x,y))
                    if piece == nil {
                        // for (var xt = x-1; xt >= 0; xt--) {
                        for xt in x>>>0 {
                            let piece2 = self.piece(at: Slot(xt,y))
                            if piece2 == nil {
                                continue
                            }
                            await movePiece(piece2!, to: Slot(x,y))
                            break
                        }
                    }
                }
            }
            // for (var y = center; y < self.yct; y++) {
            for y in center..<self.rows {
                // for (var x = 0; x < self.xct-1; x++) {
                for x in 0..<self.columns {
                    let piece = self.piece(at: Slot(x,y))
                    if piece == nil {
                        // for (var xt = x+1; xt < self.xct; xt++) {
                        for xt in x..<self.columns {
                            let piece2 = self.piece(at: Slot(xt,y))
                            if piece2 == nil {
                                continue
                            }
                            await movePiece(piece2!, to: Slot(x,y))
                            break
                        }
                    }
                }
            }

        default:
            break
        }
        
        // animate!
        // and then check for stuck
    
        // slide pieces into their correct place
        // okay, so all the pieces in movenda have the following odd feature:
        // they are internally consistent (they are in the right place in the grid, and they know that place)
        // but they are *physically* in the wrong place
        // thus all we have to do is move them visibly into the right place
        // the big lesson here is that animations run in another thread...
        // so as an animation begins, the interface is refreshed first
        // thus it doesn't matter that we moved the piece into its right place;
        // we also moved the piece back into its wrong place, 
        // and that is what the user will see when the animation starts

        Task { @MainActor in
            await services.view.animateAsync(withDuration: 0.15, delay: 0.1, options: .curveLinear) {
                while movenda.count > 0 {
                    // TODO: restore this, just removing so I can compile
//                    let p = movenda.removeLast()
//                    var f = p.frame
//                    f.origin = self.originOf((p.x, p.y))
//                    // print("Will change frame of piece \(p)")
//                    // print("From \(p.frame)")
//                    // print("To \(f)")
//                    p.frame = f // this is the move that will be animated
                }
            }
            self.hintPath = self.legalPath() // okay, assess the situation; either way, we need a new hint ready
            if self.hintPath == nil {
                await self.redeal()
            }
            // we do this after the slide animation is over, so we can get two animations in row, cool
            type(of: services.application).userInteraction(true)
        }
    }
    

    
    /// This is the main game logic utility! The day I figured out how to do this is the day I
    /// realized I could write this game. Decide whether the given pieces constitute a legal pair;
    /// if they do, return an array of successive slot positions consituting the legal path
    /// connecting them — and if they don't, return nil.
    /// - Parameters:
    ///   - p1: The first piece.
    ///   - p2: The second piece.
    /// - Returns: A legal path connecting the slots of the two pieces, or nil if there is no such path.
    private func checkPair(_ p1: PieceReducer, and p2: PieceReducer) -> Path? {
        let slot1 = Slot(column: p1.column, row: p1.row)
        let slot2 = Slot(column: p2.column, row: p2.row)
        // 1. First check: 1 segment. Are they on the same line with nothing between them?
        if self.lineIsClearFrom(slot1, to: slot2) {
            return [slot1, slot2]
        }
        // print("failed straight line test")
        // 2. Second check: 2 segments. Are they at the corners of a rectangle
        // with nothing on one pair of sides between them?
        let corner1 = Slot(p1.column, p2.row)
        let corner2 = Slot(p2.column, p1.row)
        if self.piece(at: corner1) == nil {
            if self.lineIsClearFrom(slot1, to: corner1) && self.lineIsClearFrom(corner1, to: slot2) {
                return [slot1, corner1, slot2]
            }
        }
        if self.piece(at: corner2) == nil {
            if self.lineIsClearFrom(slot1, to: corner2) && self.lineIsClearFrom(corner2, to: slot2) {
                return [slot1, corner2, slot2]
            }
        }
        // print("failed two-segment test")
        // 3. Third check: Three segments. "The Way of the Moving Line"
        // (This was the algorithmic insight that makes the whole thing possible!)
        // Connect the x or y coordinates of the pieces by a vertical or horizontal line;
        // move that line through the _whole_ grid including outside the boundaries,
        // and see if all three resulting segments are clear.
        // The only drawback with this approach is that if there are multiple paths,
        // we may find a longer one before we find a shorter one, which is counter-intuitive;
        // so, accumulate _all_ found paths and then return only the shortest.
        var foundPaths = [Path]()
        // print("=======")
        func addPathIfValid(_ corner1: Slot, _ corner2: Slot) {
            // print("about to check triple segment \(slot1) \(corner1) \(corner2) \(slot2)")
            guard corner1 != corner2 else { // if the corners are the same corner, that's not 3 segments
                return
            }
            if self.piece(at: corner1) == nil && self.piece(at: corner2) == nil {
                if self.lineIsClearFrom(slot1, to: corner1) &&
                    self.lineIsClearFrom(corner1, to: corner2) &&
                    self.lineIsClearFrom(corner2, to: slot2) {
                        foundPaths.append([slot1, corner1, corner2, slot2]) // easy-peasy!
                }
            }
        }
        for row in -1...self.rows {
            addPathIfValid(Slot(slot1.column, row), Slot(slot2.column, row))
        }
        for column in -1...self.columns {
            addPathIfValid(Slot(column, slot1.row), Slot(column, slot2.row))
        }
        if foundPaths.isEmpty { // no dice
            return nil
        }
        if foundPaths.count == 1 { // trivial, we're all done
            return foundPaths.first
        }
        // Okay, we have multiple paths! Find the _shortest_ and return it.
        func distance(_ pt1: Slot, _ pt2: Slot) -> Double {
            // utility to learn physical distance between two points (thank you, M. Descartes)
            let deltax = pt1.column - pt2.column
            let deltay = pt1.row - pt2.row
            return Double(deltax * deltax + deltay * deltay).squareRoot()
        }
        var shortestLength = -1.0
        var shortestPath = Path()
        for thisPath in foundPaths {
            var thisLength = 0.0
            for index in thisPath.indices.dropLast() {
                thisLength += distance(thisPath[index],thisPath[index+1])
            }
            if shortestLength < 0 || thisLength < shortestLength {
                shortestLength = thisLength
                shortestPath = thisPath
            }
        }
        assert(shortestPath.count > 0, "We must have a path to illuminate by now")
        return shortestPath
    }

    /// Check whether the currently highlighted two pieces constitute a legal pair.
    /// If they do, remove them from the hilited pieces, the grid, and the interface.
    /// If they don't, remove them from the hilited pieces (and remove their interface highlighting).
    private func checkHilitedPair() async {
        assert(state.hilitedPieces.count == 2, "Must have a pair to check")
        await presenter?.receive(.userInteraction(false))
        defer {
            Task {
                await presenter?.receive(.userInteraction(true))
            }
        }
        let p1 = state.hilitedPieces[0]
        let p2 = state.hilitedPieces[1]
        guard p1.picName == p2.picName else {
            await self.unhilite()
            return
        }
        if let path = self.checkPair(p1, and: p2) {
            // flash the path
            await presenter?.receive(.illuminate(path: path))
            try? await unlessTesting {
                try? await Task.sleep(for: .seconds(0.2))
            }
            await presenter?.receive(.unilluminate)
            try? await unlessTesting {
                try? await Task.sleep(for: .seconds(0.1))
            }
//          await reallyRemovePair()
            // TODO: restore reallyRemovePair; right now I am just removing directly
            // which is right only for stage 1
            await self.unhilite()
            await self.removePiece(p1)
            await self.removePiece(p2)
        } else {
            await self.unhilite()
        }
    }
    
    /// The user has tapped the given piece. If already highlighted, remove it from the highlighted
    /// list and unhighlight it; otherwise, add it to the highlighted list and highlight it. If there
    /// are now two highlighted pieces, evaluate for a legal path.
    /// - Parameter piece: The piece tapped.
    private func userTapped(piece: PieceReducer) async {
        assert(state.hilitedPieces.count < 2, "tap when two pieces are already hilited")
        await presenter?.receive(.userInteraction(false))
        defer {
            Task {
                await presenter?.receive(.userInteraction(true))
            }
        }
        let hilited = state.hilitedPieces.contains(piece)
        if !hilited {
            state.hilitedPieces.append(piece)
        } else {
            state.hilitedPieces.remove(object: piece)
        }
        await presenter?.present(state)
        if state.hilitedPieces.count == 2 {
            await checkHilitedPair()
        }
    }
    
    // short-circuit, just make a legal move yet already
    @objc private func handleDeveloperDoubleTap(_ g:UIGestureRecognizer) {
        Task {
            if let path = self.legalPath() {
                let p = g.view as! Piece
                if p.isHilited {
                    p.toggleHilite()
                }
                state.hilitedPieces = [self.piece(at: path.first!)!, self.piece(at: path.last!)!]
                await checkHilitedPair()
            }
        }
    }
    
    // tap gesture on pathView
    
//    @objc private func tappedPathView(_ : UIGestureRecognizer) {
//        nc.post(name: BoardProcessor.userTappedPath, object: self)
//    }
    
    // utility to run thru the entire grid and make sure there is at least one legal path somewhere
    // if the path exists, we return array representing path that joins them; otherwise nil
    // that way, the caller can *show* the legal path if desired
    // but caller can test result as condition as well
    // the path is simply the path returned from checkPair
    
    private func legalPath () -> Path? {
        for x in 0..<self.columns {
            for y in 0..<self.rows {
                let piece = self.piece(at: Slot(x,y))
                if piece == nil {
                    continue
                }
                let picName = piece!.picName
                for xx in 0..<self.columns {
                    for yy in 0..<self.rows {
                        let piece2 = self.piece(at: Slot(xx,yy))
                        if piece2 == nil {
                            continue
                        }
                        if (x == xx && y == yy) {
                            continue
                        }
                        let picName2 = piece2!.picName
                        if picName2 != picName {
                            continue
                        }
                        // print("========")
                        // print("About to check \(piece!) vs. \(piece2!)")
                        let path = self.checkPair(piece!, and:piece2!)
                        if path == nil {
                            continue
                        }
                        // got one!
                        return path
                    }
                }
            }
        }
        return nil
    }
    
    // public, called by LinkSameViewController to ask us to display hint
    func hint() async {
        // TODO: need to deal with tappability during this kind of illumination
        // no need to waste time calling legalPath(); path is ready (or not) in hintPath
        if let path = self.hintPath {
            await presenter?.receive(.illuminate(path: path))
        } else { // this part shouldn't happen, but just in case, waste time after all
            self.hintPath = self.legalPath()
            if self.hintPath != nil {
                await self.hint() // try again, and this time we'll succeed
            } else {
                await self.redeal() // should _really_ never happen, but just in case
            }
        }
    }
    
    // public, for the same reason: if LinkSameViewController tells us to hint,
    // we stay hinted until we are told to unhint
    func unhint() async {
        await presenter?.receive(.unilluminate)
    }

    /// The user has asked to shuffle the pieces.
    func shuffle() async {
        state.hilitedPieces = []
        await presenter?.present(state)
        await presenter?.receive(.unilluminate)
        // TODO: Penalize user
        await redeal()
    }

    deinit {
        print("farewell from board")
    }

    /// Error that gives us something to throw if we get out of sync with ourselves, which should
    /// never happen but it's better than crashing.
    enum DeckSizeError: Error {
        case oops
    }
}

/// Reducer that carries pertinent BoardProcessor data into and out of persistence.
nonisolated
struct BoardSaveableData: Codable {
    let stageNumber: Int
    let grid: Grid
    let deckAtStartOfStage: [PieceReducer]
}
extension BoardSaveableData {
    @MainActor init(boardProcessor board: any BoardProcessorType) {
        self.stageNumber = board.stageNumber
        self.grid = board.grid
        self.deckAtStartOfStage = board.deckAtStartOfStage
    }
}
