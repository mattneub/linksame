/// Representation of the rectangular grid of pieces (or spaces) on which the game is played.
/// This is so that we can go directly and easily from a coordinate in the game grid to whatever
/// piece is at that coordinate. Maintained by the BoardProcessor.
///
/// **WARNING**: We have to be careful to maintain consistency between:
/// * where a Piece is in the Grid
/// * where that same Piece is in the Board
/// * where that same Piece thinks it is (its column and row)
///
@MainActor
struct Grid: Equatable, Codable {
    private(set) var grid: [[PieceReducer?]]
    let columns: Int
    let rows: Int
    init(columns: Int, rows: Int) {
        self.columns = columns
        self.rows = rows
        self.grid = Array(repeating: Array(repeating: nil, count: rows), count: columns)
    }
    /// Getter for the piece reducer at a given address. There is an imaginary border around the
    /// "borders" of our grid, one piece in thickness, for which we return `nil`. Addresses outside
    /// that border are illegal.
    subscript(column column: Int, row row: Int) -> PieceReducer? {
        get {
            // it is legal to ask for piece one slot outside boundaries, but not further
            assert(column >= -1 && column <= self.columns, "Piece requested out of bounds (column)")
            assert(row >= -1 && row <= self.rows, "Piece requested out of bounds (row)")
            // immediately outside boundaries, report slot as empty
            if (column == -1 || column == self.columns) { return nil }
            if (row == -1 || row == self.rows) { return nil }
            // inside boundaries, report actual contents of slot
            return grid[column][row]
        }
    }
    /// "Convenience" getter, for when the context has a Slot rather than individual column and
    /// row values. Simply calls the subscript getter for column and row, returning piece reducer.
    subscript(_ slot: Slot) -> PieceReducer? {
        get {
            self[column: slot.column, row: slot.row]
        }
    }
    /// Setter using just the name of the piece's picture and a given address; we create an actual
    /// piece reducer from that information. Unfortunately this means we also have to supply a
    /// getter, so now we have an ambiguous getter; but that's a small price to pay. And it turns out
    /// that I can demote the getter here so I never have to deal directly with the ambiguity.
    @_disfavoredOverload subscript(column column: Int, row row: Int) -> String? {
        get {
            grid[column][row]?.picName // TODO: what if we threw a fatal error here?
        }
        set(picName) {
            // it is illegal to set a value outside boundaries
            assert(column > -1 && column < self.columns, "Slot set out of bounds (column)")
            assert(row > -1 && row < self.rows, "Slot set out of bounds (row)")
            if let picName {
                grid[column][row] = PieceReducer(picName: picName, column: column, row: row)
            } else {
                grid[column][row] = nil
            }
        }
    }

    /// Is the grid empty? (This is how you know a stage has ended.)
    var isEmpty: Bool {
        grid.flatMap { $0 }.allSatisfy { $0 == nil }
    }
}

/// The address of a slot within the grid.
struct Slot: Equatable, Hashable {
    let column: Int
    let row: Int
}

/// Extra Slot initializer, because sometimes we are too busy to add external names.
extension Slot {
    init(_ column: Int, _ row: Int) {
        self.column = column
        self.row = row
    }
}

/// Expression of the concept of a path between a succession of slots.
typealias Path = [Slot]

/// A movendum is a temporary reducer describing the movement of a piece to new slot.
struct Movendum: Equatable {
    let piece: PieceReducer
    let newSlot: Slot
}
