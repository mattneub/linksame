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
        let boardView = MockBoardView(columns: 1, rows: 1)
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
        let view = MockBoardView(columns: 1, rows: 1)
        view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        subject.backgroundView.addSubview(view)
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
        #expect(MockUIView.methodsCalled.first == "transitionAsync(with:duration:options:)")
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

    @Test("doShuffle: sends shuffle to processor")
    func doShuffle() async throws {
        subject.doShuffle(nil)
        await #while(processor.thingsReceived.isEmpty)
        #expect(processor.thingsReceived.first == .shuffle)
    }

}
