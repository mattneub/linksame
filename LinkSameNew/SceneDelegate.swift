
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        self.window = self.window ?? UIWindow(windowScene: windowScene)
        self.window!.rootViewController = LinkSameViewController()
        self.window!.backgroundColor = .white
        self.window!.makeKeyAndVisible()
    }
}

