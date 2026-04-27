import UIKit
import Swift

/// The chief presenter.
final class NewGameViewController: UIViewController, ReceiverPresenter {
    /// Object that serves as data source and delegate for our picker view.
    /// Should be a constant but needs to be a `var` for testing.
    var pickerViewDataSourceDelegate: any NewGamePickerViewDataSourceDelegateType = NewGamePickerViewDataSourceDelegate()

    /// Object that serves as data source and delegate for our table view.
    /// Should be a constant but needs to be a `var` for testing.
    var tableViewDataSourceDelegate: any NewGameTableViewDataSourceDelegateType = NewGameTableViewDataSourceDelegate()

    /// Retained instance of popover presentation delegate, set by the coordinator on creation.
    var popoverPresentationDelegate: (any UIPopoverPresentationControllerDelegate)?

    /// Table view that will give the user a choice of styles (and, on iPad, sizes).
    lazy var tableView = UITableView(frame: .zero, style: .plain).applying {
        let tableHeight: CGFloat = (onPhone ? 120 : 300)
        // This height is only a temporary guess; see `updateConstraints` for the real answer.
        $0.frame = CGRect(x: 0, y: 0, width: 320, height: tableHeight)
        $0.backgroundColor = .secondarySystemBackground
        tableViewDataSourceDelegate.register($0)
        $0.bounces = false
        $0.isScrollEnabled = false
        $0.translatesAutoresizingMaskIntoConstraints = false
        // border, seems more crisp somehow
        $0.layer.borderWidth = 1
        $0.layer.borderColor = UIColor.lightGray.cgColor
        $0.sectionHeaderTopPadding = 6
        $0.backgroundView = UIView().applying {
            $0.backgroundColor = .systemBackground
        }
    }

    /// Picker view that will give the user a choice of number of stages.
    lazy var pickerView = UIPickerView().applying {
        $0.backgroundColor = .systemBackground
        $0.translatesAutoresizingMaskIntoConstraints = false
        pickerViewDataSourceDelegate.register($0)
    }

    /// Reference to the processor, set by the coordinator at module creation time.
    /// We pass this along to the data sources, which are sub-presenters.
    weak var processor: (any Processor<NewGameAction, NewGameState, NewGameEffect>)? {
        didSet {
            pickerViewDataSourceDelegate.processor = processor
            tableViewDataSourceDelegate.processor = processor
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        let cancelBarButtonItem = MyBarButtonItem(systemItem: .cancel) { [weak self] _ in
            Task.immediate {
                await self?.processor?.receive(.cancelNewGame)
            }
        }
        navigationItem.rightBarButtonItem = cancelBarButtonItem
        let doneBarButtonItem = MyBarButtonItem(systemItem: .done) { [weak self] _ in
            Task.immediate {
                await self?.processor?.receive(.startNewGame)
            }
        }
        navigationItem.leftBarButtonItem = doneBarButtonItem

        // Set up interface; we do not yet know what height
        // to give the table view, or our own preferred content height.

        view.addSubview(tableView)
        view.addSubview(pickerView)

        // no table height constraint yet
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: tableView.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: tableView.trailingAnchor),
            view.leadingAnchor.constraint(equalTo: pickerView.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: pickerView.trailingAnchor),
            view.safeAreaLayoutGuide.topAnchor.constraint(equalTo: tableView.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: pickerView.topAnchor),
        ])

        Task.immediate {
            await processor?.receive(.initialInterfaceIsReady)
        }
    }

    /// One-time flag so that we only give the table view a height constraint once.
    var didProvideTableViewHeightConstraint = false

    /// Determine the actual height of the table view, and set it. The timing here is rather tricky;
    /// we must wait until the table view has its content.
    override func updateViewConstraints() {
        if !didProvideTableViewHeightConstraint && tableView.numberOfSections > 0 {
            var proposedHeight: CGFloat = 0
            for section in 0..<tableView.numberOfSections {
                proposedHeight += tableView.rect(forSection: section).height
            }
            if proposedHeight > 0 {
                NSLayoutConstraint.activate([
                    tableView.heightAnchor.constraint(equalToConstant: proposedHeight),
                ])
                didProvideTableViewHeightConstraint = true
            }
        }
        super.updateViewConstraints()
    }

    /// Determine our overall view height, based on the height of the table view and the
    /// height of the picker view. This applies only to the popover on iPad;
    /// on the iPhone we are fullscreen and size is determined by a presentation controller.
    override func viewDidLayoutSubviews() {
        let totalHeight = self.tableView.bounds.height + self.pickerView.bounds.height
        self.preferredContentSize = CGSize(width: 320, height: totalHeight)
    }

    /// We have no state to present, of ourselves; rather, we pass the state along to the two
    /// sub-presenters for them to deal with.
    func present(_ state: NewGameState) async {
        await tableViewDataSourceDelegate.present(state)
        await pickerViewDataSourceDelegate.present(state)
    }

    func receive(_ effect: NewGameEffect) async {
        switch effect {
        case .selectPickerRow(let row):
            pickerView.selectRow(row, inComponent: 0, animated: false)
        }
    }
}

extension NewGameViewController: UIViewControllerTransitioningDelegate {
    func presentationController(
        forPresented presented: UIViewController,
        presenting: UIViewController?,
        source: UIViewController
    ) -> UIPresentationController? {
        NewGamePresentationController(presentedViewController: presented, presenting: presenting)
    }
}

/// Protocol describing a delegate to whom we can report that the user has tapped a bar button
/// item and wants to start a new game or simply cancel. Both are ways of dismissing us.
protocol NewGamePopoverDismissalButtonDelegate: AnyObject {
    func cancelNewGame() async
    func startNewGame() async
}

