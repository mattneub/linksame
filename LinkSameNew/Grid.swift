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
struct Grid: Codable {
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
