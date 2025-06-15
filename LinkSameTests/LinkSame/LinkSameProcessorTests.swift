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

    @Test("stageLabelText: returns expected value")
    func stageLabelText() {
        let boardProcessor = MockBoardProcessor()
        subject.boardProcessor = boardProcessor
        boardProcessor.stageNumber = 7
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

    @Test("receive didInitialLayout: with no saved data, gets board size from persistence, or Easy on phone; asks coordinator to make board processor")
    func didInitialLayoutNoSavedData() async throws {
        screen.traitCollection = UITraitCollection { traits in // how to say, nowadays
            traits.userInterfaceIdiom = .phone
            traits.displayScale = 2
        }
        await subject.receive(.didInitialLayout)
        #expect(!persistence.keys.contains(.size)) // on iPhone we don't ask persistence for size
        #expect(coordinator.methodsCalled == ["makeBoardProcessor(gridSize:)"])
        let gridSize = try #require(coordinator.gridSize)
        #expect(gridSize == (10, 6)) // on iPhone, persistence size is ignored, we only do Easy
        #expect(subject.boardProcessor != nil)
    }

    @Test("receive didInitialLayout: with no saved data, gets board size from persistence, or Easy on phone (3x); asks coordinator to make board processor")
    func didInitialLayoutNoSavedData3x() async throws {
        screen.traitCollection = UITraitCollection { traits in
            traits.userInterfaceIdiom = .phone
            traits.displayScale = 3
        }
        await subject.receive(.didInitialLayout)
        #expect(!persistence.keys.contains(.size)) // on iPhone we don't ask persistence for size
        #expect(coordinator.methodsCalled == ["makeBoardProcessor(gridSize:)"])
        let gridSize = try #require(coordinator.gridSize)
        #expect(gridSize == (12, 7)) // on iPhone, persistence size is ignored, we only do Easy
        #expect(subject.boardProcessor != nil)
    }

    @Test("receive didInitialLayout: with no saved data, gets board size from persistence on iPad; asks coordinator to make board processor")
    func didInitialLayoutNoSavedDataPad() async throws {
        persistence.string = ["Hard"]
        screen.traitCollection = UITraitCollection { traits in
            traits.userInterfaceIdiom = .pad
            traits.displayScale = 2
        }
        await subject.receive(.didInitialLayout)
        #expect(persistence.methodsCalled.contains("loadString(forKey:)"))
        #expect(persistence.keys.contains(.size))
        #expect(coordinator.methodsCalled == ["makeBoardProcessor(gridSize:)"])
        let gridSize = try #require(coordinator.gridSize)
        #expect(gridSize == (16, 9)) // hard size
        #expect(subject.boardProcessor != nil)
    }

    @Test("receive didInitialLayout: with saved data, gets board size from saved data, asks coordinator to make board processor")
    func didInitialLayoutSavedData() async throws {
        let boardSaveableData = BoardSaveableData(stage: 5, frame: .zero, grid: Grid(columns: 3, rows: 2), deckAtStartOfStage: ["howdy"])
        let persistentState = PersistentState(board: boardSaveableData, score: 42, timed: false)
        let data = try PropertyListEncoder().encode(persistentState)
        persistence.data = data
        await subject.receive(.didInitialLayout)
        #expect(persistence.methodsCalled.first == "loadData(forKey:)")
        #expect(persistence.keys.first == .boardData)
        #expect(coordinator.methodsCalled == ["makeBoardProcessor(gridSize:)"])
        let gridSize = try #require(coordinator.gridSize)
        #expect(gridSize == (3, 2))
        #expect(subject.boardProcessor != nil)
    }

    @Test("receive didInitialLayout: with no saved data configures state interface mode and stage label text")
    func didInitialLayoutStateNoSavedData() async throws {
        persistence.int = 4
        await subject.receive(.didInitialLayout)
        let state = try #require(presenter.statePresented)
        #expect(state.interfaceMode == .timed)
        #expect(state.stageLabelText == "Stage 1 of 5")
    }

    @Test("receive didInitialLyout with saved data configures state interface mode and stage label text")
    func didInitialLayoutStateSavedData() async throws {
        let boardSaveableData = BoardSaveableData(stage: 5, frame: .zero, grid: Grid(columns: 3, rows: 2), deckAtStartOfStage: ["howdy"])
        let persistentState = PersistentState(board: boardSaveableData, score: 42, timed: false)
        let data = try PropertyListEncoder().encode(persistentState)
        persistence.data = data
        persistence.int = 4
        await subject.receive(.didInitialLayout)
        let state = try #require(presenter.statePresented)
        #expect(state.interfaceMode == .practice)
        #expect(state.stageLabelText == "Stage 6 of 5")
    }

    @Test("receive didInitialLayout: with no saved data sends .userInteraction, .putBoard, .animatedBoardTransition, sets stageNumber, makes stage, tells board create deck")
    func didInitialLayoutThenWhatNoSavedData() async throws {
        persistence.string = ["Hard"]
        screen.traitCollection = UITraitCollection { traits in
            traits.userInterfaceIdiom = .pad
            traits.displayScale = 2
        }
        await subject.receive(.didInitialLayout)
        let board = try #require(subject.boardProcessor as? MockBoardProcessor)
        #expect(presenter.thingsReceived.count == 5)
        #expect(presenter.thingsReceived[0] == .userInteraction(false))
        #expect(presenter.thingsReceived[1] == .putBoardViewIntoInterface(board.view))
        #expect(presenter.thingsReceived[2] == .animateBoardTransition(.fade))
        #expect(presenter.thingsReceived[3] == .animateStageLabel)
        #expect(presenter.thingsReceived[4] == .userInteraction(true))
        #expect(board.stageNumber == 0)
        #expect(board.methodsCalled.first == "createAndDealDeck()")
        let stage = try #require(subject.stage)
        #expect(stage.score == 0)
        // and we save board state
        #expect(persistence.methodsCalled.last == "save(_:forKey:)")
        #expect(persistence.keys.last == .boardData)
        let value = try #require(persistence.value as? Data)
        let _ = try PropertyListDecoder().decode(PersistentState.self, from: value)
    }

    @Test("receive didInitialLayout: with saved data sends .userInteraction, .putBoard, .animatedBoardTransition, sets stageNumber, makes stage, tells board create deck")
    func didInitialLayoutThenWhatSavedData() async throws {
        let boardSaveableData = BoardSaveableData(stage: 5, frame: .zero, grid: Grid(columns: 3, rows: 2), deckAtStartOfStage: ["howdy"])
        let persistentState = PersistentState(board: boardSaveableData, score: 42, timed: false)
        let data = try PropertyListEncoder().encode(persistentState)
        persistence.data = data
        await subject.receive(.didInitialLayout)
        let board = try #require(subject.boardProcessor as? MockBoardProcessor)
        #expect(presenter.thingsReceived.count == 5)
        #expect(presenter.thingsReceived[0] == .userInteraction(false))
        #expect(presenter.thingsReceived[1] == .putBoardViewIntoInterface(board.view))
        #expect(presenter.thingsReceived[2] == .animateBoardTransition(.fade))
        #expect(presenter.thingsReceived[3] == .animateStageLabel)
        #expect(presenter.thingsReceived[4] == .userInteraction(true))
        #expect(board.stageNumber == 5)
        #expect(board.methodsCalled.first == "populateFrom(oldGrid:deckAtStartOfStage:)")
        #expect(board.grid == Grid(columns: 3, rows: 2))
        #expect(board.deckAtStartOfStage == ["howdy"])
        let stage = try #require(subject.stage)
        #expect(stage.score == 42)
    }

    @Test("receive saveBoardState: saves the board state to persistence")
    func saveBoardState() async throws {
        let boardProcessor = MockBoardProcessor()
        subject.boardProcessor = boardProcessor
        boardProcessor.grid = Grid(columns: 1, rows: 1)
        subject.stage = Stage(score: 1)
        await subject.receive(.saveBoardState)
        await #while(persistence.methodsCalled.isEmpty)
        #expect(persistence.methodsCalled == ["save(_:forKey:)"])
        #expect(persistence.keys == [.boardData])
        let value = try #require(persistence.value as? Data)
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
        let boardProcessor = MockBoardProcessor()
        subject.boardProcessor = boardProcessor
        boardProcessor.grid = Grid(columns: 1, rows: 1)
        subject.stage = Stage(score: 1)
        await subject.receive(.viewDidLoad)
        try? await Task.sleep(for: .seconds(0.1))
        services.lifetime.didEnterBackgroundPublisher.send()
        await #while(persistence.methodsCalled.isEmpty)
        #expect(persistence.methodsCalled == ["save(_:forKey:)"])
        #expect(persistence.keys == [.boardData])
        let value = try #require(persistence.value as? Data)
        let _ = try PropertyListDecoder().decode(PersistentState.self, from: value)
    }
}

/// We need this so that the processor sees its presenter as a dismissal delegate;
/// but I expect all this to change when I move the delegate to the subject itself!
extension MockReceiverPresenter: NewGamePopoverDismissalButtonDelegate {
    func cancelNewGame() {}
    
    func startNewGame() {}
}
