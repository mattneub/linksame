
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

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
        self.window = self.window ?? UIWindow(windowScene: scene)
        self.window!.rootViewController = LinkSameViewController()
        self.window!.backgroundColor = .white
        self.window!.makeKeyAndVisible()
    }
}

