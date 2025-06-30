import Foundation

/// Processor for the game over module.
@MainActor
final class GameOverProcessor: Processor {
    /// Reference to the presenter, set by coordinator on creation.
    weak var presenter: (any ReceiverPresenter<Void, GameOverState>)?

    /// Reference to the coordinator, set by coordinator on creation.
    weak var coordinator: (any RootCoordinatorType)?

    /// State to be presented by the presenter. Initial value will be replaced by coordinator.
    var state = GameOverState(newHigh: false, score: 0, practice: false)

    func receive(_ action: GameOverAction) async {
        switch action {
        case .tapped:
            coordinator?.dismiss()
        case .viewDidLoad:
            await presenter?.present(state)
        }
    }
}
