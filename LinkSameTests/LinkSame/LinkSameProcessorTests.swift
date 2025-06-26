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
    let application = MockApplication()
    let board = MockBoardProcessor()
    let router = MockHamburgerRouter()

    init() {
        subject.presenter = presenter
        subject.coordinator = coordinator
        subject.boardProcessor = board
        subject.hamburgerRouter = router
        services.persistence = persistence
        services.screen = screen
        services.application = application
    }

    @Test("stageLabelText: returns expected value")
    func stageLabelText() {
        board._stageNumber = 7
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
    enum AwakeningType: CaseIterable {
        case didInitialLayout // receive .didInitialLayout, i.e. launching cold
        case startNewGame // receive .startNewGame, i.e. user tapped Done in New Game popover
        case didBecomeActiveGameOver // didBecomeActive is called, and there is a .gameOver true default
        case didBecomeActiveComingBack // didBecomeActive is called, and state comingBack is true (i.e. we were backgrounded)
    }

    @Test("awakening with no saved data, gets board size from persistence, or Easy on phone; asks coordinator to make board processor",
          arguments: AwakeningType.allCases
    )
    func awakenNoSavedData(awakeningType: AwakeningType) async throws {
        screen.traitCollection = UITraitCollection { traits in // how to say, nowadays
            traits.userInterfaceIdiom = .phone
            traits.displayScale = 2
        }
        switch awakeningType {
        case .didInitialLayout:
            await subject.receive(.didInitialLayout)
        case .startNewGame:
            await subject.receive(.startNewGame)
        case .didBecomeActiveGameOver:
            persistence.bool = true
            await subject.didBecomeActive()
        case .didBecomeActiveComingBack:
            subject.state.comingBackFromBackground = true
            await subject.didBecomeActive()
        }
        #expect(!persistence.loadKeys.contains(.size)) // on iPhone we don't ask persistence for size
        #expect(coordinator.methodsCalled.last == "makeBoardProcessor(gridSize:)")
        let gridSize = try #require(coordinator.gridSize)
        #expect(gridSize == (10, 6)) // on iPhone, persistence size is ignored, we only do Easy
    }

    @Test("awakening with no saved data, gets board size from persistence, or Easy on phone (3x); asks coordinator to make board processor",
          arguments: AwakeningType.allCases
    )
    func awakenNoSavedData3x(awakeningType: AwakeningType) async throws {
        screen.traitCollection = UITraitCollection { traits in
            traits.userInterfaceIdiom = .phone
            traits.displayScale = 3
        }
        switch awakeningType {
        case .didInitialLayout:
            await subject.receive(.didInitialLayout)
        case .startNewGame:
            await subject.receive(.startNewGame)
        case .didBecomeActiveGameOver:
            persistence.bool = true
            await subject.didBecomeActive()
        case .didBecomeActiveComingBack:
            subject.state.comingBackFromBackground = true
            await subject.didBecomeActive()
        }
        #expect(!persistence.loadKeys.contains(.size)) // on iPhone we don't ask persistence for size
        #expect(coordinator.methodsCalled.last == "makeBoardProcessor(gridSize:)")
        let gridSize = try #require(coordinator.gridSize)
        #expect(gridSize == (12, 7)) // on iPhone, persistence size is ignored, we only do Easy
    }

    @Test("awakening with no saved data, gets board size from persistence on iPad; asks coordinator to make board processor",
          arguments: AwakeningType.allCases
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
        case .startNewGame:
            await subject.receive(.startNewGame)
        case .didBecomeActiveGameOver:
            persistence.bool = true
            await subject.didBecomeActive()
        case .didBecomeActiveComingBack:
            subject.state.comingBackFromBackground = true
            await subject.didBecomeActive()
        }
        #expect(persistence.methodsCalled.contains("loadString(forKey:)"))
        #expect(persistence.loadKeys.contains(.size))
        #expect(coordinator.methodsCalled.last == "makeBoardProcessor(gridSize:)")
        let gridSize = try #require(coordinator.gridSize)
        #expect(gridSize == (16, 9)) // hard size
    }

    @Test("awakening with saved data, gets board size from saved data, asks coordinator to make board processor",
          arguments: AwakeningType.allCases
    )
    func awakenSavedData(awakeningType: AwakeningType) async throws {
        let boardSaveableData = BoardSaveableData(stageNumber: 5, grid: Grid(columns: 3, rows: 2), deckAtStartOfStage: ["hello"])
        let persistentState = PersistentState(board: boardSaveableData, score: 42, timed: false)
        let data = try PropertyListEncoder().encode(persistentState)
        persistence.data = data
        switch awakeningType {
        case .didInitialLayout:
            await subject.receive(.didInitialLayout)
        case .startNewGame:
            return () // this test is not applicable
        case .didBecomeActiveGameOver:
            return () // this test is not applicable
        case .didBecomeActiveComingBack:
            subject.state.comingBackFromBackground = true
            await subject.didBecomeActive()
        }
        print(persistence.methodsCalled)
        #expect(persistence.methodsCalled.contains("loadData(forKey:)"))
        #expect(persistence.loadKeys.contains(.boardData))
        #expect(coordinator.methodsCalled.last == "makeBoardProcessor(gridSize:)")
        let gridSize = try #require(coordinator.gridSize)
        #expect(gridSize == (3, 2))
    }

    @Test("awakening with no saved data configures state interface mode and stage label text",
          arguments: AwakeningType.allCases
    )
    func awakenStateNoSavedData(awakeningType: AwakeningType) async throws {
        persistence.int = 4
        switch awakeningType {
        case .didInitialLayout:
            await subject.receive(.didInitialLayout)
        case .startNewGame:
            await subject.receive(.startNewGame)
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
          arguments: AwakeningType.allCases
    )
    func awakenStateSavedData(awakeningType: AwakeningType) async throws {
        let boardSaveableData = BoardSaveableData(stageNumber: 5, grid: Grid(columns: 3, rows: 2), deckAtStartOfStage: ["hello"])
        let persistentState = PersistentState(board: boardSaveableData, score: 42, timed: false)
        let data = try PropertyListEncoder().encode(persistentState)
        persistence.data = data
        persistence.int = 4
        switch awakeningType {
        case .didInitialLayout:
            await subject.receive(.didInitialLayout)
        case .startNewGame:
            return () // this test is not applicable
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

    @Test("awakening with no saved data sends .userInteraction, .putBoard, .animatedBoardTransition, sets stageNumber, makes scoreKeeper, tells board create deck",
          arguments: AwakeningType.allCases
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
        case .startNewGame:
            await subject.receive(.startNewGame)
        case .didBecomeActiveGameOver:
            persistence.bool = true
            await subject.didBecomeActive()
        case .didBecomeActiveComingBack:
            subject.state.comingBackFromBackground = true
            await subject.didBecomeActive()
        }
        #expect(coordinator.methodsCalled.last == "makeBoardProcessor(gridSize:)")
        #expect(presenter.thingsReceived.count == 4)
        #expect(presenter.thingsReceived[0] == .userInteraction(false))
        #expect(presenter.thingsReceived[1] == .animateBoardTransition(.fade))
        #expect(presenter.thingsReceived[2] == .animateStageLabel)
        #expect(presenter.thingsReceived[3] == .userInteraction(true))
        #expect(board._stageNumber == 0)
        #expect(board.methodsCalled == ["setStageNumber(_:)", "setScoreKeeper(score:)", "createAndDealDeck()", "stageNumber()", "stageNumber()", "deckAtStartOfStage"])
        let scoreKeeper = try #require(board.scoreKeeper)
        #expect(scoreKeeper.score == 0)
        // and we save board state
        #expect(persistence.methodsCalled.last == "save(_:forKey:)")
        #expect(persistence.saveKeys.last == .boardData)
        let value = try #require(persistence.values.last as? Data)
        let persistentState = try PropertyListDecoder().decode(PersistentState.self, from: value)
        #expect(persistentState == .init(
            board: .init(stageNumber: 0, grid: Grid(columns: 1, rows: 1), deckAtStartOfStage: []),
            score: 0,
            timed: true
        ))
    }

    @Test("awakening with saved data sends .userInteraction, .putBoard, .animatedBoardTransition, sets stageNumber, makes scoreKeeper, tells board create deck",
          arguments: AwakeningType.allCases
    )
    func awakenThenWhatSavedData(awakeningType: AwakeningType) async throws {
        let boardSaveableData = BoardSaveableData(stageNumber: 5, grid: Grid(columns: 3, rows: 2), deckAtStartOfStage: ["hello"])
        let persistentState = PersistentState(board: boardSaveableData, score: 42, timed: false)
        let data = try PropertyListEncoder().encode(persistentState)
        persistence.data = data
        switch awakeningType {
        case .didInitialLayout:
            await subject.receive(.didInitialLayout)
        case .startNewGame:
            return () // this test is not applicable
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
        #expect(board._stageNumber == 5)
        #expect(board.methodsCalled == ["setStageNumber(_:)", "populateFrom(oldGrid:deckAtStartOfStage:)", "setScoreKeeper(score:)", "stageNumber()"])
        #expect(board.grid == Grid(columns: 3, rows: 2))
        #expect(board._deckAtStartOfStage == ["hello"])
        let scoreKeeper = try #require(board.scoreKeeper)
        #expect(scoreKeeper.score == 42)
    }

    @Test("receive hamburger: hides hint, calls coordinator showActionSheet")
    func hamburger() async {
        subject.state.hintShowing = true
        subject.state.hintButtonTitle = .hide
        router.options = ["Heyho"]
        await subject.receive(.hamburger)
        #expect(subject.state.hintShowing == false)
        #expect(subject.state.hintButtonTitle == .show)
        #expect(presenter.statesPresented.last?.hintShowing == false)
        #expect(presenter.statesPresented.last?.hintButtonTitle == .show)
        #expect(board.methodsCalled == ["unhilite()", "showHint(_:)"])
        #expect(board.show == false)
        #expect(coordinator.methodsCalled == ["showActionSheet(title:options:)"])
        #expect(coordinator.options == ["Heyho"])
        #expect(router.methodsCalled == ["doChoice(_:processor:)"])
        #expect(router.choice == "Heyho")
    }

    @Test("receive hint: if no hint is showing, configures and presents state, tells board processor to show hint")
    func hintYes() async {
        subject.state.hintShowing = false
        #expect(subject.state.hintButtonTitle == .show)
        await subject.receive(.hint)
        #expect(subject.state.hintShowing == true)
        #expect(subject.state.hintButtonTitle == .hide)
        #expect(presenter.statesPresented.last?.hintShowing == true)
        #expect(presenter.statesPresented.last?.hintButtonTitle == .hide)
        #expect(board.methodsCalled == ["unhilite()", "showHint(_:)"])
        #expect(board.show == true)
    }

    @Test("receive hint: if hint is showing, configures and presents state, tells board processor to show hint")
    func hintNo() async {
        subject.state.hintShowing = true
        subject.state.hintButtonTitle = .hide
        await subject.receive(.hint)
        #expect(subject.state.hintShowing == false)
        #expect(subject.state.hintButtonTitle == .show)
        #expect(presenter.statesPresented.last?.hintShowing == false)
        #expect(presenter.statesPresented.last?.hintButtonTitle == .show)
        #expect(board.methodsCalled == ["unhilite()", "showHint(_:)"])
        #expect(board.show == false)
    }

    @Test("receive restartStage: hides hint and unhilites, calls board restartStage, sends effects to presenter")
    func restartStage() async {
        subject.state.hintShowing = true
        subject.state.hintButtonTitle = .hide
        await subject.receive(.restartStage)
        #expect(subject.state.hintShowing == false)
        #expect(subject.state.hintButtonTitle == .show)
        #expect(presenter.statesPresented.last?.hintShowing == false)
        #expect(presenter.statesPresented.last?.hintButtonTitle == .show)
        #expect(board.methodsCalled.prefix(3) == ["unhilite()", "showHint(_:)", "restartStage()"])
        #expect(board.show == false)
        #expect(presenter.thingsReceived == [.userInteraction(false), .animateBoardTransition(.fade), .animateStageLabel, .userInteraction(true)])
    }

    @Test("receive restartStage: saves the board state to persistence")
    func restartStageSaves() async throws {
        board.scoreKeeper?.score = 1
        board._stageNumber = 2
        board._deckAtStartOfStage = ["howdy"]
        board.grid = Grid(columns: 3, rows: 2)
        await subject.receive(.restartStage)
        await #while(persistence.methodsCalled.isEmpty)
        #expect(persistence.methodsCalled == ["save(_:forKey:)"])
        #expect(persistence.saveKeys == [.boardData])
        let value = try #require(persistence.values.last as? Data)
        let persistentState = try PropertyListDecoder().decode(PersistentState.self, from: value)
        #expect(persistentState == .init(
            board: .init(stageNumber: 2, grid: Grid(columns: 3, rows: 2), deckAtStartOfStage: ["howdy"]),
            score: 1,
            timed: true
        ))
    }

    @Test("receive saveBoardState: saves the board state to persistence")
    func saveBoardState() async throws {
        board.scoreKeeper?.score = 1
        board._stageNumber = 2
        board._deckAtStartOfStage = ["howdy"]
        board.grid = Grid(columns: 3, rows: 2)
        await subject.receive(.saveBoardState)
        await #while(persistence.methodsCalled.isEmpty)
        #expect(persistence.methodsCalled == ["save(_:forKey:)"])
        #expect(persistence.saveKeys == [.boardData])
        let value = try #require(persistence.values.last as? Data)
        let persistentState = try PropertyListDecoder().decode(PersistentState.self, from: value)
        #expect(persistentState == .init(
            board: .init(stageNumber: 2, grid: Grid(columns: 3, rows: 2), deckAtStartOfStage: ["howdy"]),
            score: 1,
            timed: true
        ))
    }

    @Test("receive showHelp: hides hilite and hint, tells the coordinator to showHelp")
    func showHelp() async {
        subject.state.hintShowing = true
        subject.state.hintButtonTitle = .hide
        let view = UIView()
        await subject.receive(.showHelp(sender: view))
        #expect(subject.state.hintShowing == false)
        #expect(subject.state.hintButtonTitle == .show)
        #expect(presenter.statesPresented.last?.hintShowing == false)
        #expect(presenter.statesPresented.last?.hintButtonTitle == .show)
        #expect(board.methodsCalled == ["unhilite()", "showHint(_:)"])
        #expect(board.show == false)
        #expect(coordinator.methodsCalled == ["showHelp(sourceItem:popoverPresentationDelegate:)"])
        #expect(coordinator.sourceItem === view)
        #expect(coordinator.popoverPresentationDelegate is HelpPopoverDelegate)
    }

    @Test("receive showNewGame: hides hilite and hint, tells the coordinator to showNewGame, saves a copy of defaults that the user might change")
    func showNewGame() async throws {
        subject.state.hintShowing = true
        subject.state.hintButtonTitle = .hide
        let view = UIView()
        persistence.dict = [.style: "Animals", .size: "Hard", .lastStage: 7]
        await subject.receive(.showNewGame(sender: view))
        #expect(subject.state.hintShowing == false)
        #expect(subject.state.hintButtonTitle == .show)
        #expect(presenter.statesPresented.last?.hintShowing == false)
        #expect(presenter.statesPresented.last?.hintButtonTitle == .show)
        #expect(board.methodsCalled == ["unhilite()", "showHint(_:)"])
        #expect(board.show == false)
        #expect(coordinator.methodsCalled == ["showNewGame(sourceItem:popoverPresentationDelegate:dismissalDelegate:)"])
        #expect(coordinator.sourceItem === view)
        #expect(coordinator.popoverPresentationDelegate is NewGamePopoverDelegate)
        #expect(coordinator.dismissalDelegate === subject)
        let defs = try #require(subject.state.defaultsBeforeShowingNewGamePopover)
        #expect(defs == PopoverDefaults(lastStage: 7, size: "Hard", style: "Animals"))
    }

    @Test("receive shuffle: hides hilite and hint, calls board processor shuffle")
    func shuffle() async {
        subject.state.hintShowing = true
        subject.state.hintButtonTitle = .hide
        await subject.receive(.shuffle)
        #expect(subject.state.hintShowing == false)
        #expect(subject.state.hintButtonTitle == .show)
        #expect(presenter.statesPresented.last?.hintShowing == false)
        #expect(presenter.statesPresented.last?.hintButtonTitle == .show)
        #expect(board.methodsCalled == ["unhilite()", "showHint(_:)", "shuffle()"])
        #expect(board.show == false)
    }

    @Test("receive startNewGame: calls coordinator dismiss, nilifies copy of defaults, sets and presents state interface mode")
    func startNewGame() async {
        subject.state.defaultsBeforeShowingNewGamePopover = .init(lastStage: 7, size: "Size", style: "Style")
        subject.state.interfaceMode = .practice
        await subject.receive(.startNewGame)
        #expect(coordinator.methodsCalled.first == "dismiss()")
        #expect(subject.state.defaultsBeforeShowingNewGamePopover == nil)
        #expect(presenter.statesPresented.last?.interfaceMode == .timed)
    }

    @Test("receive timedPractice: hides hilite and hint, presents state with corresponding interfaceMode")
    func timedPractice() async {
        subject.state.hintShowing = true
        subject.state.hintButtonTitle = .hide
        subject.state.interfaceMode = .practice
        await subject.receive(.timedPractice(0))
        #expect(subject.state.hintShowing == false)
        #expect(subject.state.hintButtonTitle == .show)
        #expect(presenter.statesPresented.last?.hintShowing == false)
        #expect(presenter.statesPresented.last?.hintButtonTitle == .show)
        #expect(board.methodsCalled == ["unhilite()", "showHint(_:)"])
        #expect(board.show == false)
        #expect(presenter.statesPresented.last?.interfaceMode == .timed)
        // --
        board.methodsCalled = []
        subject.state.hintShowing = true
        subject.state.hintButtonTitle = .hide
        subject.state.interfaceMode = .timed
        await subject.receive(.timedPractice(1))
        #expect(subject.state.hintShowing == false)
        #expect(subject.state.hintButtonTitle == .show)
        #expect(presenter.statesPresented.last?.hintShowing == false)
        #expect(presenter.statesPresented.last?.hintButtonTitle == .show)
        #expect(board.methodsCalled == ["unhilite()", "showHint(_:)"])
        #expect(board.show == false)
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
        board.scoreKeeper?.score = 1
        board._stageNumber = 2
        board._deckAtStartOfStage = ["howdy"]
        board.grid = Grid(columns: 3, rows: 2)
        await subject.receive(.viewDidLoad)
        try? await Task.sleep(for: .seconds(0.1))
        services.lifetime.didEnterBackgroundPublisher.send()
        await #while(persistence.methodsCalled.isEmpty)
        #expect(persistence.methodsCalled == ["save(_:forKey:)"])
        #expect(persistence.saveKeys == [.boardData])
        let value = try #require(persistence.values.last as? Data)
        let persistentState = try PropertyListDecoder().decode(PersistentState.self, from: value)
        #expect(persistentState == .init(
            board: .init(stageNumber: 2, grid: Grid(columns: 3, rows: 2), deckAtStartOfStage: ["howdy"]),
            score: 1,
            timed: false
        ))
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

    @Test("after .viewDidLoad, lifetime didBecomeActive, if not coming back from background, calls scoreKeeper didBecomeActive")
    func didBecomeActiveNotComingBack() async throws {
        subject.state.comingBackFromBackground = false
        await subject.receive(.viewDidLoad)
        try? await Task.sleep(for: .seconds(0.1))
        services.lifetime.didBecomeActivePublisher.send()
        let scoreKeeper = try #require(board.scoreKeeper as? MockScoreKeeper)
        await #while(scoreKeeper.methodsCalled.isEmpty)
        #expect(scoreKeeper.methodsCalled == ["didBecomeActive()"])
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

    @Test("stageEnded: checks persistence lastStage, if not greater than stageNumber, stops")
    func stageEndedStops() {
        board._stageNumber = 5
        persistence.int = 5
        subject.stageEnded()
        #expect(persistence.methodsCalled == ["loadInt(forKey:)"])
        #expect(persistence.loadKeys.first == .lastStage)
        #expect(coordinator.methodsCalled.isEmpty)
    }

    @Test("stageEnded: checks persistence lastState, if greater, continues, calls coordinator makeBoardProcessor")
    func stageEndedContinues() async throws {
        board._stageNumber = 5
        persistence.int = 6
        board.grid = Grid(columns: 3, rows: 4)
        board._deckAtStartOfStage = ["howdy"]
        let scoreKeeper = try #require(board.scoreKeeper as? MockScoreKeeper)
        scoreKeeper.score = 10
        subject.stageEnded()
        #expect(persistence.methodsCalled == ["loadInt(forKey:)"])
        #expect(persistence.loadKeys.first == .lastStage)
        #expect(coordinator.methodsCalled == ["makeBoardProcessor(gridSize:)"])
        #expect(coordinator.gridSize! == (3, 4))
        // and the rest is like "then what" when launching,
        // but board transition is slide and stage number is incremented
        await #while(presenter.thingsReceived.count < 4)
        #expect(presenter.thingsReceived.count == 4)
        #expect(presenter.thingsReceived[0] == .userInteraction(false))
        #expect(presenter.thingsReceived[1] == .animateBoardTransition(.slide)) // NB slide transition
        #expect(presenter.thingsReceived[2] == .animateStageLabel)
        #expect(presenter.thingsReceived[3] == .userInteraction(true))
        #expect(board._stageNumber == 6) // NB incrementing stage number
        #expect(board.methodsCalled ==  ["stageNumber()", "setStageNumber(_:)", "setScoreKeeper(score:)", "createAndDealDeck()", "stageNumber()", "stageNumber()", "deckAtStartOfStage"])
        #expect(scoreKeeper.score == 10)
        // and we save board state
        #expect(persistence.methodsCalled.last == "save(_:forKey:)")
        #expect(persistence.saveKeys.last == .boardData)
        let value = try #require(persistence.values.last as? Data)
        let persistentState = try PropertyListDecoder().decode(PersistentState.self, from: value)
        #expect(persistentState == .init(
            board: .init(stageNumber: 6, grid: Grid(columns: 3, rows: 4), deckAtStartOfStage: ["howdy"]),
            score: 0,
            timed: true
        ))
    }

    @Test("userTappedPathView: hides hilite and hint")
    func userTappedPathView() async {
        subject.state.hintShowing = true
        subject.state.hintButtonTitle = .hide
        subject.userTappedPathView()
        await #while(subject.state.hintShowing == true)
        #expect(subject.state.hintShowing == false)
        #expect(subject.state.hintButtonTitle == .show)
        #expect(presenter.statesPresented.last?.hintShowing == false)
        #expect(presenter.statesPresented.last?.hintButtonTitle == .show)
        #expect(board.methodsCalled == ["unhilite()", "showHint(_:)"])
        #expect(board.show == false)
    }
}

/// We need this so that the processor sees its presenter as a dismissal delegate;
/// but I expect all this to change when I move the delegate to the subject itself!
extension MockReceiverPresenter: NewGamePopoverDismissalButtonDelegate {
    func cancelNewGame() {}
    func startNewGame() {}
}
