/// Messages from the presenter to the processor.
enum BoardAction: Equatable {
    case tapped(PieceReducer)
}
