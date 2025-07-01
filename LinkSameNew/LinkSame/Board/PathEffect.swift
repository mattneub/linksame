import Foundation

/// Transient messages from the board processor to the path view.
enum PathEffect: Equatable {
    /// Draw the path connecting the giving points.
    case illuminate([CGPoint])
    /// Draw nothing.
    case unilluminate
}
