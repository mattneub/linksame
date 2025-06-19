/// Transient commands from the processor to the presenter.
enum BoardEffect {
    /// Put the given piece onto the board, in accordance with its column and row.
    case insert(piece: Piece)
    /// Turn user interaction off or on.
    case userInteraction(Bool)
}
