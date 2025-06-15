import UIKit

/// Processor that contains the logic for the module. This is the primary processor of the app as a whole.
@MainActor
final class LinkSameProcessor: Processor {
    
    /// Reference to our chief presenter. Set by the coordinator on module creation.
    weak var presenter: (any ReceiverPresenter<LinkSameEffect, LinkSameState>)?

    /// Reference to the coordinator. Set by the coordinator on module creation.
    weak var coordinator: (any RootCoordinatorType)?

    /// State to be passed to the presenter for reflection in the interface.
    var state = LinkSameState()

    /// Stage object that will help manage timer and score while a stage is being played.
    var stage: Stage?

    /// Board processor that will manage the board view where the game action takes place.
    var boardProcessor: (any BoardProcessorType)?

    /// Storage for our never-ending task containing eternal for-loops. See the Lifetime object.
    var subscriptionsTask: Task<(), Never>?

    var stageLabelText: String {
        let stageNumber = self.boardProcessor?.stageNumber ?? 0
        let maxStages = services.persistence.loadInt(forKey: .lastStage)
        return "Stage \(stageNumber + 1) of \(maxStages + 1)"
    }

    func receive(_ action: LinkSameAction) async {
        switch action {
        case .cancelNewGame:
            coordinator?.dismiss()
            restorePopoverDefaults()
        case .didInitialLayout: // sent only once, so this means we are launching
            if let savedStateData = services.persistence.loadData(forKey: .boardData),
               let savedState = try? PropertyListDecoder().decode(PersistentState.self, from: savedStateData) {
                await setUpGameFromSavedState(savedState)
            } else {
                await setUpGameFromScratch()
            }
        case .saveBoardState:
            saveBoardState()
        case .showHelp(sender: let sender):
            coordinator?.showHelp(
                sourceItem: sender,
                popoverPresentationDelegate: HelpPopoverDelegate() // TODO: might have to keep a reference of course
            )
        case .showNewGame(sender: let sender):
            coordinator?.showNewGame(
                sourceItem: sender,
                popoverPresentationDelegate: NewGamePopoverDelegate(), // TODO: might have to keep a reference of course
                dismissalDelegate: presenter as? any NewGamePopoverDismissalButtonDelegate
            )
            savePopoverDefaults()
        case .startNewGame:
            coordinator?.dismiss()
            state.defaultsBeforeShowingNewGamePopover = nil // crucial or we'll fall one behind
            state.interfaceMode = .timed // TODO: Currently we presume that all new games start as timed
            await presenter?.present(state)
        case .timedPractice(let segment):
            state.interfaceMode = .init(rawValue: segment)!
            await presenter?.present(state)
        case .viewDidLoad:
            // The call to `setUpLifetimeSubscriptions` never returns, so we call it in a detached task
            // and store the task.
            let subscriptionsTask = Task.detached {
                await self.setUpLifetimeSubscriptions()
            }
            self.subscriptionsTask = subscriptionsTask
        }
    }

    /// Set up "subscriptions" to the Lifetime "notifications". Called once, when `.viewDidLoad` is received.
    ///
    /// **NOTE:** This method never returns! Be careful how you call it.
    ///
    func setUpLifetimeSubscriptions() async {
        await withTaskGroup(returning: Void.self) { group in
            group.addTask { @Sendable @MainActor in
                for await _ in services.lifetime.didEnterBackgroundPublisher.values {
                    await self.didEnterBackground()
                }
            }
            group.addTask { @Sendable @MainActor in
                for await _ in services.lifetime.didBecomeActivePublisher.values {
                    await self.didBecomeActive()
                }
            }
            group.addTask { @Sendable @MainActor in
                for await _ in services.lifetime.willResignActivePublisher.values {
                    await self.willResignActive()
                }
            }
        }
    }

    /// Set up the entire game from scratch: new board, new pieces, stage 0, score 0.
    func setUpGameFromScratch() async {
        // determine layout dimensions
        let (boardColumns, boardRows) = if onPhone {
            Sizes.boardSize(Sizes.easy)
        } else {
            Sizes.boardSize(services.persistence.loadString(forKey: .size))
        }
        // create new board object and configure it
        guard let board = coordinator?.makeBoardProcessor(gridSize: (boardColumns, boardRows)) else {
            return
        }
        self.boardProcessor = board

        await presenter?.receive(.userInteraction(false))

        // put its `view` into the interface, replacing the one that may be there already
        await presenter?.receive(.putBoardViewIntoInterface(board.view))

        boardProcessor?.stageNumber = 0
        // self.board.stage = 8 // testing game end behavior, comment out!

        self.stage = Stage(score: 0)

        // build and display board
        boardProcessor?.createAndDealDeck()
        let boardTransition: BoardTransition = .fade
        await presenter?.receive(.animateBoardTransition(boardTransition))

        // show stage label
        state.interfaceMode = .timed // TODO: assuming every new game is a timed game
        state.stageLabelText = stageLabelText
        await presenter?.present(state)
        await presenter?.receive(.animateStageLabel)

        await presenter?.receive(.userInteraction(true))

        saveBoardState() // last of all, now that everything is configured
    }

