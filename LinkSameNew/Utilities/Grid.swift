/// Simple type that represents the rectangular grid of pieces (or spaces) on which the game is played.
/// This is so that we can go directly and easily from a coordinate in the game grid to whatever
/// piece is at that coordinate. Maintained by the BoardProcessor.
///
/// **WARNING**: We have to be careful to maintain consistency between:
/// * where a Piece is in the Grid
/// * where that same Piece is in the Board
/// * where that same Piece thinks it is (its x and y)
///
@MainActor
struct Grid: Equatable, Codable {
    private(set) var grid: [[Piece?]]
    let columns: Int
    let rows: Int
    init(columns: Int, rows: Int) {
        self.columns = columns
        self.rows = rows
        // and now set up the empty grid with nils
        // hold my beer and watch this!
        self.grid = Array(repeating: Array(repeating: nil, count: rows), count: columns)
    }
    subscript(column column: Int, row row: Int) -> Piece? {
        get {
            grid[column][row]
        }
        set(piece) {
            grid[column][row] = piece
        }
    }
}

// TODO: OK, I think I see how this should be done. Use an array of a _reducer_ instead of Piece.
// That way, we don't have to grapple with the problem of making Piece Codable, and of having to keep
// a reference to a Piece both in the Grid and in the interface. The Reducer knows the picName and
// whether the Piece is highlighted, and that's all. We could then pass the Grid in a State and let
// the presenter form the pieces. The Grid would thus become a pure source of truth for what's shown.
