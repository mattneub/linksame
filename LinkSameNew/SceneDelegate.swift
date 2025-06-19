
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

    func sceneDidBecomeActive(_ scene: UIScene) {
        services.lifetime.didBecomeActive()
    }

    func sceneWillResignActive(_ scene: UIScene) {
        services.lifetime.willResignActive()
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        services.lifetime.willEnterForeground()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Hide the board view from the app switcher screenshot.
        // I feel bad about this, but the problem is that by the time the processor gets the
        // message via the Lifetime object, it is too late to hide the board view! So I have to
        // bypass the whole module architecture and just reach in directly and hide it, kaboom.
        rootCoordinator.hideBoardView()
        services.lifetime.didEnterBackground()
    }

}

