import Foundation

/// Effects sent by the processor to its chief presenter.
enum NewGameEffect: Equatable {
    case selectPickerRow(Int)
}
