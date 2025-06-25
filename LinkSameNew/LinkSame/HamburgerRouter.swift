import Foundation

/// Protocol describing our hamburger router, so we can mock it for testing.
@MainActor
protocol HamburgerRouterType {
    var options: [String] { get }
    func doChoice(_ choice: String?, processor: any Processor<LinkSameAction, LinkSameState, LinkSameEffect>) async
}

/// Router for the hamburger button.
@MainActor
final class HamburgerRouter: HamburgerRouterType {
    /// Choices for the hamburger button's action sheet.
    enum HamburgerChoices: String, CaseIterable {
        case game = "Game"
        case hint = "Hint"
        case shuffle = "Shuffle"
        case restart = "Restart Stage"
        case help = "Help"
    }
    var options: [String] {
        HamburgerChoices.allCases.map { $0.rawValue }
    }
    func doChoice(_ choice: String?, processor: any Processor<LinkSameAction, LinkSameState, LinkSameEffect>) async {
        guard let choice else {
            return
        }
        guard let which = HamburgerChoices(rawValue: choice) else {
            return
        }
        switch which {
        case .game: await processor.receive(.showNewGame(sender: nil))
        case .help: await processor.receive(.showHelp(sender: nil))
        case .hint: await processor.receive(.hint)
        case .restart: break // TODO: write restart stage when we have a score
        case .shuffle: await processor.receive(.shuffle)
        }
    }
}
