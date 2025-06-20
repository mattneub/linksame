/// Transient commands from the processor to the presenter.
enum BoardEffect: Equatable {
    /// Put the given piece onto the board, in accordance with its column and row.
    case insert(piece: PieceReducer)
    /// Remove a piece from the board, corresponding with the given reducer (and throw it away).
    case remove(piece: PieceReducer)
    /// Turn user interaction off or on.
    case userInteraction(Bool)
}
