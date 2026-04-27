import UIKit
@testable import LinkSame
import Testing
import WaitWhile

struct NewGameViewControllerTests {
    let subject = NewGameViewController()
    fileprivate let mockPickerDelegate = MockPickerDelegate()
    fileprivate let mockTableDelegate = MockTableDelegate()
    let processor = MockProcessor<NewGameAction, NewGameState, NewGameEffect>()
    let mockScreen = MockScreen()

    init() {
        subject.pickerViewDataSourceDelegate = mockPickerDelegate
        subject.tableViewDataSourceDelegate = mockTableDelegate
        subject.processor = processor
        services.screen = mockScreen
        mockScreen.traitCollection = UITraitCollection(userInterfaceIdiom: .phone)
    }

    @Test("table view is correctly initialized")
    func tableView() throws {
        let tableView = subject.tableView
        #expect(tableView.frame == CGRect(x: 0, y: 0, width: 320, height: 120))
        #expect(tableView.backgroundColor == .secondarySystemBackground)
        #expect(mockTableDelegate.methodsCalled.first == "register(_:)")
        #expect(tableView.bounces == false)
        #expect(tableView.isScrollEnabled == false)
        #expect(tableView.translatesAutoresizingMaskIntoConstraints == false)
        #expect(tableView.layer.borderWidth == 1)
        #expect(tableView.layer.borderColor == UIColor.lightGray.cgColor)
        #expect(tableView.sectionHeaderTopPadding == 6)
        let background = try #require(tableView.backgroundView)
        #expect(background.backgroundColor == .systemBackground)
    }

    @Test("table view is correctly initialized on iPad")
    func tableViewPad() throws {
        mockScreen.traitCollection = .init(userInterfaceIdiom: .pad)
        let tableView = subject.tableView
        #expect(tableView.frame == CGRect(x: 0, y: 0, width: 320, height: 300))
    }

    @Test("picker view is correctly initialized")
    func pickerView() {
        let pickerView = subject.pickerView
        #expect(pickerView.backgroundColor == .systemBackground)
        #expect(pickerView.translatesAutoresizingMaskIntoConstraints == false)
        #expect(mockPickerDelegate.methodsCalled.first == "register(_:)")
    }

    @Test("setting the processor sets the delegates' processor")
    func processorSet() {
        subject.processor = nil
        #expect(mockPickerDelegate.processor == nil)
        #expect(mockTableDelegate.processor == nil)
        subject.processor = processor
        #expect(mockPickerDelegate.processor === processor)
        #expect(mockTableDelegate.processor === processor)
    }

    @Test("viewDidLoad: sets background color, configures bar button items")
    func viewDidLoad() throws {
        subject.loadViewIfNeeded()
        #expect(subject.view.backgroundColor == .systemBackground)
        let cancelItem = try #require(subject.navigationItem.rightBarButtonItem as? MyBarButtonItem)
        #expect(cancelItem.systemItem == .cancel)
        cancelItem.actionHandler?(UIAction { _ in })
        #expect(processor.thingsReceived.last == .cancelNewGame)
        processor.thingsReceived = []
        let doneItem = try #require(subject.navigationItem.leftBarButtonItem as? MyBarButtonItem)
        #expect(doneItem.systemItem == .done)
        doneItem.actionHandler?(UIAction { _ in })
        #expect(processor.thingsReceived.last == .startNewGame)
    }

    @Test("viewDidLoad: sets up interface, up to a point; sends .initialInterfaceIsReady")
    func viewDidLoadInterface() async throws {
        subject.loadViewIfNeeded()
        await #while(subject.view.subviews.count == 0)
        #expect(subject.tableView.isDescendant(of: subject.view))
        #expect(subject.pickerView.isDescendant(of: subject.view))
        #expect(subject.tableView.constraints.isEmpty)
        #expect(processor.thingsReceived.last == .initialInterfaceIsReady)
    }

    @Test("updateViewConstraints: if table view has sections with row heights, gives table view a height constraint")
    func updateViewConstraints() async throws {
        makeWindow(viewController: subject)
        subject.loadViewIfNeeded()
        await #while(subject.view.subviews.count == 0)
        subject.tableView.dataSource = mockTableDelegate
        subject.tableView.delegate = mockTableDelegate
        subject.view.setNeedsUpdateConstraints()
        try? await Task.sleep(for: .seconds(0.1))
        #expect(subject.tableView.constraints.count == 0)
        // ok, now let's construct the table view
        subject.tableView.reloadData()
        subject.view.setNeedsUpdateConstraints()
        try? await Task.sleep(for: .seconds(0.1))
        #expect(subject.tableView.constraints.count == 0)
        // nope, still no sections; ok, watch _this_ little move
        mockTableDelegate.numberOfSections = 1
        subject.tableView.rowHeight = 30
        subject.tableView.reloadData()
        subject.view.setNeedsUpdateConstraints()
        try? await Task.sleep(for: .seconds(0.1))
        let constraint = try #require(subject.tableView.constraints.first(where: {
            $0.firstAttribute == .height
        }))
        #expect(constraint.constant == 90)
    }

    @Test("viewDidLayoutSubviews: sets preferred content size to sum of heights of table and picker")
    func viewDidLayoutSubviews() {
        subject.tableView.bounds = CGRect(x: 0, y: 0, width: 320, height: 500)
        subject.pickerView.bounds = CGRect(x: 0, y: 0, width: 320, height: 500)
        subject.viewDidLayoutSubviews()
        #expect(subject.preferredContentSize == .init(width: 320, height: 1000))
    }

    @Test("receive .selectPickerRow: selects that row of the picker")
    func selectPickerRow() async {
        subject.pickerView.dataSource = mockPickerDelegate
        subject.pickerView.delegate = mockPickerDelegate
        await subject.receive(.selectPickerRow(3))
        #expect(subject.pickerView.selectedRow(inComponent: 0) == 3)
    }
}

fileprivate final class MockPickerDelegate: NSObject, NewGamePickerViewDataSourceDelegateType {
    var methodsCalled = [String]()
    var state: NewGameState?

    var processor: (any Processor<NewGameAction, NewGameState, NewGameEffect>)?
    
    func register(_ pickerView: UIPickerView) {
        methodsCalled.append(#function)
    }
    
    func present(_ state: NewGameState) async {
        methodsCalled.append(#function)
        self.state = state
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return 10
    }
}
fileprivate final class MockTableDelegate: NSObject, NewGameTableViewDataSourceDelegateType {
    var methodsCalled = [String]()
    var state: NewGameState?
    var numberOfSections = 0

    var processor: (any Processor<NewGameAction, NewGameState, NewGameEffect>)?
    
    func register(_ tableView: UITableView) {
        methodsCalled.append(#function)
    }
    
    func present(_ state: NewGameState) async {
        methodsCalled.append(#function)
        self.state = state
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return numberOfSections
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 3
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        return cell
    }
}
