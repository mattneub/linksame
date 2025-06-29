import Foundation

/// Processor for the game over module.
@MainActor
final class GameOverProcessor: Processor {
    /// Reference to the presenter, set by coordinator on creation.
    weak var presenter: (any ReceiverPresenter<Void, GameOverState>)?

    /// Reference to the coordinator, set by coordinator on creation.
    weak var coordinator: (any RootCoordinatorType)?

    /// State to be presented by the presenter.
    var state = GameOverState()

    func receive(_ action: GameOverAction) async {
        switch action {
        case .tapped:
            coordinator?.dismiss()
        case .viewDidLoad:
            await presenter?.present(state)
        }
    }
}
