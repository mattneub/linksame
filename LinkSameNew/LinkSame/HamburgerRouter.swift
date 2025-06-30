import UIKit

/// Protocol describing our hamburger router, so we can mock it for testing.
@MainActor
protocol HamburgerRouterType {
    var options: [String] { get }
    func makeMenu(processor: any Processor<LinkSameAction, LinkSameState, LinkSameEffect>) async -> UIMenu
}

/// Router for the hamburger button.
@MainActor
final class HamburgerRouter: HamburgerRouterType {
    /// Choices for the hamburger button's action sheet.
    enum HamburgerChoices: String, CaseIterable {
        case game = "New Game"
        case hint = "Show Hint"
        case shuffle = "Shuffle"
        case restart = "Restart Stage"
        case practice = "Practice Mode"
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
        case .restart: await processor.receive(.restartStage)
        case .practice: await processor.receive(.timedPractice(1))
        case .shuffle: await processor.receive(.shuffle)
        }
    }
    func makeMenu(processor: any Processor<LinkSameAction, LinkSameState, LinkSameEffect>) async -> UIMenu {
        var actions = [UIAction]()
        for option in options {
            let action = UIAction(title: option) { [weak self, weak processor] action in
                Task {
                    if let processor {
                        await self?.doChoice(action.title, processor: processor)
                    }
                }
            }
            actions.append(action)
        }
        let menu = UIMenu(title: "", image: nil, identifier: nil, options: [], children: actions)
        return menu
    }
}
