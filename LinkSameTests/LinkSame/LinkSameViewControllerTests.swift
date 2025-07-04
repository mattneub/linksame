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
        #expect(subject.hintButton == nil) // no need to check the others
        #expect(subject.hamburgerButton != nil)
        #expect(subject.practiceLabel != nil)
        #expect(subject.practiceLabel?.isHidden == true)
        #expect(subject.prevLabel.text == " ")
        #expect(subject.scoreLabel.text == " ")
    }

    @Test("nib loaded to get view depends on phone/pad")
    func loadNibPad() {
        screen.traitCollection = .init(userInterfaceIdiom: .pad)
        subject.loadViewIfNeeded()
        #expect(subject.hintButton != nil) // no need to check the others
        #expect(subject.hamburgerButton == nil)
        #expect(subject.practiceLabel == nil)
        #expect(subject.prevLabel.text == " ")
        #expect(subject.scoreLabel.text == " ")
    }

    @Test("viewDidLoad: label font size depends on 3x")
    func viewDidLoad2xPhone() {
        screen.traitCollection = UITraitCollection { traits in
            traits.userInterfaceIdiom = .phone
            traits.displayScale = 2
        }
        subject.loadViewIfNeeded()
        #expect(subject.scoreLabel.font.pointSize == 15)
        #expect(subject.prevLabel.font.pointSize == 15)
        #expect(subject.stageLabel.font.pointSize == 15)
        #expect(subject.practiceLabel?.font.pointSize == 15)
    }

    @Test("viewDidLoad: label font size depends on 3x")
    func viewDidLoad3xPhone() {
        screen.traitCollection = UITraitCollection { traits in
            traits.userInterfaceIdiom = .phone
            traits.displayScale = 3
        }
        subject.loadViewIfNeeded()
        #expect(subject.scoreLabel.font.pointSize == 17)
        #expect(subject.prevLabel.font.pointSize == 17)
        #expect(subject.stageLabel.font.pointSize == 17)
        #expect(subject.practiceLabel?.font.pointSize == 17)
    }

    @Test("viewDidLoad: label font size depends on 3x")
    func viewDidLoad2xPad() {
        screen.traitCollection = UITraitCollection { traits in
            traits.userInterfaceIdiom = .pad
            traits.displayScale = 2
        }
        subject.loadViewIfNeeded()
        #expect(subject.scoreLabel.font.pointSize == 24)
        #expect(subject.prevLabel.font.pointSize == 24)
        #expect(subject.stageLabel.font.pointSize == 24)
    }

    @Test("viewDidLoad: label font size depends on 3x")
    func viewDidLoad3xPad() {
        screen.traitCollection = UITraitCollection { traits in
            traits.userInterfaceIdiom = .pad
            traits.displayScale = 3
        }
        subject.loadViewIfNeeded()
        #expect(subject.scoreLabel.font.pointSize == 26)
        #expect(subject.prevLabel.font.pointSize == 26)
        #expect(subject.stageLabel.font.pointSize == 26)
    }

    @Test("viewDidLoad: sets hintLabel text and width")
    func viewDidLoadHintLabel() {
        screen.traitCollection = .init(userInterfaceIdiom: .pad)
        subject.loadViewIfNeeded()
        // #expect(subject.hintButton.possibleTitles == ["Show Hint", "Hide Hint"]) // not that it matters
        #expect(subject.hintButton?.title == "Show Hint")
        #expect(subject.hintButton?.width == 110)
    }

    @Test("viewDidLoad: configures hamburger button")
    func viewDidLoadHamburger() {
        screen.traitCollection = .init(userInterfaceIdiom: .phone)
        subject.loadViewIfNeeded()
        #expect(subject.hamburgerButton?.actions(forTarget: subject, forControlEvent: .menuActionTriggered)?.first == "doHamburgerButton:")
        #expect(subject.hamburgerButton?.preferredMenuElementOrder == .fixed)
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

    @Test("present: interfaceMode configures interface on iPad")
    func presentBoardViewInterfaceModePad() async {
        screen.traitCollection = .init(userInterfaceIdiom: .pad)
        subject.loadViewIfNeeded()
        await subject.present(LinkSameState(interfaceMode: .practice))
        #expect(subject.scoreLabel.isHidden == true)
        #expect(subject.prevLabel.isHidden == true)
        #expect(subject.timedPractice?.selectedSegmentIndex == 1)
        #expect(subject.timedPractice?.isEnabled == false)
        await subject.present(LinkSameState(interfaceMode: .timed))
        #expect(subject.scoreLabel.isHidden == false)
        #expect(subject.prevLabel.isHidden == false)
        #expect(subject.timedPractice?.selectedSegmentIndex == 0)
        #expect(subject.timedPractice?.isEnabled == true)
        #expect(subject.restartStageButton?.isEnabled == true)
    }

    @Test("present: interfaceMode configures interface on iPhone")
    func presentBoardViewInterfaceModePhone() async {
        screen.traitCollection = .init(userInterfaceIdiom: .phone)
        subject.loadViewIfNeeded()
        await subject.present(LinkSameState(interfaceMode: .practice))
        #expect(subject.scoreLabel.isHidden == true)
        #expect(subject.prevLabel.isHidden == true)
        #expect(subject.practiceLabel?.isHidden == false)
        await subject.present(LinkSameState(interfaceMode: .timed))
        #expect(subject.scoreLabel.isHidden == false)
        #expect(subject.prevLabel.isHidden == false)
        #expect(subject.practiceLabel?.isHidden == true)
    }

    @Test("present: stageLabelText configures stageLabel")
    func presentStageLabelText() async {
        screen.traitCollection = .init(userInterfaceIdiom: .pad)
        subject.loadViewIfNeeded()
        await subject.present(LinkSameState(stageLabelText: "howdy"))
        #expect(subject.stageLabel?.text == "howdy")
    }

    @Test("present: score configures score label")
    func presentScore() async {
        subject.loadViewIfNeeded()
        subject.scoreLabel.textColor = .blue
        await(subject.present(LinkSameState(score: .init(score: 100, direction: .up))))
        #expect(subject.scoreLabel.text == "100")
        #expect(subject.scoreLabel.textColor == .black)
        await(subject.present(LinkSameState(score: .init(score: 100, direction: .down))))
        #expect(subject.scoreLabel.text == "100")
        #expect(subject.scoreLabel.textColor == .red)
    }

    @Test("present: highScore configures prev label")
    func presentHighScore() async {
        subject.loadViewIfNeeded()
        subject.prevLabel.text = "hello"
        await(subject.present(LinkSameState(highScore: "howdy")))
        #expect(subject.prevLabel.text == "howdy")
    }

    @Test("present: hintButtonTitle configures hint button")
    func presentHintButtonTitle() async {
        screen.traitCollection = .init(userInterfaceIdiom: .pad)
        subject.loadViewIfNeeded()
        await subject.present(LinkSameState(hintButtonTitle: .show))
        #expect(subject.hintButton?.title == "Show Hint")
        await subject.present(LinkSameState(hintButtonTitle: .hide))
        #expect(subject.hintButton?.title == "Hide Hint")
    }

    @Test("receive animateBoardTransition: shows the board view, performs the transition")
    func animateBoardTransition() async throws {
        makeWindow(viewController: subject)
        subject.loadViewIfNeeded()
        let view = MockBoardView(columns: 1, rows: 1)
        view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        subject.backgroundView.addSubview(view)
        view.layer.opacity = 0
        await subject.receive(.animateBoardTransition(.fade))
        #expect(view.layer.opacity == 1)
        let transitionProvider = transitionProviderMaker.mockTransitionProvider
        #expect(transitionProvider.methodsCalled == ["performTransition(transition:layer:)"])
        #expect(transitionProvider.layer == view.layer)
        let transition = try #require(transitionProvider.transition)
        #expect(transition.type == .fade)
        #expect(transition.duration == 0.7)
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

    @Test("receive setHamburgerButton: sets hamburger button menu")
    func setHamburgerButton() async {
        screen.traitCollection = .init(userInterfaceIdiom: .phone)
        subject.loadViewIfNeeded()
        #expect(subject.hamburgerButton?.menu == nil)
        await subject.receive(.setHamburgerMenu(UIMenu()))
        #expect(subject.hamburgerButton?.menu != nil)
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

    @Test("doRestartStage: sends restartStage to processor")
    func doRestartStage() async throws {
        subject.doRestartStage(nil)
        await #while(processor.thingsReceived.isEmpty)
        #expect(processor.thingsReceived.first == .restartStage)
    }

    @Test("doShuffle: sends shuffle to processor")
    func doShuffle() async throws {
        subject.doShuffle(nil)
        await #while(processor.thingsReceived.isEmpty)
        #expect(processor.thingsReceived.first == .shuffle)
    }

    @Test("toggleHint: sends hint to processor")
    func toggleHint() async throws {
        subject.toggleHint(nil)
        await #while(processor.thingsReceived.isEmpty)
        #expect(processor.thingsReceived.first == .hint)
    }

    @Test("doNew: sends showNewGame to processor")
    func doNew() async {
        let source = UIView()
        subject.doNew(source)
        await #while(processor.thingsReceived.isEmpty)
        #expect(processor.thingsReceived.first == .showNewGame(sender: source))
    }

    @Test("doTimedPractice: sends timedPractice to processor")
    func doTimedPractice() async {
        let segmented = UISegmentedControl(items: ["Hey", "Ho"])
        segmented.selectedSegmentIndex = 1
        subject.doTimedPractice(segmented)
        await #while(processor.thingsReceived.isEmpty)
        #expect(processor.thingsReceived.first == .timedPractice(1))
    }

    @Test("doHelp: sends showHelp to processor")
    func doHelp() async {
        let source = UIView()
        subject.doHelp(source)
        await #while(processor.thingsReceived.isEmpty)
        #expect(processor.thingsReceived.first == .showHelp(sender: source))
    }

    @Test("doHamburgerButton: sends hamburger to processor")
    func doHamburgerButton() async {
        subject.doHamburgerButton(UIView())
        await #while(processor.thingsReceived.isEmpty)
        #expect(processor.thingsReceived.first == .hamburger)
    }

}