    /// Set up the entire game from persistent state that was found in user defaults.
    /// The board's grid, the pieces, the stage, the score all come from this.
    func setUpGameFromSavedState(_ savedState: PersistentState) async {
        // structure is: -------
        // let board: BoardSaveableData
        // let score: Int
        // let timed: Bool
        // where BoardSaveableData is: -------
        // let stage: Int
        // let frame: CGRect [but I think this can be cut]
        // let grid: Grid
        // let deckAtStartOfStage: [String]
        let boardData = savedState.board
        let grid = boardData.grid
        guard let board = coordinator?.makeBoardProcessor(gridSize: (grid.columns, grid.rows)) else {
            return
        }
        await presenter?.receive(.userInteraction(false))

        self.boardProcessor = board

        // put its `view` into the interface, replacing the one that may be there already
        await presenter?.receive(.putBoardViewIntoInterface(board.view))

        boardProcessor?.stageNumber = boardData.stage
        boardProcessor?.populateFrom(oldGrid: grid, deckAtStartOfStage: boardData.deckAtStartOfStage)

        self.stage = Stage(score: savedState.score)

        await presenter?.receive(.animateBoardTransition(.fade))

        state.interfaceMode = savedState.timed ? .timed : .practice
        state.stageLabelText = stageLabelText
        await presenter?.present(state)
        await presenter?.receive(.animateStageLabel)

        await presenter?.receive(.userInteraction(true))
    }

    /// The app is entering the background; respond.
    func didEnterBackground() async {
        switch state.interfaceMode {
        case .timed:
            // In a timed game, we do not save the board state; a half-played game is thrown away.
            // Rather, the board state was saved when the stage started, and so when we come back
            // to the front, we will resume the stage from the beginning.
            // However, we do hide the board view so it doesn't appear in the app switcher snapshot.
            state.boardViewHidden = true
            await presenter?.present(state)
        case .practice:
            // In a practice game, we do save the board state, and we allow it to appear in the
            // app switcher snapshot.
            saveBoardState()
        }
    }

    /// The app is becoming active; respond. Not received at launch time, only subsequently.
    func didBecomeActive() async {
        // eliminate spurious call when user pulls down the notification center
        try? await Task.sleep(for: .seconds(0.05))
        if UIApplication.shared.applicationState == .inactive {
            return
        }
        // TODO: Do something real here.
        print("did become active")
    }

    /// The app is about to become inactive; respond.
    func willResignActive() async {
        // In case we are showing any presented stuff, dismiss it.
        coordinator?.dismiss()
        // And in case what was showing was the New Game popover, that counts as cancellation
        // so restore the defaults.
        restorePopoverDefaults()
    }

    /// As the New Game popover appears, save off the defaults that the user can change there,
    /// so that if the user cancels after making some changes, we can restore them.
    func savePopoverDefaults() {
        state.defaultsBeforeShowingNewGamePopover = PopoverDefaults(
            defaultsDictionary: services.persistence.loadAsDictionary([.style, .size, .lastStage])
        )
    }

    /// If we stored any old popover defaults (because we showed the New Game popover), restore them.
    func restorePopoverDefaults() {
        if let popoverDefaults = state.defaultsBeforeShowingNewGamePopover {
            services.persistence.saveIndividually(popoverDefaults.toDefaultsDictionary)
            state.defaultsBeforeShowingNewGamePopover = nil
        }
    }

    func saveBoardState() {
        guard let board = boardProcessor else { return }
        let boardData = BoardSaveableData(boardProcessor: board)
        guard let score = stage?.score else { return }
        let state = PersistentState(
            board: boardData,
            score: score,
            timed: state.interfaceMode == .timed
        )
        if let stateData = try? PropertyListEncoder().encode(state) {
            services.persistence.save(stateData, forKey: .boardData)
        }
    }
}

/// Reducer representing a clump of saveable game state.
@MainActor
struct PersistentState: Codable {
    let board: BoardSaveableData
    let score: Int
    let timed: Bool
}
