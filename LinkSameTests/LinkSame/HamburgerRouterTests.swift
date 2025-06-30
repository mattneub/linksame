import UIKit
@testable import LinkSame
import Testing
import WaitWhile

@MainActor
struct HamburgerRouterTests {
    let subject = HamburgerRouter()

    @Test("options: gives the expected list")
    func options() {
        let options = subject.options
        #expect(options == ["New Game", "Show Hint", "Shuffle", "Restart Stage", "Practice Mode", "Help"])
    }

    @Test("doChoice: sends the correct message to the processor")
    func doChoice() async {
        let processor = MockProcessor<LinkSameAction, LinkSameState, LinkSameEffect>()
        do {
            await subject.doChoice("New Game", processor: processor)
            #expect(processor.thingsReceived.first == .showNewGame(sender: nil))
        }
        processor.thingsReceived = []
        do {
            await subject.doChoice("Show Hint", processor: processor)
            #expect(processor.thingsReceived.first == .hint)
        }
        processor.thingsReceived = []
        do {
            await subject.doChoice("Shuffle", processor: processor)
            #expect(processor.thingsReceived.first == .shuffle)
        }
        processor.thingsReceived = []
        do {
            await subject.doChoice("Restart Stage", processor: processor)
            #expect(processor.thingsReceived.first == .restartStage)
        }
        processor.thingsReceived = []
        do {
            await subject.doChoice("Practice Mode", processor: processor)
            #expect(processor.thingsReceived.first == .timedPractice(1))
        }
        processor.thingsReceived = []
        do {
            await subject.doChoice("Help", processor: processor)
            #expect(processor.thingsReceived.first == .showHelp(sender: nil))
        }
    }

    @Test("makeMenu: constructs the menu correctly")
    func makeMenu() async throws {
        let processor = MockProcessor<LinkSameAction, LinkSameState, LinkSameEffect>()
        let menu = await subject.makeMenu(processor: processor)
        let titles = menu.children.map { $0.title }
        #expect(titles == ["New Game", "Show Hint", "Shuffle", "Restart Stage", "Practice Mode", "Help"])
        let actions = menu.children.map { $0 as! UIAction }
        for action in actions {
            action.performWithSender(nil, target: nil)
        }
        await #while(processor.thingsReceived.count < 6)
        #expect(processor.thingsReceived == [
            .showNewGame(sender: nil),
            .hint,
            .shuffle,
            .restartStage,
            .timedPractice(1),
            .showHelp(sender: nil),
        ])
    }
}
