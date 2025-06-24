import UIKit
@testable import LinkSame
import Testing

@MainActor
struct LinkSameActionTests {
    let sourceItem = UIView()

    @Test("Equality is defined as expected")
    func equality() {
        theTest(.cancelNewGame)
        theTest(.didInitialLayout)
        theTest(.hamburger)
        theTest(.hint)
        theTest(.saveBoardState)
        theTest(.showHelp(sender: sourceItem))
        theTest(.showNewGame(sender: sourceItem))
        theTest(.shuffle)
        theTest(.startNewGame)
        theTest(.timedPractice(1))
        theTest(.viewDidLoad)
    }

    func theTest(_ whichCase: LinkSameAction) {
        // Our actual raison d'etre is this switch statement, which helps ensure that we have
        // written an equality case after adding a new case to LinkSameAction.
        // It isn't that the test won't pass, it's that we won't even compile.
        switch whichCase {
        case .cancelNewGame:
            #expect(whichCase == .cancelNewGame)
        case .didInitialLayout:
            #expect(whichCase == .didInitialLayout)
        case .hamburger:
            #expect(whichCase == .hamburger)
        case .hint:
            #expect(whichCase == .hint)
        case .saveBoardState:
            #expect(whichCase == .saveBoardState)
        case .showHelp:
            #expect(whichCase == .showHelp(sender: sourceItem))
        case .showNewGame:
            #expect(whichCase == .showNewGame(sender: sourceItem))
        case .shuffle:
            #expect(whichCase == .shuffle)
        case .startNewGame:
            #expect(whichCase == .startNewGame)
        case .timedPractice:
            #expect(whichCase == .timedPractice(1))
        case .viewDidLoad:
            #expect(whichCase == .viewDidLoad)
        }
    }
}
