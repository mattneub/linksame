
import UIKit
import QuartzCore

/// Public face of the BoardProcessor, defining the messages
/// that the LinkSameProcessor can send to the BoardProcessor.
@MainActor
protocol BoardProcessorType: AnyObject {
    var score: Int { get }
    func stageNumber() -> Int
    func setStageNumber(_: Int)
    var grid: Grid { get }
    var deckAtStartOfStage: [String] { get }
    func createAndDealDeck() async throws
    func populateFrom(oldGrid: Grid, deckAtStartOfStage: [String]) async
    func restartStage() async throws
    func showHint(_: Bool) async
    func shuffle() async
    func unhilite() async
}

/// Extension implementing some trivial state getters and setters from the protocol.
extension BoardProcessorType where Self: BoardProcessor {
    var deckAtStartOfStage: [String] {
        state.deckAtStartOfStage
    }

    var score: Int {
        scoreKeeper.score
    }

    func stageNumber() -> Int {
        state.stageNumber
    }

    func setStageNumber(_ stageNumber: Int) {
        state.stageNumber = stageNumber
    }
}

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

    /// Reference to board delegate; set by the coordinator on creation.
    weak var delegate: (any BoardDelegate)?

    /// State to be presented to the presenter for display in the interface.
    var state = BoardState()

    /// Auxiliary gravity object. It's a `var` so we can slot in a mock for testing.
    var gravity: any GravityType = Gravity()

    /// The Grid, acting as the source of truth for where the pieces are.
    /// We always have one; its dimensions are determined at creation time.
    var grid: Grid

    /// Shortcut for accessing the dimensions of the grid.
    var columns: Int { grid.columns }
    var rows: Int { grid.rows }

    /// ScoreKeeper object that will help manage timer and score while a stage is being played.
    /// We always have one; its score and delegate are determined at creation time.
    var scoreKeeper: any ScoreKeeperType

    /// Initializer.
    /// - Parameter gridSize: The size of our grid, which will be created, empty, at initialization.
    ///   We cannot live without a grid, and a grid cannot live without a size, which is immutable.
    /// - Parameter scoreKeeper: Our scorekeeper, which will be given its score and delegate
    ///   at initialization.
    init(gridSize: (columns: Int, rows: Int), scoreKeeper: any ScoreKeeperType) {
        self.grid = Grid(columns: gridSize.columns, rows: gridSize.rows)
        self.scoreKeeper = scoreKeeper
    }

    func receive(_ action: BoardAction) async {
        switch action {
        case .doubleTappedPiece:
            if let path = state.hintPath {
                if let pathStart = path.first, let pathEnd = path.last {
                    if let piece1 = grid[pathStart], let piece2 = grid[pathEnd] {
                        state.hilitedPieces = [piece1, piece2]
                        await presenter?.present(state)
                        await checkHilitedPair()
                    }
                }
            }
        case .tapped(let piece):
            await userTapped(piece: piece)
        case .tappedPathView:
            delegate?.userTappedPathView()
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
        state.deckAtStartOfStage = deck
        // create actual pieces and we're all set!
        for column in 0 ..< columns {
            for row in 0 ..< rows {
                guard !deck.isEmpty else {
                    throw DeckSizeError.oops
                }
                await addPieceAt(Slot(column: column, row: row), withPicture: deck.removeLast())
            }
        }
        state.hintPath = self.legalPath() // generate initial hint
    }

    /// Given a grid and a deck, make our grid look like the old grid, making all the same
    /// pieces appear in the interface, and keep a copy of the deck in case we have to restart
    /// the stage.
    func populateFrom(oldGrid: Grid, deckAtStartOfStage oldDeck: [String]) async {
        for column in 0 ..< oldGrid.columns {
            for row in 0 ..< oldGrid.rows {
                if let oldPiece = oldGrid[column: column, row: row] {
                    await addPieceAt(Slot(column: column, row: row), withPicture: oldPiece.picName)
                } // and otherwise it will just be nil
                // TODO: seem to be just assuming that the physical layout is empty
            }
        }
        state.deckAtStartOfStage = oldDeck
        state.hintPath = self.legalPath() // generate initial hint
    }

    /// Restart the current stage, by replacing the current pieces with the deck that we saved off
    /// when the stage began.
    /// - Throws: If anything goes wrong. This is an attempt to deal with crashes that could occur;
    /// I never tracked these down, but it's hard to see what _could_ be crashing except some
    /// size mismatch resulting in a bad `removeLast`.
    func restartStage() async throws {
        guard state.deckAtStartOfStage.count == columns * rows else {
            throw DeckSizeError.oops
        }
        var deck = state.deckAtStartOfStage // do not change deckAtStartOfStage itself, we might need it again!
        for column in 0 ..< self.columns {
            for row in 0 ..< self.rows {
                if let oldPiece = grid[column: column, row: row] {
                    await self.removePiece(oldPiece)
                }
                guard !deck.isEmpty else {
                    throw DeckSizeError.oops
                }
                await addPieceAt(Slot(column: column, row: row), withPicture: deck.removeLast())
            }
        }
        state.hintPath = self.legalPath() // generate initial hint
    }

    /// Shuffle existing pieces; could be because user asked to shuffle,
    /// could be we're out of legal moves. Gather up all displayed pieces (as picture names),
    /// shuffle them, deal them into the currently occupied slots.
    func redeal() async {
        var limit = unlessTesting(10) // put a limit on how many times we will try
        repeat {
            await presenter?.receive(.userInteraction(false))
            var deck = [String]()
            for column in 0 ..< columns {
                for row in 0 ..< rows {
                    if let piece = grid[column: column, row: row] {
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
                        grid[column: column, row: row] = picture
                        await presenter?.receive(.transition(piece: originalPiece, toPicture: picture))
                    }
                }
            }
            await presenter?.receive(.userInteraction(true))
            limit -= 1
        } while self.legalPath() == nil && limit > 0 // both creates and tests for existence of legal path
        state.hintPath = self.legalPath() // generate initial hint
        // and if we've failed to get a legal path after 10 tries, the hint is just nil
        // but at least the user will see something, rather than us looping forever or crashing or something
    }

    /// Create a piece and put it into a given slot _and the interface_.
    /// It is crucial to keep these in sync.
    /// - Parameters:
    ///   - slot: The slot where the piece should go.
    ///   - picTitle: The name of the picture for the piece.
    private func addPieceAt(_ slot: Slot, withPicture picTitle: String) async {
        let (column, row) = (slot.column, slot.row)
        grid[column: column, row: row] = picTitle
        let piece = PieceReducer(picName: picTitle, column: column, row: row)
        await presenter?.receive(.insert(piece: piece))
    }
    
    /// Remove any piece highlighting. If nothing is highlighted, no harm done.
    func unhilite() async {
        if !state.hilitedPieces.isEmpty {
            state.hilitedPieces = []
            await presenter?.present(state)
        }
    }

    /// Utility to determine whether the line from p1 to p2 consists entirely of nil.
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
                if grid[column: p1.column, row: row] != nil {
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
                if grid[column: column, row: p1.row] != nil {
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
        if grid[corner1] == nil {
            if self.lineIsClearFrom(slot1, to: corner1) && self.lineIsClearFrom(corner1, to: slot2) {
                return [slot1, corner1, slot2]
            }
        }
        if grid[corner2] == nil {
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
            if grid[corner1] == nil && grid[corner2] == nil {
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
        let p1 = state.hilitedPieces[0]
        let p2 = state.hilitedPieces[1]
        guard p1.picName == p2.picName else {
            await presenter?.receive(.userInteraction(true))
            await self.unhilite()
            return
        }
        if let path = self.checkPair(p1, and: p2) {
            // legal move! tell the score keeper
            await scoreKeeper.userMadeLegalMove()
            // flash the path
            await presenter?.receive(.illuminate(path: path))
            try? await unlessTesting {
                try? await Task.sleep(for: .seconds(0.2))
            }
            await presenter?.receive(.unilluminate)
            try? await unlessTesting {
                try? await Task.sleep(for: .seconds(0.1))
            }
            await self.unhilite()
            // remove the pieces
            await self.removePiece(p1)
            await self.removePiece(p2)
            if grid.isEmpty {
                // stage is over! tell the delegate, we're out of here
                await presenter?.receive(.userInteraction(true))
                delegate?.stageEnded()
                return
            }
            // perform any gravity moves
            let movenda = gravity.exerciseGravity(grid: &grid, stageNumber: state.stageNumber)
            if !movenda.isEmpty {
                await presenter?.receive(.move(movenda))
            }
            // generate new hint path, but also check whether we need a redeal
            state.hintPath = self.legalPath()
            if state.hintPath == nil {
                await self.redeal()
            }
        } else {
            await self.unhilite()
        }
        await presenter?.receive(.userInteraction(true))
    }

    // TODO: restore eventually, this is game over check
    // type(of: services.application).userInteraction(false)
    // notify (so score can be incremented)
    // nc.post(name: BoardProcessor.userMoved, object: self)
    // actually remove the pieces (we happen to know there must be exactly two)
    //        for piece in state.hilitedPieces {
    //            await self.removePiece(piece)
    //        }
    //        state.hilitedPieces.removeAll()
    // game over? if so, notify along with current stage and we're out of here!
    //        if self.gameOver() {
    //            Task { @MainActor in
    //                try? await Task.sleep(for: .seconds(0.1)) // nicer with a little delay
    //                type(of: services.application).userInteraction(true)
    //                // nc.post(name: BoardProcessor.gameOver, object: self, userInfo: ["stage":self.stageNumber])
    //            }
    //            return
    //        }

    /// The user has tapped the given piece. If already highlighted, remove it from the highlighted
    /// list and unhighlight it; otherwise, add it to the highlighted list and highlight it. If there
    /// are now two highlighted pieces, evaluate for a legal path.
    /// - Parameter piece: The piece tapped.
    private func userTapped(piece: PieceReducer) async {
        assert(state.hilitedPieces.count < 2, "tap when two pieces are already hilited")
        await presenter?.receive(.userInteraction(false))
        let hilited = state.hilitedPieces.contains(piece)
        if !hilited {
            state.hilitedPieces.append(piece)
        } else {
            state.hilitedPieces.remove(object: piece)
        }
        await presenter?.present(state)
        await presenter?.receive(.userInteraction(true))

        if state.hilitedPieces.count == 2 {
            await checkHilitedPair()
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
                let piece = grid[column: x, row: y]
                if piece == nil {
                    continue
                }
                let picName = piece!.picName
                for xx in 0..<self.columns {
                    for yy in 0..<self.rows {
                        let piece2 = grid[column: xx, row: yy]
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

    func showHint(_ show: Bool) async {
        state.hilitedPieces = []
        if show {
            // no need to waste time calling legalPath(); path is ready (or not) in hintPath
            if let path = state.hintPath {
                await presenter?.receive(.illuminate(path: path))
            } else { // this part shouldn't happen, but just in case, waste time after all
                state.hintPath = self.legalPath()
                if state.hintPath != nil {
                    await self.showHint(true) // try again, and this time we'll succeed
                } else {
                    await self.redeal() // should _really_ never happen, but just in case
                }
            }
            state.pathViewTappable = true
        } else {
            await presenter?.receive(.unilluminate)
            state.pathViewTappable = false
        }
        await presenter?.present(state)
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

@MainActor
protocol BoardDelegate: AnyObject {
    func stageEnded()
    func userTappedPathView()
}

/// Reducer that carries pertinent BoardProcessor data into and out of persistence.
nonisolated
struct BoardSaveableData: Codable, Equatable {
    let stageNumber: Int
    let grid: Grid
    let deckAtStartOfStage: [String]
}
