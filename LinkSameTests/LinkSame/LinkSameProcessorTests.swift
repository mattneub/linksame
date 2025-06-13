import UIKit
@testable import LinkSame
import Testing
import WaitWhile

@MainActor
struct LinkSameProcessorTests {
    let subject = LinkSameProcessor()
    let presenter = MockReceiverPresenter<LinkSameEffect, LinkSameState>()
    let coordinator = MockRootCoordinator()
    let persistence = MockPersistence()
    let screen = MockScreen()

    init() {
        subject.presenter = presenter
        subject.coordinator = coordinator
        services.persistence = persistence
        services.screen = screen
    }

    @Test("receive cancelNewGame: calls coordinator dismiss, saves prepopover defaults to real defaults, set prepover defaults to nil")
    func cancelNewGame() async {
        subject.state.defaultsBeforeShowingNewGamePopover = [.size: "Size", .style: "Style"]
        await subject.receive(.cancelNewGame)
        #expect(coordinator.methodsCalled == ["dismiss()"])
        #expect(persistence.methodsCalled == ["saveIndividually(_:)"])
        #expect(persistence.dict?.keys.count == 2)
        #expect(persistence.dict?[.size] as? String == "Size")
        #expect(persistence.dict?[.style] as? String == "Style")
    }

    @Test("receive didInitialLayout: gets board size from persistence, or Easy on phone; asks coordinator to make board processor")
    func didInitialLayout() async throws {
        screen.traitCollection = UITraitCollection { traits in // how to say, nowadays
            traits.userInterfaceIdiom = .phone
            traits.displayScale = 2
        }
        await subject.receive(.didInitialLayout)
        #expect(persistence.methodsCalled.count == 0) // on iPhone we don't bother to talk to persistence
        #expect(coordinator.methodsCalled == ["makeBoardProcessor(gridSize:)"])
        let gridSize = try #require(coordinator.gridSize)
        #expect(gridSize == (10, 6)) // on iPhone, persistence size is ignored, we only do Easy
        #expect(subject.boardProcessor != nil)
    }

    @Test("receive didInitialLayout: gets board size from persistence, or Easy on phone (3x); asks coordinator to make board processor")
    func didInitialLayout3x() async throws {
        screen.traitCollection = UITraitCollection { traits in
            traits.userInterfaceIdiom = .phone
            traits.displayScale = 3
        }
        await subject.receive(.didInitialLayout)
        #expect(persistence.methodsCalled.count == 0) // on iPhone we don't bother to talk to persistence
        #expect(coordinator.methodsCalled == ["makeBoardProcessor(gridSize:)"])
        let gridSize = try #require(coordinator.gridSize)
        #expect(gridSize == (12, 7)) // on iPhone, persistence size is ignored, we only do Easy
        #expect(subject.boardProcessor != nil)
    }

    @Test("receive didInitialLayout: gets board size from persistence on iPad; asks coordinator to make board processor")
    func didInitialLayoutPad() async throws {
        persistence.string = ["Hard"]
        screen.traitCollection = UITraitCollection { traits in
            traits.userInterfaceIdiom = .pad
            traits.displayScale = 2
        }
        await subject.receive(.didInitialLayout)
        #expect(persistence.methodsCalled.count == 1)
        #expect(persistence.methodsCalled.first == "loadString(forKey:)")
        #expect(persistence.keys.first == .size)
        #expect(coordinator.methodsCalled == ["makeBoardProcessor(gridSize:)"])
        let gridSize = try #require(coordinator.gridSize)
        #expect(gridSize == (16, 9)) // hard size
        #expect(subject.boardProcessor != nil)
    }

    @Test("receive didInitialLayout: sends .userInteraction, .putBoard, .animatedBoardTransition, sets stageNumber, makes stage, tells board create deck")
    func didInitialLayoutThenWhat() async throws {
        persistence.string = ["Hard"]
        screen.traitCollection = UITraitCollection { traits in
            traits.userInterfaceIdiom = .pad
            traits.displayScale = 2
        }
        await subject.receive(.didInitialLayout)
        let board = try #require(subject.boardProcessor as? MockBoardProcessor)
        #expect(presenter.thingsReceived.count == 4)
        #expect(presenter.thingsReceived[0] == .userInteraction(false))
        #expect(presenter.thingsReceived[1] == .putBoardViewIntoInterface(board.view))
        #expect(presenter.thingsReceived[2] == .animateBoardTransition(.fade))
        #expect(presenter.thingsReceived[3] == .userInteraction(true))
        #expect(board.stageNumber == 0)
        #expect(board.methodsCalled.first == "createAndDealDeck()")
        #expect(subject.stage != nil)
    }

