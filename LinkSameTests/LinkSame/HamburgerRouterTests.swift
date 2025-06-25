import Foundation
@testable import LinkSame
import Testing
import WaitWhile

@MainActor
struct HamburgerRouterTests {
    let subject = HamburgerRouter()

    @Test("options: gives the expected list")
    func options() {
        let options = subject.options
        #expect(options == ["Game", "Hint", "Shuffle", "Restart Stage", "Help"])
    }

    @Test("doChoice: sends the correct message to the processor")
    func doChoice() async {
        let processor = MockProcessor<LinkSameAction, LinkSameState, LinkSameEffect>()
        do {
            await subject.doChoice("Game", processor: processor)
            #expect(processor.thingsReceived.first == .showNewGame(sender: nil))
        }
        processor.thingsReceived = []
        do {
            await subject.doChoice("Hint", processor: processor)
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
            await subject.doChoice("Help", processor: processor)
            #expect(processor.thingsReceived.first == .showHelp(sender: nil))
        }
    }
}
