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

    func receive(_ action: LinkSameAction) async {
        switch action {
        case .cancelNewGame:
            coordinator?.dismiss()
            if let popoverDefaults = state.defaultsBeforeShowingNewGamePopover {
                services.persistence.saveIndividually(popoverDefaults.toDefaultsDictionary)
                state.defaultsBeforeShowingNewGamePopover = nil
            }
        case .didInitialLayout:
            await setUpGameFromScratch()
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
            // store these defaults so we can restore them later if user cancels
            state.defaultsBeforeShowingNewGamePopover = PopoverDefaults(
                defaultsDictionary: services.persistence.loadAsDictionary([.style, .size, .lastStage])
            )
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

        board.stageNumber = 0 // default, we might change this in a moment
        // self.board.stage = 8 // testing, comment out!

        let stage = Stage()
        // TODO: need to restore this somehow
        // self.interfaceMode = .timed // every new game is a timed game
        board.createAndDealDeck()
        let boardTransition: BoardTransition = .fade
        await presenter?.receive(.animateBoardTransition(boardTransition))
        saveBoardState()

        self.stage = stage

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

    func saveBoardState() {
        guard let board = boardProcessor as? BoardProcessor else { return } // TODO: need to fix entirely what gets saved here
        guard let score = stage?.score else { return }
        let state = PersistentState(
            board: board,
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
    let board: BoardProcessor
    let score: Int
    let timed: Bool
}
