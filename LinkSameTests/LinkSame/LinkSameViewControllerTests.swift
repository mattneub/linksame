import UIKit
@testable import LinkSame
import Testing
import WaitWhile

@MainActor
struct LinkSameViewControllerTests {
    let subject = LinkSameViewController()
    let screen = MockScreen()
    let processor = MockProcessor<LinkSameAction, LinkSameState, LinkSameEffect>()
    let transitionProviderMaker = MockTransitionProviderMaker()

    init() {
        services.screen = screen
        services.application = MockApplication()
        services.transitionProviderMaker = transitionProviderMaker
        MockApplication.methodsCalled.removeAll()
        MockApplication.bools.removeAll()
        subject.processor = processor
    }

    @Test("nib loaded to get view depends on phone/pad")
    func loadNibPhone() {
        screen.traitCollection = .init(userInterfaceIdiom: .phone)
        subject.loadViewIfNeeded()
        #expect(subject.hintButton == nil)
    }

    @Test("nib loaded to get view depends on phone/pad")
    func loadNibPad() {
        screen.traitCollection = .init(userInterfaceIdiom: .pad)
        subject.loadViewIfNeeded()
        #expect(subject.hintButton != nil)
    }

    @Test("viewDidLoad: label font size depends on 3x")
    func viewDidLoad2x() {
        screen.traitCollection = .init(displayScale: 2)
        subject.loadViewIfNeeded()
        #expect(subject.scoreLabel.font.pointSize == 24)
        #expect(subject.prevLabel.font.pointSize == 24)
        #expect(subject.stageLabel.font.pointSize == 24)
    }

    @Test("viewDidLoad: label font size depends on 3x")
    func viewDidLoad3x() {
        screen.traitCollection = .init(displayScale: 3)
        subject.loadViewIfNeeded()
        #expect(subject.scoreLabel.font.pointSize == 26)
        #expect(subject.prevLabel.font.pointSize == 26)
        #expect(subject.stageLabel.font.pointSize == 26)
    }

    @Test("viewDidLoad: sets hintLabel text and width")
    func viewDidLoadHintLabel() {
        screen.traitCollection = .init(userInterfaceIdiom: .pad)
        subject.loadViewIfNeeded()
        #expect(subject.hintButton.possibleTitles == ["Show Hint", "Hide Hint"]) // not that it matters
        #expect(subject.hintButton.title == "Show Hint")
        #expect(subject.hintButton.width == 110)
    }

    @Test("viewDidLoad: sends viewDidLoad")
    func viewDidLoad() async {
        subject.loadViewIfNeeded()
        await #while(processor.thingsReceived.isEmpty)
        #expect(processor.thingsReceived.first == .viewDidLoad)
    }

    @Test("viewDidLayoutSubviews: sends didInitialLayout the first time")
    func viewDidLayoutSubviews() async {
        subject.viewDidLayoutSubviews()
        await #while(!processor.thingsReceived.contains(.didInitialLayout))
        #expect(processor.thingsReceived.filter({$0 == .didInitialLayout}).count == 1)
        processor.thingsReceived = []
        subject.viewDidLayoutSubviews()
        try? await Task.sleep(for: .seconds(0.5))
        #expect(processor.thingsReceived.isEmpty)
    }

    @Test("present: boardViewHidden governs visibility of boardView")
    func presentBoardViewHidden() async {
        subject.loadViewIfNeeded()
        let boardView = MockBoardView()
        subject.backgroundView.addSubview(boardView)
        boardView.isHidden = false
        await subject.present(LinkSameState(boardViewHidden: true))
        #expect(boardView.isHidden == true)
        await subject.present(LinkSameState(boardViewHidden: false))
        #expect(boardView.isHidden == false)
    }

