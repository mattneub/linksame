import Foundation

/// A size is a board grid size, i.e. how many tiles are displayed in each dimension.
/// The user gets to determine the board's size, except on iPhone where there is just one size.
@MainActor
struct Sizes {
    /// Constants, with string values for display in the interface as well as for reference,
    /// as values in user defaults, etc.
    static let easy = "Easy"
    static let normal = "Normal"
    static let hard = "Hard"

    /// The order in which the size values are displayed in the interface.
    static var sizesInOrder: [String] { [easy, normal, hard] }

    /// Private calculation of the Easy board size, which differs depending on whether we are
    /// on iPhone or iPad.
    private static var easySize: (columns: Int, rows: Int) {
        var result: (columns: Int, rows: Int) = onPhone ? (columns: 10, rows: 6) : (columns: 12, rows: 7)
        if on3xScreen { result = (columns: 12, rows: 7) }
        return result
    }

    /// Board size in columns and rows, given a size string.
    /// - Parameter sizeString: String corresponding to one of our size constants.
    /// - Returns: The board size.
    static func boardSize (_ sizeString: String) -> (columns: Int, rows: Int) {
        switch sizeString {
        case easy: easySize
        case normal: (columns: 14, rows: 8)
        case hard: (columns: 16, rows: 9)
        default: easySize // shouldn't happen
        }
    }
}

