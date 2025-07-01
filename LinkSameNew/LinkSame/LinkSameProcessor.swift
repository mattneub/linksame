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

    /// Board processor that will manage the board view where the game action takes place.
    /// This is a strong reference! The board processor is rooted here.
    var boardProcessor: (any BoardProcessorType)?

    /// Helper object that manages the hamburger button choices and responses.
    var hamburgerRouter: (any HamburgerRouterType) = HamburgerRouter()

    /// Storage for our never-ending task containing eternal for-loops. See the Lifetime object.
    var subscriptionsTask: Task<(), Never>?

    /// Utility for constructing the text displayed by the stage label.
    var stageLabelText: String {
        let stageNumber = self.boardProcessor?.stageNumber() ?? 0
        let maxStages = services.persistence.loadInt(forKey: .lastStage)
        return "Stage \(stageNumber + 1) of \(maxStages + 1)"
    }

    func receive(_ action: LinkSameAction) async {
        switch action {
        case .cancelNewGame: // comes from the new game popover
            coordinator?.dismiss()
            restorePopoverDefaults()
        case .didInitialLayout: // sent only once, so this means we are launching
            await presenter?.receive(.setHamburgerMenu(hamburgerRouter.makeMenu(processor: self)))
            await showHighScore()
            if let savedStateData = services.persistence.loadData(forKey: .boardData),
               let savedState = try? PropertyListDecoder().decode(PersistentState.self, from: savedStateData) {
                await setUpGameFromSavedState(savedState)
            } else {
                await setUpGameFromScratch()
            }
        case .hint:
            // This is a _toggle_, based on the state. The called methods
            // _also_ check the state, so they can be called directly elsewhere.
            // Also, as the name suggests, they unhilite any hilited pieces no matter what,
            // which saves repetition.
            if state.hintShowing {
                await hideHintAndUnhilite()
            } else {
                await showHintAndUnhilite()
            }
        case .hamburger:
            await hideHintAndUnhilite()
        case .restartStage:
            await hideHintAndUnhilite()
            await restartStage()
        case .saveBoardState:
            saveBoardState()
        case .showHelp(sender: let sender):
            await hideHintAndUnhilite()
            coordinator?.showHelp(
                sourceItem: sender,
                popoverPresentationDelegate: HelpPopoverDelegate()
                // I'm surprised I don't have to keep a reference
            )
        case .showNewGame(sender: let sender):
            await hideHintAndUnhilite()
            coordinator?.showNewGame(
                sourceItem: sender,
                popoverPresentationDelegate: NewGamePopoverDelegate(),
                // I'm surprised I don't have to keep a reference
                dismissalDelegate: self
            )
            savePopoverDefaults()
        case .shuffle:
            await hideHintAndUnhilite()
            await boardProcessor?.shuffle()
        case .startNewGame: // comes from the new game popover
            coordinator?.dismiss()
            state.defaultsBeforeShowingNewGamePopover = nil // crucial or we'll fall one behind
            await showHighScore()
            await setUpGameFromScratch()
        case .timedPractice(let segment):
            await hideHintAndUnhilite()
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

    /// Set up "subscriptions" to the Lifetime "notifications".
    /// Called once, when `.viewDidLoad` is received.
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
            group.addTask { @Sendable @MainActor in
                for await _ in services.lifetime.willEnterForegroundPublisher.values {
                    await self.willEnterForeground()
                }
            }
        }
    }

    /// Set up the entire game from scratch: new board, new pieces, stage 0, score 0.
    func setUpGameFromScratch() async {
        let (boardColumns, boardRows) = Sizes.boardSize(services.persistence.loadString(forKey: .size) ?? Sizes.easy)
        coordinator?.makeBoardProcessor(gridSize: (boardColumns, boardRows), score: 0)
        state.interfaceMode = .timed // all new games are timed games
        await setUpNewStage(stageNumber: 0)
    }

    /// Follow-on from `setUpGameFromScratch`, factored out so `stageEnded` can call it too,
    /// with different stage number. As the name says, set up the new stage: make a deck and
    /// deal it out, transition the board appropriately, show the stage label, save the board state.
    /// - Parameter stageNumber: The number of the new stage.
    func setUpNewStage(stageNumber: Int) async {
        await presenter?.receive(.userInteraction(false))

        boardProcessor?.setStageNumber(stageNumber)
        // self.board.stage = 8 // testing game end behavior, comment out!

        // build and display board
        do {
            try await boardProcessor?.createAndDealDeck()
        } catch {
            print(error) // TODO: could use better error handling, perhaps
            return
        }
        let boardTransition: BoardTransition = stageNumber == 0 ? .fade : .slide
        await presenter?.receive(.animateBoardTransition(boardTransition))

        // show stage label
        state.stageLabelText = stageLabelText
        await presenter?.present(state)
        await presenter?.receive(.animateStageLabel)

        await presenter?.receive(.userInteraction(true))

        saveBoardState() // last of all, now that everything is configured
    }

    /// Set up the entire game from persistent state that was found in user defaults.
    /// The board's grid, the pieces, the stage, the score all come from this.
    func setUpGameFromSavedState(_ savedState: PersistentState) async {
        let boardData = savedState.board
        let grid = boardData.grid
        coordinator?.makeBoardProcessor(gridSize: (grid.columns, grid.rows), score: savedState.score)

        await presenter?.receive(.userInteraction(false))

        boardProcessor?.setStageNumber(boardData.stageNumber)
        await boardProcessor?.populateFrom(oldGrid: grid, deckAtStartOfStage: boardData.deckAtStartOfStage)

        await presenter?.receive(.animateBoardTransition(.fade))

        state.interfaceMode = savedState.timed ? .timed : .practice
        state.stageLabelText = stageLabelText
        await presenter?.present(state)
        await presenter?.receive(.animateStageLabel)

        await presenter?.receive(.userInteraction(true))
    }

    /// The app is entering the background; respond.
    func didEnterBackground() async {
        if state.interfaceMode == .practice {
            saveBoardState()
        }
        // In a timed game, we do not save the board state.
    }

    /// The app is becoming active; respond. Not received at launch time, only subsequently.
    func didBecomeActive() async {
        await boardProcessor?.restartTimerIfPaused()
    }

    /// The app is about to enter the foreground; respond.
    func willEnterForeground() async {
        // Well, this situation is exactly as if we had just launched: either there is saved
        // data or there isn't, and either way we want to set up the game based on that.
        // So we just repeat the `receive` code for `.didInitialLayout`.
        await showHighScore()
        if let savedStateData = services.persistence.loadData(forKey: .boardData),
           let savedState = try? PropertyListDecoder().decode(PersistentState.self, from: savedStateData) {
            await setUpGameFromSavedState(savedState)
        } else {
            await setUpGameFromScratch()
        }
    }

    /// The app is about to become inactive; respond.
    ///
    /// **NOTE:** If the user pulls down the notification center, we will get _two_ `willResignActive`
    /// calls. But that's okay, because everything we are doing here is lightweight; there is no
    /// harm in doing it twice. The only thing that is "reversible" is pausing the timer, and it
    /// is balanced by restarting the timer in `didBecomeActive` — so the worst that can happen
    /// is we will just pause, resume, and pause again.
    func willResignActive() async {
        // Pause the timer!
        await boardProcessor?.pauseTimer()
        // In case we are showing hint, stop showing it.
        await hideHintAndUnhilite()
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

    /// Gather state information and store it into persistence.
    func saveBoardState() {
        guard let board = boardProcessor else { return }
        let boardData = BoardSaveableData(
            stageNumber: board.stageNumber(),
            grid: board.grid,
            deckAtStartOfStage: board.deckAtStartOfStage
        )
        let state = PersistentState(
            board: boardData,
            score: board.score,
            timed: state.interfaceMode == .timed
        )
        if let stateData = try? PropertyListEncoder().encode(state) {
            services.persistence.save(stateData, forKey: .boardData)
        }
    }

    /// Hide the hint (and incidentally remove any piece highlighting).
    func hideHintAndUnhilite() async {
        await boardProcessor?.unhilite()
        if state.hintShowing {
            state.hintShowing = false
            state.hintButtonTitle = .show
            await presenter?.present(state)
            await boardProcessor?.showHint(false)
        }
    }

    /// Show a hint (and incidentally remove any piece highlighting).
    func showHintAndUnhilite() async {
        await boardProcessor?.unhilite()
        if !state.hintShowing {
            state.hintShowing = true
            state.hintButtonTitle = .hide
            await presenter?.present(state)
            await boardProcessor?.showHint(true)
        }
    }

    /// Restart the current stage.
    func restartStage() async {
        do {
            await presenter?.receive(.userInteraction(false))
            try await boardProcessor?.restartStage()
            await presenter?.receive(.animateBoardTransition(.fade))
            await presenter?.receive(.animateStageLabel)
            saveBoardState()
            await presenter?.receive(.userInteraction(true))
        } catch {
            await presenter?.receive(.userInteraction(true))
            print(error)
        }
    }

    /// Display the current high score, based on info in persistence.
    func showHighScore() async {
        let size = services.persistence.loadString(forKey: .size) ?? Sizes.easy
        let lastStage = services.persistence.loadInt(forKey: .lastStage)
        let scoresKey = "\(size)\(lastStage)"
        let scores: [String: Int]? = services.persistence.loadDictionary(forKey: .scores)
        if let score = scores?[scoresKey] {
            state.highScore = "High score: \(score)"
        } else {
            state.highScore = ""
        }
        await presenter?.present(state)
    }

    /// Utility called only by `stageEnded` when it has determined that the user has finished
    /// the entire game. If the score is a new high score for this level, record and display it.
    /// Then start the game from scratch exactly as from the New Game popover Done button.
    /// - Parameters:
    ///   - lastStage: The number of the final stage of this game.
    ///   - score: The score at the end of the game.
    func gameEnded(lastStage: Int, score: Int) async {
        var newHigh = false
        if state.interfaceMode == .timed { // is this a new high score? only matters if timed mode
            let size = services.persistence.loadString(forKey: .size) ?? Sizes.easy
            let scoresKey = "\(size)\(lastStage)"
            var scores: [String: Int] = services.persistence.loadDictionary(forKey: .scores) ?? [:]
            let oldScore = scores[scoresKey] ?? Int.min
            if score > oldScore { // this is a new high score! take note, save it into persistence
                newHigh = true
                scores[scoresKey] = score
                services.persistence.save(scores, forKey: .scores)
            }
        }
        coordinator?.showGameOver(
            state: GameOverState(
                newHigh: newHigh,
                score: score,
                practice: state.interfaceMode == .practice
            )
        )
        // new approach: start next game without waiting for alert dismissal
        // this is just like `.startNewGame`, basically
        await showHighScore()
        await setUpGameFromScratch()
    }
}

