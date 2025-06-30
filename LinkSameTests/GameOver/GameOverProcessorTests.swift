import Foundation
@testable import LinkSame
import Testing

@MainActor
struct GameOverProcessorTests {
    let subject = GameOverProcessor()
    let presenter = MockReceiverPresenter<Void, GameOverState>()
    let coordinator = MockRootCoordinator()

    init() {
        subject.presenter = presenter
        subject.coordinator = coordinator
    }

    @Test("receive tapped: calls coordinator dismiss")
    func tapped() async {
        await subject.receive(.tapped)
        #expect(coordinator.methodsCalled == ["dismiss()"])
    }

    @Test("receive viewDidLoad: presents state")
    func viewDidLoad() async {
        subject.state = GameOverState(newHigh: true, score: 30, practice: false)
        #expect(presenter.statesPresented == [])
        await subject.receive(.viewDidLoad)
        #expect(presenter.statesPresented.first == GameOverState(newHigh: true, score: 30, practice: false))
    }
}
