import UIKit

/// View controller that displays the game over view.
final class GameOverViewController: UIViewController, ReceiverPresenter {
    weak var processor: (any Processor<GameOverAction, GameOverState, Void>)?

    /// Label saying what the score of the just ended game was.
    lazy var scoreLabel = UILabel().applying {
        $0.numberOfLines = 0
        $0.textAlignment = .center
        $0.textColor = .black
        $0.font = UIFont(name: "Arial Rounded MT Bold", size: 26)
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    /// Label saying whether the score represented a new high score.
    lazy var newHighLabel = UILabel().applying {
        $0.numberOfLines = 0
        $0.textAlignment = .center
        $0.textColor = .black
        $0.font = UIFont(name: "Arial Rounded MT Bold", size: 26)
        $0.text = "That is a new high score for this level!"
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    /// Visible background behind the labels.
    lazy var backgroundView = UIView().applying {
        $0.backgroundColor = .systemYellow
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.layer.cornerRadius = 6
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setUp()
        Task {
            await processor?.receive(.viewDidLoad)
        }
    }

    /// Reference to constraints so that we can change their `constant` values in `present`.
    var newHighLabelTop: NSLayoutConstraint?
    var newHighLabelBottom: NSLayoutConstraint?

    /// Utility called once by `viewDidLoad` to configure subviews.
    func setUp() {
        view.addSubview(backgroundView)
        backgroundView.addSubview(scoreLabel)
        backgroundView.addSubview(newHighLabel)
        newHighLabelTop = newHighLabel.topAnchor.constraint(
            equalTo: scoreLabel.bottomAnchor, constant: 40
        )
        newHighLabelTop?.isActive = true
        newHighLabelBottom = newHighLabel.bottomAnchor.constraint(
            equalTo: backgroundView.bottomAnchor, constant: -40
        )
        newHighLabelBottom?.isActive = true
        NSLayoutConstraint.activate([
            backgroundView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            backgroundView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            backgroundView.widthAnchor.constraint(equalTo: view.widthAnchor),
            scoreLabel.topAnchor.constraint(equalTo: backgroundView.topAnchor, constant: 40),
            scoreLabel.widthAnchor.constraint(equalToConstant: 300),
            scoreLabel.centerXAnchor.constraint(equalTo: backgroundView.centerXAnchor),
            newHighLabel.widthAnchor.constraint(equalToConstant: 300),
            newHighLabel.centerXAnchor.constraint(equalTo: backgroundView.centerXAnchor),
        ])
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(userTapped))
        view.addGestureRecognizer(tapGestureRecognizer)
    }

    func present(_ state: GameOverState) async {
        scoreLabel.text = if !state.practice {
            "You have finished the game with a score of \(state.score)."
        } else {
            "End of practice game."
        }
        if state.newHigh && !state.practice {
            newHighLabel.isHidden = false
            newHighLabelTop?.constant = 40
            newHighLabelBottom?.constant = -40
        } else {
            newHighLabel.isHidden = true
            newHighLabelTop?.constant = 0
            newHighLabelBottom?.constant = 0
        }
    }

    /// Action of the tap gesture recognizer.
    @objc func userTapped() {
        Task {
            await processor?.receive(.tapped)
        }
    }
}

/// Provider of the presentation animation transitioner (self) and the presentation controller.
extension GameOverViewController: UIViewControllerTransitioningDelegate {
    func animationController(
        forPresented presented: UIViewController,
        presenting: UIViewController,
        source: UIViewController
    ) -> (any UIViewControllerAnimatedTransitioning)? {
        return self
    }
    func animationController(
        forDismissed dismissed: UIViewController
    ) -> (any UIViewControllerAnimatedTransitioning)? {
        return self
    }
    func presentationController(
        forPresented presented: UIViewController,
        presenting: UIViewController?,
        source: UIViewController
    ) -> UIPresentationController? {
        GameOverPresentationController(presentedViewController: presented, presenting: presenting)
    }
}

/// Presentation animation transitioner. We fade in and grow on presentation, and fade out on dismissal.
extension GameOverViewController: UIViewControllerAnimatedTransitioning {
    func transitionDuration(
        using transitionContext: (any UIViewControllerContextTransitioning)?
    ) -> TimeInterval {
        return 0.4
    }
    func animateTransition(using context: any UIViewControllerContextTransitioning) {
        let fromView = context.view(forKey: .from)
        let toView = context.view(forKey: .to)
        if let view = toView { // presenting
            if let viewController = context.viewController(forKey: .to) {
                view.frame = context.finalFrame(for: viewController)
            }
            view.alpha = 0
            view.transform = .init(scaleX: 0, y: 0)
            context.containerView.addSubview(view)
            UIView.animate(withDuration: 0.4) {
                view.alpha = 1
                view.transform = .identity
            } completion: { _ in
                context.completeTransition(true)
            }
        } else if let view = fromView { // dismissing
            UIView.animate(withDuration: 0.4) {
                view.alpha = 0
            } completion: { _ in
                view.removeFromSuperview()
                context.completeTransition(true)
            }
        }
    }
}
