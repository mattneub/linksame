@testable import LinkSame
import Foundation

@MainActor
final class MockHamburgerRouter: HamburgerRouterType {
    var options = [String]()
    var methodsCalled = [String]()
    var choice: String?

    func doChoice(_ choice: String?, processor: any LinkSame.Processor<LinkSame.LinkSameAction, LinkSame.LinkSameState, LinkSame.LinkSameEffect>) async {
        methodsCalled.append(#function)
        self.choice = choice
    }
}