    @Test("receive saveBoardState: saves the board state to persistence")
    func saveBoardState() async throws {
        subject.boardProcessor = BoardProcessor(gridSize: (1,1))
        subject.stage = Stage()
        subject.stage?.score = 1
        await subject.receive(.saveBoardState)
        try? await Task.sleep(for: .seconds(0.1))
        services.lifetime.didEnterBackgroundPublisher.send()
        await #while(persistence.methodsCalled.isEmpty)
        #expect(persistence.methodsCalled == ["save(_:forKey:)"])
        #expect(persistence.keys == [.boardData])
        let value = try #require(persistence.value)
        #expect(value is Data)
    }

    @Test("receive showHelp: tells the coordinator to showHelp")
    func showHelp() async {
        let view = UIView()
        await subject.receive(.showHelp(sender: view))
        #expect(coordinator.methodsCalled == ["showHelp(sourceItem:popoverPresentationDelegate:)"])
        #expect(coordinator.sourceItem === view)
        #expect(coordinator.popoverPresentationDelegate is HelpPopoverDelegate)
    }

    @Test("receive showNewGame: tells the coordinator to showNewGame, saves a copy of defaults that the user might change")
    func showNewGame() async throws {
        let view = UIView()
        persistence.dict = [.style: "Animals", .size: "Hard", .lastStage: 7]
        await subject.receive(.showNewGame(sender: view))
        #expect(coordinator.methodsCalled == ["showNewGame(sourceItem:popoverPresentationDelegate:dismissalDelegate:)"])
        #expect(coordinator.sourceItem === view)
        #expect(coordinator.popoverPresentationDelegate is NewGamePopoverDelegate)
        #expect(coordinator.dismissalDelegate === presenter)
        let defs = try #require(subject.state.defaultsBeforeShowingNewGamePopover)
        #expect(defs[.style] as? String == "Animals")
        #expect(defs[.size] as? String == "Hard")
        #expect(defs[.lastStage] as? Int == 7)
    }

    @Test("receive startNewGame: calls coordinator dismiss, nilifies copy of defaults, sets and presents state interface mode")
    func startNewGame() async {
        subject.state.defaultsBeforeShowingNewGamePopover = [.style: "Animals"]
        subject.state.interfaceMode = .practice
        await subject.receive(.startNewGame)
        #expect(coordinator.methodsCalled == ["dismiss()"])
        #expect(subject.state.defaultsBeforeShowingNewGamePopover == nil)
        #expect(presenter.statesPresented.last?.interfaceMode == .timed)
    }

    @Test("receive timedPractice: presents state with corresponding interfaceMode")
    func timedPractice() async {
        subject.state.interfaceMode = .practice
        await subject.receive(.timedPractice(0))
        #expect(presenter.statesPresented.last?.interfaceMode == .timed)
        await subject.receive(.timedPractice(1))
        #expect(presenter.statesPresented.last?.interfaceMode == .practice)
    }

    @Test("receive viewDidLoad: creates the subscriptions task")
    func viewDidLoad() async {
        #expect(subject.subscriptionsTask == nil)
        await subject.receive(.viewDidLoad)
        #expect(subject.subscriptionsTask != nil)
    }

    @Test("after .viewDidLoad, lifetime didEnterBackground if state interface mode is .timed presents state with boardViewHidden")
    func didEnterBackgroundTimed() async {
        subject.state.interfaceMode = .timed
        await subject.receive(.viewDidLoad)
        try? await Task.sleep(for: .seconds(0.1))
        services.lifetime.didEnterBackgroundPublisher.send()
        await #while(presenter.statesPresented.isEmpty)
        #expect(presenter.statesPresented.first?.boardViewHidden == true)
    }

    @Test("after .viewDidLoad, lifetime didEnterBackground if state interface mode is .practice saves the board state to persistence")
    func didEnterBackgroundPractice() async throws {
        subject.state.interfaceMode = .practice
        subject.boardProcessor = BoardProcessor(gridSize: (1,1))
        subject.stage = Stage()
        subject.stage?.score = 1
        await subject.receive(.viewDidLoad)
        try? await Task.sleep(for: .seconds(0.1))
        services.lifetime.didEnterBackgroundPublisher.send()
        await #while(persistence.methodsCalled.isEmpty)
        #expect(persistence.methodsCalled == ["save(_:forKey:)"])
        #expect(persistence.keys == [.boardData])
        let value = try #require(persistence.value)
        #expect(value is Data)
    }
}

/// We need this so that the processor sees its presenter as a dismissal delegate;
/// but I expect all this to change when I move the delegate to the subject itself!
extension MockReceiverPresenter: NewGamePopoverDismissalButtonDelegate {
    func cancelNewGame() {}
    
    func startNewGame() {}
}
