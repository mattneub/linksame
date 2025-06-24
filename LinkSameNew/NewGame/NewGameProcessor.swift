import Foundation

/// Processor that contains the logic for the module.
@MainActor
final class NewGameProcessor: Processor {

    /// Reference to our chief presenter. Set by the coordinator on module creation.
    weak var presenter: (any ReceiverPresenter<NewGameEffect, NewGameState>)?

    /// Reference to the delegate to whom we will report when the user taps a bar button item
    /// to dismiss us; set by the coordinator at module creation time.
    weak var dismissalDelegate: (any NewGamePopoverDismissalButtonDelegate)?

    /// State to be passed to the presenter for reflection in the interface.
    var state = NewGameState()

    func receive(_ action: NewGameAction) async {
        switch action {

        case .cancelNewGame:
            await dismissalDelegate?.cancelNewGame()

        case .initialInterfaceIsReady:
            let numberOfStages = services.persistence.loadInt(forKey: .lastStage)
            await presenter?.receive(.selectPickerRow(numberOfStages))
            await updateCheckmarks()

        case .startNewGame:
            await dismissalDelegate?.startNewGame()

        case .userSelectedPickerRow(let row):
            services.persistence.save(row, forKey: .lastStage)

        case .userSelectedTableRow(let indexPath):
            let (key, value): (DefaultKey, String) = switch indexPath.section {
            case 0: (.style, Styles.stylesInOrder[indexPath.row])
            case 1: (.size, Sizes.sizesInOrder[indexPath.row])
            default: fatalError("impossible")
            }
            services.persistence.save(value, forKey: key)
            await updateCheckmarks()

        case .viewDidLoad:
            state.tableViewSections = [
                .init(title: DefaultKey.style.rawValue, rows: Styles.stylesInOrder),
            ]
            if !onPhone {
                state.tableViewSections.append(
                    .init(title: DefaultKey.size.rawValue, rows: Sizes.sizesInOrder)
                )
            }
            await presenter?.present(state)
        }
    }

    /// Utility that updates our presenter with regard to which row of each section of the table view
    /// should receive the checkmark.
    func updateCheckmarks() async {
        /// Fetch the current value for each table view section category from defaults and match
        /// against the list for that category to get the row number.
        let checkmarkedRows = [
            Styles.stylesInOrder.firstIndex(of: services.persistence.loadString(forKey: .style)) ?? -1,
            Sizes.sizesInOrder.firstIndex(of: services.persistence.loadString(forKey: .size)) ?? -1
        ]
        /// Update the `checkmarkedRow` of each section in the state and present the state.
        state.tableViewSections = zip(checkmarkedRows, state.tableViewSections).map { checkmarkedRow, section in
            NewGameSection(title: section.title, rows: section.rows, checkmarkedRow: checkmarkedRow)
        }
        await presenter?.present(state)
    }
}
