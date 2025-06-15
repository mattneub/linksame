@testable import LinkSame
import Testing
import UIKit

@MainActor
struct SceneDelegateTests {
    @Test("bootstrap: tells the root coordinator to create the interface")
    func bootstrap() async throws {
        let scene = try #require(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let subject = SceneDelegate()
        let mockRootCoordinator = MockRootCoordinator()
        subject.rootCoordinator = mockRootCoordinator
        subject.bootstrap(scene: scene)
        let window = try #require(subject.window)
        #expect(window.isKeyWindow)
        #expect(mockRootCoordinator.methodsCalled == ["createInitialInterface(window:)"])
        #expect(mockRootCoordinator.window === window)
    }

    @Test("sceneDidBecomeActive: calls lifetime didBecomeActive")
    func didBecomeActive() throws {
        let lifetime = MockLifetime()
        services.lifetime = lifetime
        let subject = SceneDelegate()
        let scene = try #require(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        subject.sceneDidBecomeActive(scene)
        #expect(lifetime.methodsCalled == ["didBecomeActive()"])
    }

    @Test("sceneDidEnterBackground: calls lifetime didEnterBackground")
    func didEnterBackground() throws {
        let lifetime = MockLifetime()
        services.lifetime = lifetime
        let subject = SceneDelegate()
        let scene = try #require(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        subject.sceneDidEnterBackground(scene)
        #expect(lifetime.methodsCalled == ["didEnterBackground()"])
    }

    @Test("sceneWillResignActive: calls lifetime willResignActive")
    func willResignActive() throws {
        let lifetime = MockLifetime()
        services.lifetime = lifetime
        let subject = SceneDelegate()
        let scene = try #require(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        subject.sceneWillResignActive(scene)
        #expect(lifetime.methodsCalled == ["willResignActive()"])
    }
}
