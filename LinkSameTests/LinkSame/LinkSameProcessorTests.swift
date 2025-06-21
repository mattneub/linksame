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
    let stage = MockStage()
    let application = MockApplication()
    let board = MockBoardProcessor()

    init() {
        subject.presenter = presenter
        subject.coordinator = coordinator
        subject.boardProcessor = board
        services.persistence = persistence
        services.screen = screen
        services.application = application
    }

    @Test("stageLabelText: returns expected value")
    func stageLabelText() {
        board.stageNumber = 7
        persistence.int = 8
        #expect(subject.stageLabelText == "Stage 8 of 9") // adds 1 to each of those values
    }

    @Test("receive cancelNewGame: calls coordinator dismiss, saves prepopover defaults to real defaults, set prepover defaults to nil")
    func cancelNewGame() async {
        subject.state.defaultsBeforeShowingNewGamePopover = PopoverDefaults(lastStage: 7, size: "Size", style: "Style")
        await subject.receive(.cancelNewGame)
        #expect(coordinator.methodsCalled == ["dismiss()"])
        #expect(persistence.methodsCalled == ["saveIndividually(_:)"])
        #expect(persistence.dict?.keys.count == 3)
        #expect(persistence.dict?[.size] as? String == "Size")
        #expect(persistence.dict?[.style] as? String == "Style")
        #expect(persistence.dict?[.lastStage] as? Int == 7)
    }

    // There are three ways that the app can "awaken" which share functionality.
    // So we test all of them together, using this enum to configure the tests for each one.
    enum AwakeningType {
        case didInitialLayout // receive .didInitialLayout, i.e. launching cold
        case didBecomeActiveGameOver // didBecomeActive is called, and there is a .gameOver true default
        case didBecomeActiveComingBack // didBecomeActive is called, and state comingBack is true (i.e. we were backgrounded)
    }

    @Test("awakening with no saved data, gets board size from persistence, or Easy on phone; asks coordinator to make board processor",
          arguments: [AwakeningType.didInitialLayout, .didBecomeActiveGameOver, .didBecomeActiveComingBack]
    )
    func awakenNoSavedData(awakeningType: AwakeningType) async throws {
        screen.traitCollection = UITraitCollection { traits in // how to say, nowadays
            traits.userInterfaceIdiom = .phone
            traits.displayScale = 2
        }
        switch awakeningType {
        case .didInitialLayout:
            await subject.receive(.didInitialLayout)
        case .didBecomeActiveGameOver:
            persistence.bool = true
            await subject.didBecomeActive()
        case .didBecomeActiveComingBack:
            subject.state.comingBackFromBackground = true
            await subject.didBecomeActive()
        }
        #expect(!persistence.loadKeys.contains(.size)) // on iPhone we don't ask persistence for size
        #expect(coordinator.methodsCalled == ["makeBoardProcessor(gridSize:)"])
        let gridSize = try #require(coordinator.gridSize)
        #expect(gridSize == (10, 6)) // on iPhone, persistence size is ignored, we only do Easy
    }

    @Test("awakening with no saved data, gets board size from persistence, or Easy on phone (3x); asks coordinator to make board processor",
          arguments: [AwakeningType.didInitialLayout, .didBecomeActiveGameOver, .didBecomeActiveComingBack]
    )
    func awakenNoSavedData3x(awakeningType: AwakeningType) async throws {
        screen.traitCollection = UITraitCollection { traits in
            traits.userInterfaceIdiom = .phone
            traits.displayScale = 3
        }
        switch awakeningType {
        case .didInitialLayout:
            await subject.receive(.didInitialLayout)
        case .didBecomeActiveGameOver:
            persistence.bool = true
            await subject.didBecomeActive()
        case .didBecomeActiveComingBack:
            subject.state.comingBackFromBackground = true
            await subject.didBecomeActive()
        }
        #expect(!persistence.loadKeys.contains(.size)) // on iPhone we don't ask persistence for size
        #expect(coordinator.methodsCalled == ["makeBoardProcessor(gridSize:)"])
        let gridSize = try #require(coordinator.gridSize)
        #expect(gridSize == (12, 7)) // on iPhone, persistence size is ignored, we only do Easy
    }

    @Test("awakening with no saved data, gets board size from persistence on iPad; asks coordinator to make board processor",
          arguments: [AwakeningType.didInitialLayout, .didBecomeActiveGameOver, .didBecomeActiveComingBack]
    )
    func awakenNoSavedDataPad(awakeningType: AwakeningType) async throws {
        persistence.string = ["Hard"]
        screen.traitCollection = UITraitCollection { traits in
            traits.userInterfaceIdiom = .pad
            traits.displayScale = 2
        }
        switch awakeningType {
        case .didInitialLayout:
            await subject.receive(.didInitialLayout)
        case .didBecomeActiveGameOver:
            persistence.bool = true
            await subject.didBecomeActive()
        case .didBecomeActiveComingBack:
            subject.state.comingBackFromBackground = true
            await subject.didBecomeActive()
        }
        #expect(persistence.methodsCalled.contains("loadString(forKey:)"))
        #expect(persistence.loadKeys.contains(.size))
        #expect(coordinator.methodsCalled == ["makeBoardProcessor(gridSize:)"])
        let gridSize = try #require(coordinator.gridSize)
        #expect(gridSize == (16, 9)) // hard size
    }

    @Test("awakening with saved data, gets board size from saved data, asks coordinator to make board processor",
          arguments: [AwakeningType.didInitialLayout, .didBecomeActiveGameOver, .didBecomeActiveComingBack]
    )
    func awakenSavedData(awakeningType: AwakeningType) async throws {
        let boardSaveableData = BoardSaveableData(stageNumber: 5, grid: Grid(columns: 3, rows: 2), deckAtStartOfStage: [.init(picName: "hello")])
        let persistentState = PersistentState(board: boardSaveableData, score: 42, timed: false)
        let data = try PropertyListEncoder().encode(persistentState)
        persistence.data = data
        switch awakeningType {
        case .didInitialLayout:
            await subject.receive(.didInitialLayout)
        case .didBecomeActiveGameOver:
            return () // this test is not applicable
        case .didBecomeActiveComingBack:
            subject.state.comingBackFromBackground = true
            await subject.didBecomeActive()
        }
        print(persistence.methodsCalled)
        #expect(persistence.methodsCalled.contains("loadData(forKey:)"))
        #expect(persistence.loadKeys.contains(.boardData))
        #expect(coordinator.methodsCalled == ["makeBoardProcessor(gridSize:)"])
        let gridSize = try #require(coordinator.gridSize)
        #expect(gridSize == (3, 2))
    }

    @Test("awakening with no saved data configures state interface mode and stage label text",
          arguments: [AwakeningType.didInitialLayout, .didBecomeActiveGameOver, .didBecomeActiveComingBack]
    )
    func awakenStateNoSavedData(awakeningType: AwakeningType) async throws {
        persistence.int = 4
        switch awakeningType {
        case .didInitialLayout:
            await subject.receive(.didInitialLayout)
        case .didBecomeActiveGameOver:
            persistence.bool = true
            await subject.didBecomeActive()
        case .didBecomeActiveComingBack:
            subject.state.comingBackFromBackground = true
            await subject.didBecomeActive()
        }
        let state = try #require(presenter.statePresented)
        #expect(state.interfaceMode == .timed)
        #expect(state.stageLabelText == "Stage 1 of 5")
    }

    @Test("receive didInitialLayout with saved data configures state interface mode and stage label text",
          arguments: [AwakeningType.didInitialLayout, .didBecomeActiveGameOver, .didBecomeActiveComingBack]
    )
    func awakenStateSavedData(awakeningType: AwakeningType) async throws {
        let boardSaveableData = BoardSaveableData(stageNumber: 5, grid: Grid(columns: 3, rows: 2), deckAtStartOfStage: [.init(picName: "hello")])
        let persistentState = PersistentState(board: boardSaveableData, score: 42, timed: false)
        let data = try PropertyListEncoder().encode(persistentState)
        persistence.data = data
        persistence.int = 4
        switch awakeningType {
        case .didInitialLayout:
            await subject.receive(.didInitialLayout)
        case .didBecomeActiveGameOver:
            return () // this test is not applicable
        case .didBecomeActiveComingBack:
            subject.state.comingBackFromBackground = true
            await subject.didBecomeActive()
        }
        let state = try #require(presenter.statePresented)
        #expect(state.interfaceMode == .practice)
        #expect(state.stageLabelText == "Stage 6 of 5")
        #expect(state.boardViewHidden == false)
    }

    @Test("awakening with no saved data sends .userInteraction, .putBoard, .animatedBoardTransition, sets stageNumber, makes stage, tells board create deck",
          arguments: [AwakeningType.didInitialLayout, .didBecomeActiveGameOver, .didBecomeActiveComingBack]
    )
    func awakenThenWhatNoSavedData(awakeningType: AwakeningType) async throws {
        persistence.string = ["Hard"]
        screen.traitCollection = UITraitCollection { traits in
            traits.userInterfaceIdiom = .pad
            traits.displayScale = 2
        }
        switch awakeningType {
        case .didInitialLayout:
            await subject.receive(.didInitialLayout)
        case .didBecomeActiveGameOver:
            persistence.bool = true
            await subject.didBecomeActive()
        case .didBecomeActiveComingBack:
            subject.state.comingBackFromBackground = true
            await subject.didBecomeActive()
        }
        #expect(coordinator.methodsCalled == ["makeBoardProcessor(gridSize:)"])
        #expect(presenter.thingsReceived.count == 4)
        #expect(presenter.thingsReceived[0] == .userInteraction(false))
        #expect(presenter.thingsReceived[1] == .animateBoardTransition(.fade))
        #expect(presenter.thingsReceived[2] == .animateStageLabel)
        #expect(presenter.thingsReceived[3] == .userInteraction(true))
        #expect(board.stageNumber == 0)
        #expect(board.methodsCalled.first == "createAndDealDeck()")
        let stage = try #require(subject.stage)
        #expect(stage.score == 0)
        // and we save board state
        #expect(persistence.methodsCalled.last == "save(_:forKey:)")
        #expect(persistence.saveKeys.last == .boardData)
        let value = try #require(persistence.values.last as? Data)
        let _ = try PropertyListDecoder().decode(PersistentState.self, from: value)
    }

    @Test("awakening with saved data sends .userInteraction, .putBoard, .animatedBoardTransition, sets stageNumber, makes stage, tells board create deck",
          arguments: [AwakeningType.didInitialLayout, .didBecomeActiveGameOver, .didBecomeActiveComingBack]
    )
    func awakenThenWhatSavedData(awakeningType: AwakeningType) async throws {
        let boardSaveableData = BoardSaveableData(stageNumber: 5, grid: Grid(columns: 3, rows: 2), deckAtStartOfStage: [.init(picName: "hello")])
        let persistentState = PersistentState(board: boardSaveableData, score: 42, timed: false)
        let data = try PropertyListEncoder().encode(persistentState)
        persistence.data = data
        switch awakeningType {
        case .didInitialLayout:
            await subject.receive(.didInitialLayout)
        case .didBecomeActiveGameOver:
            return () // this test is not applicable
        case .didBecomeActiveComingBack:
            subject.state.comingBackFromBackground = true
            await subject.didBecomeActive()
        }
        #expect(coordinator.methodsCalled == ["makeBoardProcessor(gridSize:)"])
        #expect(presenter.thingsReceived.count == 4)
        #expect(presenter.thingsReceived[0] == .userInteraction(false))
        #expect(presenter.thingsReceived[1] == .animateBoardTransition(.fade))
        #expect(presenter.thingsReceived[2] == .animateStageLabel)
        #expect(presenter.thingsReceived[3] == .userInteraction(true))
        #expect(board.stageNumber == 5)
        #expect(board.methodsCalled.first == "populateFrom(oldGrid:deckAtStartOfStage:)")
        #expect(board.grid == Grid(columns: 3, rows: 2))
        #expect(board.deckAtStartOfStage == [.init(picName: "hello")])
        let stage = try #require(subject.stage)
        #expect(stage.score == 42)
    }

    @Test("receive saveBoardState: saves the board state to persistence")
    func saveBoardState() async throws {
        board.grid = Grid(columns: 1, rows: 1)
        subject.stage = MockStage()
        subject.stage?.score = 1
        await subject.receive(.saveBoardState)
        await #while(persistence.methodsCalled.isEmpty)
        #expect(persistence.methodsCalled == ["save(_:forKey:)"])
        #expect(persistence.saveKeys == [.boardData])
        let value = try #require(persistence.values.last as? Data)
        let _ = try PropertyListDecoder().decode(PersistentState.self, from: value)
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
        #expect(defs == PopoverDefaults(lastStage: 7, size: "Hard", style: "Animals"))
    }

    @Test("receive shuffle: call board processor shuffle")
    func shuffle() async {
        await subject.receive(.shuffle)
        #expect(board.methodsCalled == ["shuffle()"])
    }

    @Test("receive startNewGame: calls coordinator dismiss, nilifies copy of defaults, sets and presents state interface mode")
    func startNewGame() async {
        subject.state.defaultsBeforeShowingNewGamePopover = .init(lastStage: 7, size: "Size", style: "Style")
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

    @Test("after .viewDidLoad, lifetime didEnterBackground if state interface mode is .practice saves the board state to persistence")
    func didEnterBackgroundPractice() async throws {
        subject.state.interfaceMode = .practice
        board.grid = Grid(columns: 1, rows: 1)
        subject.stage = MockStage()
        subject.stage?.score = 1
        await subject.receive(.viewDidLoad)
        try? await Task.sleep(for: .seconds(0.1))
        services.lifetime.didEnterBackgroundPublisher.send()
        await #while(persistence.methodsCalled.isEmpty)
        #expect(persistence.methodsCalled == ["save(_:forKey:)"])
        #expect(persistence.saveKeys == [.boardData])
        let value = try #require(persistence.values.last as? Data)
        let _ = try PropertyListDecoder().decode(PersistentState.self, from: value)
    }

    @Test("after .viewDidLoad, lifetime didBecomeActive sets state `comingBackFromBackground` to false")
    func didBecomeActiveState() async throws {
        subject.state.comingBackFromBackground = true
        await subject.receive(.viewDidLoad)
        try? await Task.sleep(for: .seconds(0.1))
        services.lifetime.didBecomeActivePublisher.send()
        await #while(subject.state.comingBackFromBackground == true)
        #expect(subject.state.comingBackFromBackground == false)
        #expect(!persistence.saveKeys.contains(.gameEnded))
    }

    @Test("after .viewDidLoad, lifetime didBecomeActive does nothing if application is inactive")
    func didBecomeActiveInactive() async throws {
        subject.state.comingBackFromBackground = true
        application.applicationState = .inactive
        await subject.receive(.viewDidLoad)
        try? await Task.sleep(for: .seconds(0.1))
        services.lifetime.didBecomeActivePublisher.send()
        try? await Task.sleep(for: .seconds(0.1))
        #expect(subject.state.comingBackFromBackground == true)
        #expect(!persistence.saveKeys.contains(.gameEnded))
    }

    @Test("after .viewDidLoad, lifetime didBecomeActive checks persistence gameEnded, and if so, sets it to false")
    func didBecomeActiveGameEnded() async throws {
        persistence.bool = true
        await subject.receive(.viewDidLoad)
        try? await Task.sleep(for: .seconds(0.1))
        services.lifetime.didBecomeActivePublisher.send()
        await #while(!persistence.methodsCalled.contains("loadBool(forKey:)"))
        #expect(persistence.methodsCalled.contains("loadBool(forKey:)"))
        #expect(persistence.loadKeys.contains(.gameEnded))
        #expect(persistence.saveKeys.contains(.gameEnded))
        #expect(persistence.values.first as? Bool == false)
    }

    @Test("after .viewDidLoad, lifetime didBecomeActive, if not coming back from background, calls stage didBecomeActive")
    func didBecomeActiveNotComingBack() async throws {
        subject.stage = stage
        subject.state.comingBackFromBackground = false
        await subject.receive(.viewDidLoad)
        try? await Task.sleep(for: .seconds(0.1))
        services.lifetime.didBecomeActivePublisher.send()
        await #while(stage.methodsCalled.isEmpty)
        #expect(stage.methodsCalled == ["didBecomeActive()"])
    }

    @Test("after .viewDidLoad, lifetime willEnterForeground sets state comingBack to true")
    func willEnterForeground() async throws {
        subject.state.comingBackFromBackground = false
        await subject.receive(.viewDidLoad)
        try? await Task.sleep(for: .seconds(0.1))
        services.lifetime.willEnterForegroundPublisher.send()
        await #while(subject.state.comingBackFromBackground == false)
        #expect(subject.state.comingBackFromBackground == true)
    }
}

/// We need this so that the processor sees its presenter as a dismissal delegate;
/// but I expect all this to change when I move the delegate to the subject itself!
extension MockReceiverPresenter: NewGamePopoverDismissalButtonDelegate {
    func cancelNewGame() {}
    
    func startNewGame() {}
}
