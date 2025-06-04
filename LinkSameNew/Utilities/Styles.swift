import Foundation

/// A style is a named set of images. The user gets to pick which set should be used as the images
/// on the visible pieces.
@MainActor
struct Styles {
    /// Constants, with string values for display in the interface as well as for reference,
    /// as values in user defaults, etc.
    static let animals = "Animals"
    static let snacks = "Snacks"

    /// The order in which the style values are displayed in the interface.
    static var stylesInOrder: [String] { [animals, snacks] }

    /// Image numbers, for obtaining the images for a given style. Given a number n, `foods/n.png`
    /// is the corresponding image file.
    /// The first number in each pair is the start of the run of 9 basic pieces (for Easy size).
    /// The second number in each pair is the start of the run of additional pieces (for remaining sizes).
    /// - Parameter styleName: A string equal to one of our styles constants.
    /// - Returns: The image numbers.
    static func pieces(_ styleName: String) -> (basic: Int, additional: Int) {
        switch styleName {
        case animals: (basic: 11, additional: 110)
        case snacks: (basic: 21, additional: 210)
        default: (basic: 11, additional: 110) // shouldn't happen
        }
    }
}
