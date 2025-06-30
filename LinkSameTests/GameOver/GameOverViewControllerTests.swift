import UIKit
@testable import LinkSame
import Testing
import WaitWhile
import SnapshotTesting

@MainActor
struct GameOverViewControllerTests {
    let subject = GameOverViewController()
    let processor = MockProcessor<GameOverAction, GameOverState, Void>()

    init() {
        subject.processor = processor
    }

    @Test("scoreLabel is correctly configured")
    func scoreLabel() {
        #expect(subject.scoreLabel.numberOfLines == 0)
        #expect(subject.scoreLabel.textAlignment == .center)
        #expect(subject.scoreLabel.textColor == .black)
        #expect(subject.scoreLabel.font == UIFont(name: "Arial Rounded MT Bold", size: 26))
        #expect(subject.scoreLabel.translatesAutoresizingMaskIntoConstraints == false)
    }

    @Test("newHighLabel is correctly configured")
    func newHighLabel() {
        #expect(subject.newHighLabel.numberOfLines == 0)
        #expect(subject.newHighLabel.textAlignment == .center)
        #expect(subject.newHighLabel.textColor == .black)
        #expect(subject.newHighLabel.font == UIFont(name: "Arial Rounded MT Bold", size: 26))
        #expect(subject.newHighLabel.translatesAutoresizingMaskIntoConstraints == false)
        #expect(subject.newHighLabel.text == "That is a new high score for this level!")
    }

    @Test("backgroundView is correctly configured")
    func backgroundView() {
        #expect(subject.backgroundView.backgroundColor == .systemYellow)
        #expect(subject.backgroundView.translatesAutoresizingMaskIntoConstraints == false)
        #expect(subject.backgroundView.layer.cornerRadius == 6)
    }

    @Test("viewDidLoad: sets background to clear, calls processor .viewDidLoad, configures subviews")
    func viewDidLoad() async {
        subject.loadViewIfNeeded()
        #expect(subject.view.backgroundColor == .clear)
        await #while(processor.thingsReceived.isEmpty)
        #expect(processor.thingsReceived == [.viewDidLoad])
        #expect(subject.backgroundView.isDescendant(of: subject.view))
        #expect(subject.scoreLabel.isDescendant(of: subject.backgroundView))
        #expect(subject.newHighLabel.isDescendant(of: subject.backgroundView))
    }

    @Test("present: behaves as expected")
    func present() async {
        var state = GameOverState(newHigh: false, score: 30, practice: false)
        await(subject.present(state))
        #expect(subject.scoreLabel.text == "You have finished the game with a score of 30.")
        #expect(subject.newHighLabel.isHidden == true)
        //
        state.newHigh = true
        await(subject.present(state))
        #expect(subject.scoreLabel.text == "You have finished the game with a score of 30.")
        #expect(subject.newHighLabel.isHidden == false)
        //
        state.practice = true
        await(subject.present(state))
        #expect(subject.scoreLabel.text == "End of practice game.")
        #expect(subject.newHighLabel.isHidden == true)
    }

    @Test("view looks correct, not new high")
    func snapshotNotNewHigh() async {
        let window = makeWindow(viewController: subject)
        window.layoutIfNeeded()
        let state = GameOverState(newHigh: false, score: 30, practice: false)
        await(subject.present(state))
        assertSnapshot(of: subject.view, as: .image)
    }

    @Test("view looks correct, new high")
    func snapshotNewHigh() async {
        let window = makeWindow(viewController: subject)
        window.layoutIfNeeded()
        let state = GameOverState(newHigh: true, score: 30, practice: false)
        await(subject.present(state))
        assertSnapshot(of: subject.view, as: .image)
    }

    @Test("view looks correct, practice")
    func snapshotPractice() async {
        let window = makeWindow(viewController: subject)
        window.layoutIfNeeded()
        let state = GameOverState(newHigh: true, score: 30, practice: true)
        await(subject.present(state))
        assertSnapshot(of: subject.view, as: .image)
    }

    @Test("userTapped: calls processor .tapped")
    func userTapped() async {
        subject.userTapped()
        await #while(processor.thingsReceived.isEmpty)
        #expect(processor.thingsReceived == [.tapped])
    }
}
