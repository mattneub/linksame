import UIKit

/// Protocol that expresses the public face of our class, so we can mock it for testing.
@MainActor
protocol NewGamePickerViewDataSourceDelegateType: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
    var processor: (any Processor<NewGameAction, NewGameState, NewGameEffect>)? { get set }
    func register(_ pickerView: UIPickerView)
    func present(_ state: NewGameState) async
}

/// Sub-presenter that populates the picker view and responds to the user's action there.
@MainActor
final class NewGamePickerViewDataSourceDelegate: NSObject, NewGamePickerViewDataSourceDelegateType {
    /// Reference to the processor, set by the view controller.
    weak var processor: (any Processor<NewGameAction, NewGameState, NewGameEffect>)?

    /// Reference to the picker view, set in `register`, so that we can tell it to reload as needed.
    weak var pickerView: UIPickerView?

    /// The actual data for the picker, set in `present`. Here, the only thing it is appropriate
    /// for the presenter not to know a priori is how many rows to contain (i.e. how many stages,
    /// maximum, a game can consist of).
    var numberOfRows = 0

    /// Register the picker with the given table view.
    /// - Parameter pickerView: The picker view.
    func register(_ pickerView: UIPickerView) {
        self.pickerView = pickerView
        pickerView.dataSource = self
        pickerView.delegate = self
    }

    func present(_ state: NewGameState) async {
        if self.numberOfRows != state.maximumStages {
            self.numberOfRows = state.maximumStages
            pickerView?.reloadAllComponents()
        }
    }

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return numberOfRows
    }

    func pickerView(
        _ pickerView: UIPickerView,
        attributedTitleForRow row: Int,
        forComponent component: Int
    ) -> NSAttributedString? {
        var attributedString = AttributedString(localized: "^[\(row + 1) \("Stage")](inflect: true)")
        attributedString.uiKit.foregroundColor = .label
        return NSAttributedString(attributedString)
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        Task {
            await processor?.receive(.userSelectedPickerRow(row))
        }
    }

    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        return 35
    }

}
