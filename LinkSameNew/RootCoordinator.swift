import UIKit

@MainActor
protocol RootCoordinatorType {
    func createInitialInterface(window: UIWindow)
}

@MainActor
final class RootCoordinator: RootCoordinatorType {
    /// Reference to the root view controller of the app.
    weak var rootViewController: UIViewController?

    func createInitialInterface(window: UIWindow) {
        let viewController = LinkSameViewController()
        window.rootViewController = viewController
        self.rootViewController = viewController
        window.backgroundColor = .white
    }
}
