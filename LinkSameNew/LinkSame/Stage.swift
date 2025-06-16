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

/// Protocol describing the public face of our Stage object, so we can mock it for testing.
@MainActor
protocol StageType {
    var score: Int { get set }
    func didBecomeActive()
}

/// The Stage object brings together the score, the timer, and control over the score display in the interface.
/// The idea is to make a new Stage object every time a new timed stage begins,
/// and then communicate with it only in terms of game-related events.
///
@MainActor
final class Stage: StageType {
    var score: Int
    let scoreAtStartOfStage: Int
    private var timer: CancelableTimer? // no timer initially (user has not moved yet)
    private var lastTime: Date = Date.distantPast

    init(score: Int) { // initial score for this stage
        self.score = score
        self.scoreAtStartOfStage = score // might need this if we restart this stage later
        print("new Stage object!", self)

//        self.lsvc.scoreLabel?.text = String(self.score)
//        self.lsvc.scoreLabel?.textColor = .black
//        if let scoresDict: [String: Int] = services.persistence.loadDictionary(forKey: .scores),
//            let prev = scoresDict[self.lsvc.scoresKey] {
//            self.lsvc.prevLabel?.text = "High score: \(prev)"
//        } else {
//            self.lsvc.prevLabel?.text = ""
//        }

        /*
        // application lifetime events affect our timer
        nc.addObserver(self, selector: #selector(resigningActive),
                       name: UIApplication.willResignActiveNotification, object: nil)
        // long-distance communication from the board object
        nc.addObserver(self, selector: #selector(userMadeLegalMove),
                       name: Board.userMoved, object: nil)
        nc.addObserver(self, selector: #selector(gameEnded),
                       name: Board.gameOver, object: nil)
         */
    }
    deinit {
        print("farewell from Stage object", self)
        // self.timer?.cancel()
        // nc.removeObserver(self) // probably not needed, but whatever
    }
    // okay, you're never going to believe this one
    // I finally saw how to register for become active without triggering on the first one:
    // register in the first resign active! what a dummy I am not to have realized this
    private var didResign = false
    @objc private func resigningActive() { // notification
        Task {
            await self.timer?.cancel()
        }
//        if !self.didResign {
//            self.didResign = true
//            nc.addObserver(self, selector: #selector(didBecomeActive),
//                           name: UIApplication.didBecomeActiveNotification, object: nil)
//        }
    }
    private func restartTimer() { // private utility: start counting down from 10
        self.timer = CancelableTimer(interval: 10) { [weak self] in
            await self?.timerTimedOut()
        }
    }

    private func timerTimedOut() {
        // timed out! user failed to move, adjust score, interface
        // this is our main job!
        self.score -= 1
//        self.lsvc.scoreLabel?.text = String(self.score)
//        self.lsvc.scoreLabel?.textColor = .red
//        restartTimer()
    }

    /// Called by the processor to let us know that we have become active after becoming inactive
    /// (i.e. not backgrounded, which is a whole different affair). This is regarded as a temporary
    /// interruption in the game, so carry on timing.
    func didBecomeActive() {
        self.restartTimer()
    }

    @objc private func gameEnded() { // notification from Board
        Task {
            await self.timer?.cancel()
        }
    }
    func userAskedForHint() { // called by LinkSameViewController
        self.restartTimer()
        self.score -= 10
//        self.lsvc.scoreLabel?.text = String(self.score)
//        self.lsvc.scoreLabel?.textColor = .red
    }

    func userAskedForShuffle() { // called by LinkSameViewController
        self.restartTimer()
        self.score -= 20
//        self.lsvc.scoreLabel?.text = String(self.score)
//        self.lsvc.scoreLabel?.textColor = .red
    }

    @objc private func userMadeLegalMove() { // notification from Board
        self.restartTimer()
        // calculate time between moves, award points (and remember, points mean prizes)
        let now = Date()
        let diff = now.timeIntervalSinceReferenceDate - self.lastTime.timeIntervalSinceReferenceDate
        self.lastTime = now
        // THIS IS A MAJOR CHANGE, whole new way of calculating the score
        // therefore I have invalidated past scores
        // let bonus = (diff < 10) ? Int((10.0/diff).rounded(.up)) : 0
        let bonus = calcBonus(diff)
        print("diff", diff)
        print("bonus", bonus)
        self.score += 1 + bonus
//        self.lsvc.scoreLabel?.text = String(self.score)
//        self.lsvc.scoreLabel?.textColor = .black
    }
}
