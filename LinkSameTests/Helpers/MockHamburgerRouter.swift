@testable import LinkSame
import UIKit

@MainActor
final class MockHamburgerRouter: HamburgerRouterType {

    var options = [String]()
    var methodsCalled = [String]()

    func makeMenu(processor: any LinkSame.Processor<LinkSame.LinkSameAction, LinkSame.LinkSameState, LinkSame.LinkSameEffect>) async -> UIMenu {
        methodsCalled.append(#function)
        return UIMenu()
    }
}