    @Test("present: interfaceMode configures interface")
    func presentBoardViewInterfaceMode() async {
        screen.traitCollection = .init(userInterfaceIdiom: .pad)
        subject.loadViewIfNeeded()
        await subject.present(LinkSameState(interfaceMode: .practice))
        #expect(subject.scoreLabel.isHidden == true)
        #expect(subject.prevLabel.isHidden == true)
        #expect(subject.timedPractice.selectedSegmentIndex == 1)
        #expect(subject.timedPractice.isEnabled == false)
        #expect(subject.restartStageButton.isEnabled == false)
        await subject.present(LinkSameState(interfaceMode: .timed))
        #expect(subject.scoreLabel.isHidden == false)
        #expect(subject.prevLabel.isHidden == false)
        #expect(subject.timedPractice.selectedSegmentIndex == 0)
        #expect(subject.timedPractice.isEnabled == true)
        #expect(subject.restartStageButton.isEnabled == true)
    }

    @Test("present: stageLabelText configures stageLabel")
    func presentStageLabelText() async {
        screen.traitCollection = .init(userInterfaceIdiom: .pad)
        subject.loadViewIfNeeded()
        await subject.present(LinkSameState(stageLabelText: "howdy"))
        #expect(subject.stageLabel?.text == "howdy")
    }

    @Test("receive animateBoardTransition: shows the board view, performs the transition")
    func animateBoardTransition() async throws {
        makeWindow(viewController: subject)
        subject.loadViewIfNeeded()
        let view = MockBoardView()
        await subject.receive(.putBoardViewIntoInterface(view))
        subject.view.setNeedsLayout()
        view.isHidden = true
        await subject.receive(.animateBoardTransition(.fade))
        #expect(view.isHidden == false)
        let transitionProvider = transitionProviderMaker.mockTransitionProvider
        #expect(transitionProvider.methodsCalled == ["performTransition(transition:layer:)"])
        #expect(transitionProvider.layer == view.layer)
        let transition = try #require(transitionProvider.transition)
        #expect(transition.type == .fade)
        #expect(transition.duration == 0.7)
        #expect(transition.fillMode == .backwards)
        #expect(transition.timingFunction == CAMediaTimingFunction(name: .linear))
    }

    @Test("receive animateStageLabel: performs label transition animation")
    func animateStageLabel() async throws {
        services.view = MockUIView.self
        MockUIView.methodsCalled = []
        makeWindow(viewController: subject)
        subject.loadViewIfNeeded()
        await subject.receive(.animateStageLabel)
        #expect(MockUIView.methodsCalled == ["transitionAsync(with:duration:options:)"])
    }

    @Test("receive: putBoard puts the board view into the interface")
    func receivePutBoard() async {
        screen.traitCollection = .init(userInterfaceIdiom: .pad)
        makeWindow(viewController: subject)
        subject.loadViewIfNeeded()
        let view = MockBoardView()
        await subject.receive(.putBoardViewIntoInterface(view))
        subject.view.setNeedsLayout()
        #expect(subject.boardView == view)
        #expect(subject.backgroundView.bounds == view.bounds)
        #expect(view.translatesAutoresizingMaskIntoConstraints == false)
        let view2 = MockBoardView()
        await subject.receive(.putBoardViewIntoInterface(view2))
        subject.view.setNeedsLayout()
        #expect(subject.boardView == view2)
        #expect(subject.backgroundView.bounds == view2.bounds)
        #expect(view2.translatesAutoresizingMaskIntoConstraints == false)
        #expect(view.superview == nil)
        let constraints = subject.backgroundView.constraints
        print(constraints)
        #expect(constraints.count == 4)
        #expect(constraints.allSatisfy { $0.firstItem as? UIView === subject.backgroundView })
        #expect(constraints.allSatisfy { $0.secondItem as? UIView === view2 })
        let firsts = constraints.map { $0.firstAttribute }
        let expected: [NSLayoutConstraint.Attribute] = [.top, .bottom, .leading, .trailing]
        #expect(Set(firsts) == Set(expected))
        #expect(constraints.allSatisfy { $0.firstAttribute == $0.secondAttribute })
    }

    @Test("receive userInteraction: calls application userInteraction")
    func userInteraction() async {
        await subject.receive(.userInteraction(false))
        #expect(MockApplication.methodsCalled == ["userInteraction(_:)"])
        #expect(MockApplication.bools == [false])
        await subject.receive(.userInteraction(true))
        #expect(MockApplication.methodsCalled == ["userInteraction(_:)", "userInteraction(_:)"])
        #expect(MockApplication.bools == [false, true])
    }

}
