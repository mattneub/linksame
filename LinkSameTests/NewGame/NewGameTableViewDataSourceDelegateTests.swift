import UIKit
@testable import LinkSame
import Testing
import WaitWhile

@MainActor
struct NewGameTableViewDataSourceDelegateTests {
    let subject = NewGameTableViewDataSourceDelegate()
    let processor = MockProcessor<NewGameAction, NewGameState, NewGameEffect>()

    init() {
        subject.processor = processor
    }

    @Test("registering a table view configures the table view")
    func register() {
        let tableView = UITableView()
        subject.register(tableView)
        #expect(tableView.dataSource === subject)
        #expect(tableView.delegate === subject)
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell")
        #expect(cell != nil)
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "Header")
        #expect(header != nil)
    }

    @Test("presenting state after registering a table view constructs the table view contents")
    func present() async {
        let tableView = UITableView()
        subject.register(tableView)
        let state = NewGameState(tableViewSections: [
            .init(title: "Hey", rows: ["Ho", "Ha"]),
            .init(title: "Yay", rows: ["Yo"]),
        ])
        await subject.present(state)
        #expect(tableView.numberOfSections == 2)
        #expect(tableView.numberOfRows(inSection: 0) == 2)
        #expect(tableView.numberOfRows(inSection: 1) == 1)
    }

    @Test("header contains label with tag 99 and given text")
    func header() async throws {
        let tableView = UITableView()
        makeWindow(view: tableView)
        subject.register(tableView)
        let state = NewGameState(tableViewSections: [
            .init(title: "Hey", rows: ["Ho", "Ha"]),
            .init(title: "Yay", rows: ["Yo"]),
        ])
        await subject.present(state)
        await #while(tableView.headerView(forSection: 0) == nil)
        let header = try #require(tableView.headerView(forSection: 0))
        let label = try #require(header.viewWithTag(99) as? UILabel)
        #expect(label.font == UIFont.systemFont(ofSize: 20, weight: .bold))
        #expect(label.text == "Hey")
        #expect(label.textColor == .label)
        #expect(label.translatesAutoresizingMaskIntoConstraints == false)
        #expect(header.backgroundConfiguration?.backgroundColor == .secondarySystemBackground)
        #expect(header.bounds.height == 30)
    }

    @Test("cell text label and accessory type are correct")
    func cell() async throws {
        let tableView = UITableView()
        makeWindow(view: tableView)
        subject.register(tableView)
        let state = NewGameState(tableViewSections: [
            .init(title: "Hey", rows: ["Ho", "Ha"], checkmarkedRow: 1),
            .init(title: "Yay", rows: ["Yo"]),
        ])
        await subject.present(state)
        await #while(tableView.headerView(forSection: 0) == nil)
        do {
            let cell = try #require(tableView.cellForRow(at: .init(row: 0, section: 0)))
            #expect(cell.textLabel?.text == "Ho")
            #expect(cell.textLabel?.font == UIFont.systemFont(ofSize: 17, weight: .regular))
            #expect(cell.accessoryType == .none)
        }
        do {
            let cell = try #require(tableView.cellForRow(at: .init(row: 1, section: 0)))
            #expect(cell.textLabel?.text == "Ha")
            #expect(cell.textLabel?.font == UIFont.systemFont(ofSize: 17, weight: .regular))
            #expect(cell.accessoryType == .checkmark)
        }
    }

    @Test("selecting a cell sends the userSelectedTableRow action")
    func select() async {
        let tableView = UITableView()
        subject.tableView(tableView, didSelectRowAt: .init(row: 1, section: 0))
        await #while(processor.thingsReceived.count == 0)
        #expect(processor.thingsReceived.last == .userSelectedTableRow(.init(row: 1, section: 0)))
    }
}
