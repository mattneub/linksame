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
        persistence.values = [.lastStage: 8]
        #expect(subject.stageLabelText == "Stage 8 of 9") // adds 1 to each of those values
        #expect(persistence.loads[0] == ("loadInt(forKey:)", .lastStage))
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
        persistence.values = [:] // no saved .size info on iPhone
        switch awakeningType {
        case .didInitialLayout:
            await subject.receive(.didInitialLayout)
        case .startNewGame:
            await subject.receive(.startNewGame)
        case .didBecomeActiveComingBack:
            subject.state.comingBackFromBackground = true
            await subject.didBecomeActive()
        }
        #expect(coordinator.methodsCalled.last == "makeBoardProcessor(gridSize:score:)")
        #expect(coordinator.gridSize == (10, 6)) // easy by default
        #expect(coordinator.score == 0)
    }

    @Test("awakening with no saved data, gets board size from persistence, or Easy on phone (3x); asks coordinator to make board processor",
          arguments: AwakeningType.allCases
    )
    func awakenNoSavedData3x(awakeningType: AwakeningType) async throws {
        screen.traitCollection = UITraitCollection { traits in
            traits.userInterfaceIdiom = .phone
            traits.displayScale = 3
        }
        persistence.values = [:] // no saved .size info on iPhone
        switch awakeningType {
        case .didInitialLayout:
            await subject.receive(.didInitialLayout)
        case .startNewGame:
            await subject.receive(.startNewGame)
        case .didBecomeActiveComingBack:
            subject.state.comingBackFromBackground = true
            await subject.didBecomeActive()
        }
        #expect(coordinator.methodsCalled.last == "makeBoardProcessor(gridSize:score:)")
        #expect(coordinator.gridSize == (12, 7)) // easy by default, but easy is bigger on 3x iPhone
        #expect(coordinator.score == 0)
    }

    @Test("awakening with no saved data, gets board size from persistence on iPad; asks coordinator to make board processor",
          arguments: AwakeningType.allCases
    )
    func awakenNoSavedDataPad(awakeningType: AwakeningType) async throws {
        screen.traitCollection = UITraitCollection { traits in
            traits.userInterfaceIdiom = .pad
            traits.displayScale = 2
        }
        persistence.values = [.size: "Hard"]
        switch awakeningType {
        case .didInitialLayout:
            await subject.receive(.didInitialLayout)
        case .startNewGame:
            await subject.receive(.startNewGame)
        case .didBecomeActiveComingBack:
            subject.state.comingBackFromBackground = true
            await subject.didBecomeActive()
        }
        #expect(coordinator.methodsCalled.last == "makeBoardProcessor(gridSize:score:)")
        #expect(coordinator.gridSize == (16, 9)) // hard size
        #expect(coordinator.score == 0)
    }

    @Test("awakening with saved data, gets board size from saved data, asks coordinator to make board processor",
          arguments: AwakeningType.allCases
    )
    func awakenSavedData(awakeningType: AwakeningType) async throws {
        let boardSaveableData = BoardSaveableData(stageNumber: 5, grid: Grid(columns: 3, rows: 2), deckAtStartOfStage: ["hello"])
        let persistentState = PersistentState(board: boardSaveableData, score: 42, timed: false)
        let data = try PropertyListEncoder().encode(persistentState)
        persistence.values = [.boardData: data]
        switch awakeningType {
        case .didInitialLayout:
            await subject.receive(.didInitialLayout)
        case .startNewGame:
            return () // this test is not applicable
        case .didBecomeActiveComingBack:
            subject.state.comingBackFromBackground = true
            await subject.didBecomeActive()
        }
        print(persistence.methodsCalled)
        #expect(persistence.methodsCalled.contains("loadData(forKey:)"))
        #expect(coordinator.methodsCalled.last == "makeBoardProcessor(gridSize:score:)")
        #expect(coordinator.gridSize == (3, 2))
        #expect(coordinator.score == 42)
    }

    @Test("awakening with no saved data configures state interface mode and stage label text",
          arguments: AwakeningType.allCases
    )
    func awakenStateNoSavedData(awakeningType: AwakeningType) async throws {
        persistence.values = [.lastStage: 4]
        switch awakeningType {
        case .didInitialLayout:
            await subject.receive(.didInitialLayout)
        case .startNewGame:
            await subject.receive(.startNewGame)
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
        persistence.values = [.boardData: data, .lastStage: 4]
        switch awakeningType {
        case .didInitialLayout:
            await subject.receive(.didInitialLayout)
        case .startNewGame:
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
        persistence.values = [.size: "Hard"]
        screen.traitCollection = UITraitCollection { traits in
            traits.userInterfaceIdiom = .pad
            traits.displayScale = 2
        }
        board.score = 42 // arbitrary, we are just checking that this value is saved
        switch awakeningType {
        case .didInitialLayout:
            await subject.receive(.didInitialLayout)
        case .startNewGame:
            await subject.receive(.startNewGame)
        case .didBecomeActiveComingBack:
            subject.state.comingBackFromBackground = true
            await subject.didBecomeActive()
        }
        #expect(coordinator.methodsCalled.last == "makeBoardProcessor(gridSize:score:)")
        #expect(presenter.thingsReceived.count == 4)
        #expect(presenter.thingsReceived[0] == .userInteraction(false))
        #expect(presenter.thingsReceived[1] == .animateBoardTransition(.fade))
        #expect(presenter.thingsReceived[2] == .animateStageLabel)
        #expect(presenter.thingsReceived[3] == .userInteraction(true))
        #expect(board._stageNumber == 0)
        #expect(board.methodsCalled == ["setStageNumber(_:)", "createAndDealDeck()", "stageNumber()", "stageNumber()", "deckAtStartOfStage"])
        // and we save board state
        #expect(persistence.methodsCalled.contains("save(_:forKey:)"))
        #expect(persistence.saveKeys.last == .boardData)
        let value = try #require(persistence.savedValues.last as? Data)
        let persistentState = try PropertyListDecoder().decode(PersistentState.self, from: value)
        #expect(persistentState == .init(
            board: .init(stageNumber: 0, grid: Grid(columns: 1, rows: 1), deckAtStartOfStage: ["brand new deck"]),
            score: 42,
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
        persistence.values = [.boardData: data]
        switch awakeningType {
        case .didInitialLayout:
            await subject.receive(.didInitialLayout)
        case .startNewGame:
            return () // this test is not applicable
        case .didBecomeActiveComingBack:
            subject.state.comingBackFromBackground = true
            await subject.didBecomeActive()
        }
        #expect(coordinator.methodsCalled == ["makeBoardProcessor(gridSize:score:)"])
        #expect(coordinator.score == 42)
        #expect(presenter.thingsReceived.count == 4)
        #expect(presenter.thingsReceived[0] == .userInteraction(false))
        #expect(presenter.thingsReceived[1] == .animateBoardTransition(.fade))
        #expect(presenter.thingsReceived[2] == .animateStageLabel)
        #expect(presenter.thingsReceived[3] == .userInteraction(true))
        #expect(board._stageNumber == 5)
        #expect(board.methodsCalled == ["setStageNumber(_:)", "populateFrom(oldGrid:deckAtStartOfStage:)", "stageNumber()"])
        #expect(board.grid == Grid(columns: 3, rows: 2))
        #expect(board._deckAtStartOfStage == ["hello"])
    }

    @Test(
        "awakening with initialData or startNewGame displays stored high score for current size and stage count",
        arguments: AwakeningType.allCases
    )
    func awakeHighScore(awakeningType: AwakeningType) async throws {
        do {
            persistence.values = [.size: "Hard", .lastStage: 7, .scores: ["Hard7": 42]]
            switch awakeningType {
            case .didInitialLayout:
                await subject.receive(.didInitialLayout)
            case .startNewGame:
                await subject.receive(.startNewGame)
            case .didBecomeActiveComingBack:
                return () // this test is not applicable
            }
            #expect(subject.state.highScore == "High score: 42")
            #expect(presenter.statesPresented.last?.highScore == "High score: 42")
        }
        do {
            // if the scores dictionary doesn't contain the key, empty string
            persistence.values = [.size: "Hard", .lastStage: 7, .scores: ["Hard8": 42]]
            switch awakeningType {
            case .didInitialLayout:
                await subject.receive(.didInitialLayout)
            case .startNewGame:
                await subject.receive(.startNewGame)
            case .didBecomeActiveComingBack:
                return () // this test is not applicable
            }
            #expect(subject.state.highScore == "")
            #expect(presenter.statesPresented.last?.highScore == "")
        }
        do {
            // if the scores dictionary is absent, empty string
            persistence.values = [.size: "Hard", .lastStage: 7]
            subject.state.highScore = "High score: 42"
            switch awakeningType {
            case .didInitialLayout:
                await subject.receive(.didInitialLayout)
            case .startNewGame:
                await subject.receive(.startNewGame)
            case .didBecomeActiveComingBack:
                return () // this test is not applicable
            }
            #expect(subject.state.highScore == "")
            #expect(presenter.statesPresented.last?.highScore == "")
        }
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
        board.score = 1
        board._stageNumber = 2
        board._deckAtStartOfStage = ["howdy"]
        board.grid = Grid(columns: 3, rows: 2)
        await subject.receive(.restartStage)
        await #while(persistence.methodsCalled.isEmpty)
        #expect(persistence.methodsCalled == ["save(_:forKey:)"])
        #expect(persistence.saveKeys == [.boardData])
        let value = try #require(persistence.savedValues.last as? Data)
        let persistentState = try PropertyListDecoder().decode(PersistentState.self, from: value)
        #expect(persistentState == .init(
            board: .init(stageNumber: 2, grid: Grid(columns: 3, rows: 2), deckAtStartOfStage: ["howdy"]),
            score: 1,
            timed: true
        ))
    }

    @Test("receive saveBoardState: saves the board state to persistence")
    func saveBoardState() async throws {
        board.score = 1
        board._stageNumber = 2
        board._deckAtStartOfStage = ["howdy"]
        board.grid = Grid(columns: 3, rows: 2)
        await subject.receive(.saveBoardState)
        await #while(persistence.methodsCalled.isEmpty)
        #expect(persistence.methodsCalled == ["save(_:forKey:)"])
        #expect(persistence.saveKeys == [.boardData])
        let value = try #require(persistence.savedValues.last as? Data)
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
        board.score = 1
        board._stageNumber = 2
        board._deckAtStartOfStage = ["howdy"]
        board.grid = Grid(columns: 3, rows: 2)
        await subject.receive(.viewDidLoad)
        try? await Task.sleep(for: .seconds(0.1))
        services.lifetime.didEnterBackgroundPublisher.send()
        await #while(persistence.methodsCalled.isEmpty)
        #expect(persistence.methodsCalled == ["save(_:forKey:)"])
        #expect(persistence.saveKeys == [.boardData])
        let value = try #require(persistence.savedValues.last as? Data)
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
    }

    @Test("after .viewDidLoad, lifetime didBecomeActive, if not coming back from background, calls scoreKeeper didBecomeActive")
    func didBecomeActiveNotComingBack() async throws {
        subject.state.comingBackFromBackground = false
        await subject.receive(.viewDidLoad)
        try? await Task.sleep(for: .seconds(0.1))
        services.lifetime.didBecomeActivePublisher.send()
        // TODO: we are not doing this any more, so what _are_ we doing?
//        let scoreKeeper = try #require(board.scoreKeeper as? MockScoreKeeper)
//        await #while(scoreKeeper.methodsCalled.isEmpty)
//        #expect(scoreKeeper.methodsCalled == ["didBecomeActive()"])
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

    @Test("stageEnded: if game ended with no previous high score, saves into scores, displays new high score")
    func stageEndedGameEndedNoPreviousHighScore() async {
        subject.state.highScore = "howdy"
        board._stageNumber = 5
        board.score = 10
        persistence.values = [.size: "Easy", .lastStage: 5]
        await subject.stageEnded()
        #expect(persistence.values[.scores] as? [String: Int] == ["Easy5": 10])
        #expect(presenter.statesPresented.first?.highScore == "High score: 10")
    }

    @Test("stageEnded: if game ended with lower previous high score, saves into scores, displays new high score")
    func stageEndedGameEndedLowerPreviousHighScore() async {
        subject.state.highScore = "howdy"
        board._stageNumber = 5
        board.score = 10
        persistence.values = [.size: "Easy", .lastStage: 5, .scores: ["Easy5": 9]] // lower
        await subject.stageEnded()
        #expect(persistence.values[.scores] as? [String: Int] == ["Easy5": 10])
        #expect(presenter.statesPresented.first?.highScore == "High score: 10")
    }

    @Test("stageEnded: if game ended with higher previous high score, no save of scores")
    func stageEndedGameEndedHigherPreviousHighScore() async {
        subject.state.highScore = "howdy"
        board._stageNumber = 5
        board.score = 10
        persistence.values = [.size: "Easy", .lastStage: 5, .scores: ["Easy5": 11]] // higher
        await subject.stageEnded()
        #expect(!persistence.saveKeys.contains(.scores))
        #expect(persistence.values[.scores] as? [String: Int] == ["Easy5": 11])
        #expect(presenter.statesPresented.first?.highScore == "howdy")
    }

    @Test("stageEnded: if game ended, continues by starting a new game")
    func stageEndedGameEndedNewGame() async throws {
        board._stageNumber = 5
        board.score = 10
        persistence.values = [.size: "Easy", .lastStage: 5, .scores: ["Easy5": 11]] // higher
        board.grid = Grid(columns: 3, rows: 4)
        board._deckAtStartOfStage = ["howdy"]
        await subject.stageEnded()
        // and the rest is like "then what" when launching,
        await #while(presenter.thingsReceived.count < 4)
        #expect(presenter.thingsReceived.count == 4)
        #expect(presenter.thingsReceived[0] == .userInteraction(false))
        #expect(presenter.thingsReceived[1] == .animateBoardTransition(.fade))
        #expect(presenter.thingsReceived[2] == .animateStageLabel)
        #expect(presenter.thingsReceived[3] == .userInteraction(true))
        #expect(board._stageNumber == 0) // new game
        #expect(board.methodsCalled ==  ["stageNumber()", "setStageNumber(_:)", "createAndDealDeck()", "stageNumber()", "stageNumber()", "deckAtStartOfStage"])
        // and we save board state
        #expect(persistence.saveKeys.last == .boardData)
        let value = try #require(persistence.savedValues.last as? Data)
        let persistentState = try PropertyListDecoder().decode(PersistentState.self, from: value)
        print("XXX", persistentState)
        #expect(persistentState == .init(
            board: .init(stageNumber: 0, grid: Grid(columns: 3, rows: 4), deckAtStartOfStage: ["brand new deck"]),
            score: 10,
            timed: true
        ))
    }

    @Test("stageEnded: if game didn't end yet, calls coordinator makeBoardProcessor with incremented stage")
    func stageEndedGameNotEnded() async throws {
        board._stageNumber = 5
        persistence.values = [.lastStage: 6]
        board.grid = Grid(columns: 3, rows: 4)
        board._deckAtStartOfStage = ["howdy"]
        board.score = 10
        await subject.stageEnded()
        #expect(persistence.loads.first?.1 == .lastStage)
        #expect(coordinator.methodsCalled == ["makeBoardProcessor(gridSize:score:)"])
        #expect(coordinator.gridSize == (3, 4))
        #expect(coordinator.score == 10)
        // and the rest is like "then what" when launching,
        // but board transition is slide and stage number is incremented
        await #while(presenter.thingsReceived.count < 4)
        #expect(presenter.thingsReceived.count == 4)
        #expect(presenter.thingsReceived[0] == .userInteraction(false))
        #expect(presenter.thingsReceived[1] == .animateBoardTransition(.slide)) // NB slide transition
        #expect(presenter.thingsReceived[2] == .animateStageLabel)
        #expect(presenter.thingsReceived[3] == .userInteraction(true))
        #expect(board._stageNumber == 6) // NB incrementing stage number
        #expect(board.methodsCalled ==  ["stageNumber()", "setStageNumber(_:)", "createAndDealDeck()", "stageNumber()", "stageNumber()", "deckAtStartOfStage"])
        // and we save board state
        #expect(persistence.methodsCalled.last == "save(_:forKey:)")
        #expect(persistence.saveKeys.last == .boardData)
        let value = try #require(persistence.savedValues.last as? Data)
        let persistentState = try PropertyListDecoder().decode(PersistentState.self, from: value)
        #expect(persistentState == .init(
            board: .init(stageNumber: 6, grid: Grid(columns: 3, rows: 4), deckAtStartOfStage: ["brand new deck"]),
            score: 10,
            timed: true
        ))
    }

    @Test("userTappedPathView: hides hilite and hint")
    func userTappedPathView() async {
        subject.state.hintShowing = true
        subject.state.hintButtonTitle = .hide
        await subject.userTappedPathView()
        await #while(subject.state.hintShowing == true)
        #expect(subject.state.hintShowing == false)
        #expect(subject.state.hintButtonTitle == .show)
        #expect(presenter.statesPresented.last?.hintShowing == false)
        #expect(presenter.statesPresented.last?.hintButtonTitle == .show)
        #expect(board.methodsCalled == ["unhilite()", "showHint(_:)"])
        #expect(board.show == false)
    }

    @Test("scoreChanged: sets the state and presents it")
    func scoreChanged() async {
        await subject.scoreChanged(.init(score: 100, direction: .up))
        #expect(subject.state.score == .init(score: 100, direction: .up))
        #expect(presenter.statesPresented.first?.score == .init(score: 100, direction: .up))
    }
}

/// We need this so that the processor sees its presenter as a dismissal delegate;
/// but I expect all this to change when I move the delegate to the subject itself!
extension MockReceiverPresenter: NewGamePopoverDismissalButtonDelegate {
    func cancelNewGame() {}
    func startNewGame() {}
}
