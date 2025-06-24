import UIKit
@testable import LinkSame
import Testing
import WaitWhile

@MainActor
struct NewGameViewControllerTests {
    let subject = NewGameViewController()
    fileprivate let mockPickerDelegate = MockPickerDelegate()
    fileprivate let mockTableDelegate = MockTableDelegate()
    let processor = MockProcessor<NewGameAction, NewGameState, NewGameEffect>()

    init() {
        subject.pickerViewDataSourceDelegate = mockPickerDelegate
        subject.tableViewDataSourceDelegate = mockTableDelegate
        subject.processor = processor
    }

    @Test("table view is correctly initialized")
    func tableView() {
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

    @Test("initialization: sets extended edges to none")
    func initialization() {
        #expect(subject.edgesForExtendedLayout == [])
    }

    @Test("viewDidLoad: sets background color, configures bar button items, sends .viewDidLoad action")
    func viewDidLoad() async throws {
        subject.loadViewIfNeeded()
        #expect(subject.view.backgroundColor == .systemBackground)
        await #while(processor.thingsReceived.isEmpty)
        #expect(processor.thingsReceived.first == .viewDidLoad)
        processor.thingsReceived = []
        let cancelItem = try #require(subject.navigationItem.rightBarButtonItem as? MyBarButtonItem)
        cancelItem.actionHandler?(UIAction { _ in })
        await #while(processor.thingsReceived.isEmpty)
        #expect(processor.thingsReceived.last == .cancelNewGame)
        processor.thingsReceived = []
        let doneItem = try #require(subject.navigationItem.leftBarButtonItem as? MyBarButtonItem)
        doneItem.actionHandler?(UIAction { _ in })
        await #while(processor.thingsReceived.isEmpty)
        #expect(processor.thingsReceived.last == .startNewGame)
    }

    @Test("viewDidLoad: sets up interface, up to a point; sends .initialInterfaceIsReady")
    func viewDidLoadInterface() async throws {
        subject.loadViewIfNeeded()
        await #while(subject.view.subviews.count == 0)
        #expect(subject.tableView.isDescendant(of: subject.view))
        #expect(subject.pickerView.isDescendant(of: subject.view))
        let allConstraints = subject.view.constraints
        #expect(allConstraints.count == 6)
        // the compiler is really slow if you don't do this
        let leading = NSLayoutConstraint.Attribute.leading
        let trailing = NSLayoutConstraint.Attribute.trailing
        let top = NSLayoutConstraint.Attribute.top
        let bottom = NSLayoutConstraint.Attribute.bottom
        // okay, now we're ready
        #expect(allConstraints.contains(where: {
            $0.firstItem === subject.view && $0.secondItem === subject.tableView &&
            $0.firstAttribute == leading && $0.secondAttribute == leading
        }))
        #expect(allConstraints.contains(where: {
            $0.firstItem === subject.view && $0.secondItem === subject.tableView &&
            $0.firstAttribute == trailing && $0.secondAttribute == trailing
        }))
        #expect(allConstraints.contains(where: {
            $0.firstItem === subject.view && $0.secondItem === subject.pickerView &&
            $0.firstAttribute == leading && $0.secondAttribute == leading
        }))
        #expect(allConstraints.contains(where: {
            $0.firstItem === subject.view && $0.secondItem === subject.pickerView &&
            $0.firstAttribute == trailing && $0.secondAttribute == trailing
        }))
        #expect(allConstraints.contains(where: {
            $0.firstItem === subject.view && $0.secondItem === subject.tableView &&
            $0.firstAttribute == top && $0.secondAttribute == top
        }))
        #expect(allConstraints.contains(where: {
            $0.firstItem === subject.tableView && $0.secondItem === subject.pickerView &&
            $0.firstAttribute == bottom && $0.secondAttribute == top
        }))
        await #while(processor.thingsReceived.last != .initialInterfaceIsReady)
        #expect(processor.thingsReceived.last == .initialInterfaceIsReady)
    }

    @Test("updateViewConstraints: if table view has sections, gives table view a height constraint")
    func updateViewConstraints() async {
        makeWindow(viewController: subject)
        subject.loadViewIfNeeded()
        await #while(subject.view.subviews.count == 0)
        subject.view.setNeedsUpdateConstraints()
        #expect(subject.tableView.constraints.count == 0)
        // ok, now let's construct the table view
        subject.tableView.reloadData()
        subject.view.setNeedsUpdateConstraints()
        #expect(subject.tableView.constraints.count == 0)
        // nope, still no sections; ok, watch _this_ little move
        mockTableDelegate.numberOfSections = 1
        subject.tableView.reloadData()
        await #while(subject.tableView.constraints.count == 0)
        #expect(subject.tableView.constraints.count == 1)
        let height = NSLayoutConstraint.Attribute.height
        #expect(subject.tableView.constraints.first?.firstAttribute == height)
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

@MainActor
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
@MainActor
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
        return UITableViewCell()
    }
}
