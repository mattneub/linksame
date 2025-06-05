import Foundation
@testable import LinkSame
import Testing

@MainActor
struct HelpProcessorTests {
    let subject = HelpProcessor()
    let presenter = MockReceiverPresenter<Void, HelpState>()
    let coordinator = MockRootCoordinator()
    let mockBundle = MockBundle()
    let screen = MockScreen()

    init() {
        subject.presenter = presenter
        subject.coordinator = coordinator
        services.bundle = mockBundle
        services.screen = screen
    }

    @Test("receive dismiss: calls coordinator dismiss")
    func dismiss() async {
        await subject.receive(.dismiss)
        #expect(coordinator.methodsCalled.last == "dismiss()")
    }

    @Test("receive viewDidLoad: loads html file, performs substitutions on iPhone, presents result")
    func viewDidLoadPhone() async {
        screen.traitCollection = .init(userInterfaceIdiom: .phone)
        let bundle = Bundle(for: Dummy.self)
        let path = bundle.path(forResource: "test", ofType: "txt")
        mockBundle.pathToReturn = path
        await subject.receive(.viewDidLoad)
        #expect(mockBundle.methodsCalled.last == "path(forResource:ofType:)")
        #expect(mockBundle.name == "linkhelp")
        #expect(mockBundle.ext == "html")
        #expect(presenter.statesPresented.last?.content == "one 30 two 8\n")
    }

    @Test("receive viewDidLoad: loads html file, performs substitutions on iPad, presents result")
    func viewDidLoadPad() async {
        screen.traitCollection = .init(userInterfaceIdiom: .pad)
        let bundle = Bundle(for: Dummy.self)
        let path = bundle.path(forResource: "test", ofType: "txt")
        mockBundle.pathToReturn = path
        await subject.receive(.viewDidLoad)
        #expect(mockBundle.methodsCalled.last == "path(forResource:ofType:)")
        #expect(mockBundle.name == "linkhelp")
        #expect(mockBundle.ext == "html")
        #expect(presenter.statesPresented.last?.content == "one 5 two 12\n")
    }
}

final class Dummy {}
