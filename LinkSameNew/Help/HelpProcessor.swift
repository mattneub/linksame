import Foundation

/// Processor that contains the logic for the module.
@MainActor
final class HelpProcessor: Processor {
    /// Reference to the presenter, set by the coordinator on creation.
    weak var presenter: (any ReceiverPresenter<Void, HelpState>)?

    /// Reference to the coordinator, set by the coordinator on creation.
    weak var coordinator: (any RootCoordinatorType)?

    /// State to be presented by the presenter.
    var state = HelpState()

    func receive(_ action: HelpAction) async {
        switch action {
        case .dismiss:
            coordinator?.dismiss()
        case .viewDidLoad:
            guard let path = services.bundle.path(forResource: "linkhelp", ofType: "html") else {
                return
            }
            guard var content = try? String(contentsOfFile: path, encoding: .utf8) else {
                return
            }
            content = content
                .replacingOccurrences(of: "FIXME2", with: onPhone ? "30" : "5") // margin
                .replacingOccurrences(of: "FIXME", with: onPhone ? "8" : "12") // text size
            state.content = content
            await presenter?.present(state)
        }
    }
}
