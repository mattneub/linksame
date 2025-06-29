import Foundation

/// State to be presented by the processor to the presenter.
struct GameOverState: Equatable {
    var newHigh = false
    var score = 0
}
