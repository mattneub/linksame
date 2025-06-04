import UIKit

/// Protocol that expresses the public face of our class, so we can mock it for testing.
@MainActor
protocol NewGameTableViewDataSourceDelegateType: NSObject, UITableViewDataSource, UITableViewDelegate {
    var processor: (any Processor<NewGameAction, NewGameState, NewGameEffect>)? { get set }
    func register(_ tableView: UITableView)
    func present(_ state: NewGameState) async
}

/// Sub-presenter that populates the table view and responds to the user's action there.
@MainActor
final class NewGameTableViewDataSourceDelegate: NSObject, NewGameTableViewDataSourceDelegateType {

    /// Constants used for registering and dequeuing cells and headers.
    private let cellid = "Cell"
    private let headerid = "Header"
    private let headertag = 99

    /// Reference to the processor, set by the view controller.
    weak var processor: (any Processor<NewGameAction, NewGameState, NewGameEffect>)?

    /// Reference to the table view, set in `register`, so that we can tell it to reload as needed.
    weak var tableView: UITableView?

    /// The actual data for the table, set in `present`.
    var tableViewSections = [NewGameSection]()

    /// Register the registration constants with the given table view, keep a reference to the
    /// table view, set ourself as the table view's data source and delegate.
    /// - Parameter tableView: The table view.
    func register(_ tableView: UITableView) {
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellid)
        tableView.register(UITableViewHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: headerid)
        self.tableView = tableView
        tableView.dataSource = self
        tableView.delegate = self
    }

    func present(_ state: NewGameState) async {
        tableViewSections = state.tableViewSections
        tableView?.reloadData()
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        tableViewSections.count
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: headerid) else {
            return nil
        }
        if headerView.viewWithTag(headertag) == nil {
            let label = UILabel().applying {
                $0.tag = headertag
                $0.font = UIFont.systemFont(ofSize: 20, weight: .bold)
                $0.translatesAutoresizingMaskIntoConstraints = false
            }
            headerView.contentView.addSubview(label)
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: headerView.contentView.topAnchor),
                label.bottomAnchor.constraint(equalTo: headerView.contentView.bottomAnchor),
                label.leadingAnchor.constraint(equalTo: headerView.contentView.layoutMarginsGuide.leadingAnchor)
            ])
        }
        guard let label = headerView.viewWithTag(headertag) as? UILabel else {
            return nil
        }
        label.text = tableViewSections[section].title
        var background = UIBackgroundConfiguration.listHeader()
        background.backgroundColor = .secondarySystemBackground
        headerView.backgroundConfiguration = background
        return headerView
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 30
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tableViewSections[section].rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellid, for:indexPath)

        cell.textLabel?.text = tableViewSections[indexPath.section].rows[indexPath.row]
        cell.textLabel?.font = UIFont.systemFont(ofSize: 17, weight: .regular)

        if tableViewSections[indexPath.section].checkmarkedRow == indexPath.row {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        Task {
            await processor?.receive(.userSelectedTableRow(indexPath))
        }
    }
}
