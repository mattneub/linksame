import Foundation
@testable import LinkSame
import Testing
import WaitWhile

@MainActor
struct NewGameProcessorTests {
    let subject = NewGameProcessor()
    let presenter = MockReceiverPresenter<NewGameEffect, NewGameState>()
    let persistence = MockPersistence()
    let screen = MockScreen()
    let dismissalDelegate = MockDismissalDelegate()

    init() {
        subject.presenter = presenter
        subject.dismissalDelegate = dismissalDelegate
        services.persistence = persistence
        services.screen = screen
    }

    @Test("receive initialInterfaceIsReady: fetches last stage from persistence, sends .selectPickerRow")
    func initialInterfaceIsReady() async {
        persistence.valuePairs = [(.lastStage, 5)]
        await subject.receive(.initialInterfaceIsReady)
        #expect(persistence.methodsCalled.first == "loadInt(forKey:)")
        #expect(persistence.loads.first?.1 == .lastStage)
        #expect(presenter.thingsReceived.first == .selectPickerRow(5))
    }

    @Test("receive initialInterfaceIsReady: updates checkmark rows in state, presents state")
    func initialInterfaceIsReadyCheckmarks() async throws {
        persistence.valuePairs = [(.lastStage, 5), (.style, "Animals"), (.size, "Hard")]
        subject.state.tableViewSections = [.init(title: "hey", rows: []), .init(title: "ho", rows: [])]
        await subject.receive(.initialInterfaceIsReady)
        #expect(persistence.loads[1] == ("loadString(forKey:)", .style))
        #expect(persistence.loads[2] == ("loadString(forKey:)", .size))
        let state = try #require(presenter.statesPresented.last)
        #expect(state.tableViewSections[0].checkmarkedRow == 0)
        #expect(state.tableViewSections[1].checkmarkedRow == 2)
    }

    @Test("receive initialInterfaceIsReady: updates checkmark row if there is just one section")
    func initialInterfaceIsReadyCheckmarksOneRow() async throws {
        persistence.valuePairs = [(.lastStage, 5), (.style, "Animals"), (.size, "Hard")]
        subject.state.tableViewSections = [.init(title: "hey", rows: [])]
        await subject.receive(.initialInterfaceIsReady)
        #expect(persistence.loads[1] == ("loadString(forKey:)", .style))
        #expect(persistence.loads[2] == ("loadString(forKey:)", .size))
        let state = try #require(presenter.statesPresented.last)
        #expect(state.tableViewSections[0].checkmarkedRow == 0)
    }

    @Test("receive userSelectedPickerRow: saves row into persistence")
    func userSelectedPickerRow() async throws {
        await subject.receive(.userSelectedPickerRow(5))
        #expect(persistence.methodsCalled.first == "save(_:forKey:)")
        #expect(persistence.saveKeys.first == .lastStage)
        #expect(persistence.savedValues.first as? Int == 5)
    }

    @Test("receive userSelectedTableRow: saves correct value into persistence under correct key")
    func userSelectedTableRow() async throws {
        do {
            await subject.receive(.userSelectedTableRow(.init(row: 0, section: 0)))
            #expect(persistence.methodsCalled.first == "save(_:forKey:)")
            #expect(persistence.savedValues.first as? String == "Animals")
            #expect(persistence.saveKeys.first == .style)
        }
        persistence.savedValues = []
        persistence.saveKeys = []
        do {
            await subject.receive(.userSelectedTableRow(.init(row: 1, section: 0)))
            #expect(persistence.methodsCalled.first == "save(_:forKey:)")
            #expect(persistence.savedValues.first as? String == "Snacks")
            #expect(persistence.saveKeys.first == .style)
        }
        persistence.savedValues = []
        persistence.saveKeys = []
        do {
            await subject.receive(.userSelectedTableRow(.init(row: 0, section: 1)))
            #expect(persistence.methodsCalled.first == "save(_:forKey:)")
            #expect(persistence.savedValues.first as? String == "Easy")
            #expect(persistence.saveKeys.first == .size)
        }
        persistence.savedValues = []
        persistence.saveKeys = []
        do {
            await subject.receive(.userSelectedTableRow(.init(row: 1, section: 1)))
            #expect(persistence.methodsCalled.first == "save(_:forKey:)")
            #expect(persistence.savedValues.first as? String == "Normal")
            #expect(persistence.saveKeys.first == .size)
        }
        persistence.savedValues = []
        persistence.saveKeys = []
        do {
            await subject.receive(.userSelectedTableRow(.init(row: 2, section: 1)))
            #expect(persistence.methodsCalled.first == "save(_:forKey:)")
            #expect(persistence.savedValues.first as? String == "Hard")
            #expect(persistence.saveKeys.first == .size)
        }
    }

    @Test("receive userSelectedTableRow: updates checkmarks in state, presents state")
    func userSelectedTableRowCheckmarks() async throws {
        persistence.valuePairs = [(.lastStage, 5), (.style, "Animals"), (.size, "Hard")]
        subject.state.tableViewSections = [.init(title: "hey", rows: []), .init(title: "ho", rows: [])]
        await subject.receive(.userSelectedTableRow(.init(row: 0, section: 0)))
        #expect(persistence.loads[0] == ("loadString(forKey:)", .style))
        #expect(persistence.loads[1] == ("loadString(forKey:)", .size))
        let state = try #require(presenter.statesPresented.last)
        #expect(state.tableViewSections[0].checkmarkedRow == 0)
        #expect(state.tableViewSections[1].checkmarkedRow == 2)
    }

    @Test("receive viewDidLoad: sets the state's table sections based on the device type")
    func viewDidLoad() async throws {
        screen.traitCollection = .init(userInterfaceIdiom: .phone)
        await subject.receive(.viewDidLoad)
        var state = try #require(presenter.statesPresented.last)
        #expect(state.tableViewSections.count == 1)
        #expect(state.tableViewSections[0].title == "Style")
        #expect(state.tableViewSections[0].rows == ["Animals", "Snacks"])
        screen.traitCollection = .init(userInterfaceIdiom: .pad)
        await subject.receive(.viewDidLoad)
        state = try #require(presenter.statesPresented.last)
        #expect(state.tableViewSections.count == 2)
        #expect(state.tableViewSections[0].title == "Style")
        #expect(state.tableViewSections[0].rows == ["Animals", "Snacks"])
        #expect(state.tableViewSections[1].title == "Size")
        #expect(state.tableViewSections[1].rows == ["Easy", "Normal", "Hard"])
        screen.traitCollection = .init(userInterfaceIdiom: .phone)
    }
}
