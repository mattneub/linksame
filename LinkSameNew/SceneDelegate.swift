
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    var rootCoordinator: any RootCoordinatorType = RootCoordinator()

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let scene = scene as? UIWindowScene else { return }
        // do not bootstrap any interface if we are unit testing
        unlessTesting {
            bootstrap(scene: scene)
        }
    }

    func bootstrap(scene: UIWindowScene) {
        let window = UIWindow(windowScene: scene)
        self.window = window
        rootCoordinator.createInitialInterface(window: window)
        window.makeKeyAndVisible()
    }
}

