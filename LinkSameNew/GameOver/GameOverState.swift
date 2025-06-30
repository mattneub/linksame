import Foundation

/// State to be presented by the processor to the presenter.
struct GameOverState: Equatable {
    var newHigh: Bool
    var score: Int
    var practice: Bool
}