/// Messages from the BoardProcessor.
extension LinkSameProcessor: BoardDelegate {
    /// The stage ended; there are no more pieces on the board. Either the entire game has now
    /// ended, or else we need to proceed to a new stage.
    func stageEnded() async {
        guard let board = boardProcessor else {
            return
        }

        // If game has just ended, start a whole new game and notify the user somehow.
        let stageNumber = board.stageNumber()
        let lastStage = services.persistence.loadInt(forKey: .lastStage)
        if stageNumber >= lastStage {
            await gameEnded(lastStage: lastStage, score: board.score)
            return
        }

        // The game has not ended, so make a new board and start a new stage.
        let gridSize = (board.grid.columns, board.grid.rows)
        coordinator?.makeBoardProcessor(gridSize: gridSize, score: board.score)
        await setUpNewStage(stageNumber: stageNumber + 1)
    }

    /// The user tapped the path view. This can happen only while a hint is showing,
    /// and means we should hide the hint.
    func userTappedPathView() async {
        await hideHintAndUnhilite()
    }
}

/// Messages from the NewGameProcessor.
extension LinkSameProcessor: NewGamePopoverDismissalButtonDelegate {
    /// The user has asked to start a new game.
    func startNewGame() async {
        await receive(.startNewGame)
    }

    /// The user has cancelled the popover.
    func cancelNewGame() async {
        await receive(.cancelNewGame)
    }
}

/// Messages from the ScoreKeeper.
extension LinkSameProcessor: ScoreKeeperDelegate {
    /// The score keeper is telling us what the score should be, so set the state and present
    /// it. This should be the _only_ way that the display of the score is affected!
    func scoreChanged(_ score: Score) async {
        state.score = score
        await presenter?.present(state)
    }
}

/// Reducer representing a clump of saveable game state.
@MainActor
struct PersistentState: Equatable, Codable {
    let board: BoardSaveableData
    let score: Int
    let timed: Bool
}

