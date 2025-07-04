/// Transient commands from the processor to the presenter.
enum BoardEffect: Equatable {
    /// Draw the given path in the path layer.
    case illuminate(path: Path)
    /// Put the given piece onto the board, in accordance with its column and row.
    case insert(piece: PieceReducer)
    /// Perform the position changes described in the argument.
    case move([Movendum])
    /// Remove a piece from the board, corresponding with the given reducer (and throw it away).
    case remove(piece: PieceReducer)
    /// Transform the given piece to display the given picture, with animation.
    case transition(piece: PieceReducer, toPicture: String)
    /// Remove the contents of the path layer.
    case unilluminate
    /// Turn user interaction off or on.
    case userInteraction(Bool)
}
