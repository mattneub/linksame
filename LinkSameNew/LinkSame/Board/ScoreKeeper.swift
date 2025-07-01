import UIKit

// ------ score-calculation utilities ------

/// Linear interpolation formula
///
/// https://math.stackexchange.com/a/377174
/// "If you have numbers x in the range [a,b] and you want to transform them
/// to numbers y in the range [c,d], you need to do this:
/// y = (x-a)*(d-c)/(b-a)+c"
///
func transform(x: Double, r1lo a: Double, r1hi b: Double, r2lo c: Double, d2hi d: Double) -> Double {
    return (x-a)*(d-c)/(b-a)+c
}

/// Calculate bonus points based on how quickly the user moved since the last move.
/// - Parameter diff: Time interval between moves.
/// - Returns: Number of bonus points to award.
///
func calcBonus(_ diff: Double) -> Int {
    // There is a rare crash here where `diff` is a nan or infinite. To avoid this, let's try to
    // pick out the crash cases and return some value immediately. I am not actually sure what
    // value to return; should it be zero or 10, the two ends of the scale as it were...?
    if diff.isNaN || diff.isInfinite {
        return 0
    }
    let bonus = if diff >= 10 {
        0.0
    } else {
        15-1.5*transform(
            x: diff.squareRoot(), r1lo: 0, r1hi: (10.0).squareRoot(), r2lo: 0, d2hi: 10
        )
    }
    return Int(bonus)
}

/// Protocol describing the public face of our ScoreKeeper object, so we can mock it for testing.
@MainActor
protocol ScoreKeeperType: AnyObject {
    var delegate: (any ScoreKeeperDelegate)? { get }
    var score: Int { get }
    func userMadeLegalMove() async
    func userAskedForShuffle() async
    func userAskedForHint() async
    func userRestartedStage() async
    func stopTimer() async
    func pauseTimer() async
    func restartTimerIfPaused() async
}

/// The ScoreKeeper object maintains and controls the timer, and keeps the score.
/// The idea is to make a new ScoreKeeper object every time a new timed stage begins,
/// and then communicate with it mostly in terms of game-related events, telling it
/// (for example) what the user did; a few messages do tell the ScoreKeeper to start
/// or stop the timer, but no message ever tells the ScoreKeeper how to keep the score!
///
@MainActor
final class ScoreKeeper: ScoreKeeperType {
    /// The current score.
    var score: Int
    /// The score when we were created. We are created on every stage, so this allows us
    /// to implement restarting the stage if needed. It's a var only for testing purposes.
    var scoreAtStartOfStage: Int
    /// The all-important timer. If a timer exists, it is timing unless (1) it is canceled or
    /// (2) it times out. A timer does _not_ exist when we are created, as the user has not
    /// yet made a move.
    var timer: (any CancelableTimerType)?
    /// Whether the timer was running when we were told to pause it.
    var timerWasRunning = false
    /// When the user last moved. This is used to calculate bonus points for speed in moving.
    private var lastTime: Date = Date.distantPast

    /// Reference to our delegate, to whom we will report any change in the score.
    weak var delegate: (any ScoreKeeperDelegate)?
    
    /// Initializer. A new ScoreKeeper is created together with the BoardProcessor, which
    /// happens when the app awakens and every time a new stage begins.
    /// - Parameters:
    ///   - score: The score at the start of the stage.
    ///   - delegate: Delegate to whom we will report the score.
    init(score: Int, delegate: (any ScoreKeeperDelegate)?) {
        self.score = score
        self.scoreAtStartOfStage = score // might need this if we restart this stage later
        self.delegate = delegate
        // And immediately report the score, thus causing it to be displayed.
        Task {
            await delegate?.scoreChanged(Score(score: score, direction: .up))
        }
    }

    /// Utility: start the timer counting down from 10, and if it times out, have it call our
    /// `timerTimedOut` method. This is done by _creating_ the timer; if it exists and has not
    /// been canceled or timed out, it is counting.
    private func restartTimer() {
        self.timer = services.cancelableTimer.init(interval: 10) { [weak self] in
            await self?.timerTimedOut()
        }
    }

    /// Called back from the timer if it times out. This means the user has failed to move in time.
    /// Adjust the score, notify the delegate.
    func timerTimedOut() async {
        self.score -= 1
        await delegate?.scoreChanged(Score(score: score, direction: .down))
        restartTimer()
    }

    /// Pause the timer, recording whether it was running so we can resume if it was.
    func pauseTimer() async {
        if let timer {
            timerWasRunning = await timer.isRunning
            print("timer pausing; was running?", timerWasRunning)
            await timer.cancel()
        }
    }

    /// Start the timer, but only if it was running when we paused.
    func restartTimerIfPaused() async {
        if timerWasRunning {
            restartTimer()
        }
    }

    /// Stop the timer.
    func stopTimer() async {
        await self.timer?.cancel()
    }

    /// The user asked for a hint. Lose ten points.
    func userAskedForHint() async {
        self.restartTimer()
        self.score -= 10
        await delegate?.scoreChanged(Score(score: score, direction: .down))
    }

    /// The user asked for a shuffle. Lose twenty points.
    func userAskedForShuffle() async {
        self.restartTimer()
        self.score -= 20
        await delegate?.scoreChanged(Score(score: score, direction: .down))
    }

    /// The user made a legal move. Awaord one point, plus a bonus for speed.
    func userMadeLegalMove() async {
        self.restartTimer()
        // calculate time between moves, award points
        let now = Date()
        let diff = now.timeIntervalSinceReferenceDate - self.lastTime.timeIntervalSinceReferenceDate
        self.lastTime = now
        let bonus = calcBonus(diff)
        print("diff", diff)
        print("bonus", bonus)
        self.score += 1 + bonus
        // tell the delegate
        await delegate?.scoreChanged(Score(score: self.score, direction: .up))
    }

    /// The user restarted the stage. Restore the score from when the stage originally started.
    func userRestartedStage() async {
        await self.timer?.cancel()
        self.score = self.scoreAtStartOfStage
        await delegate?.scoreChanged(Score(score: score, direction: .up))
    }
}

/// Protocol for reporting changes in the score. All changes in the score must be reported; the
/// delegate needs to know both the new score and whether this represents an up or down movements
/// of the score value.
@MainActor
protocol ScoreKeeperDelegate: AnyObject {
    func scoreChanged(_: Score) async
}

/// Struct expressing the score value together with the direction of change.
struct Score: Equatable {
    let score: Int
    let direction: ScoreDirection
    enum ScoreDirection {
        case up
        case down
    }
}
