import Foundation

/// Messages from the presenter(s) to the processor.
enum NewGameAction: Equatable {
    case cancelNewGame
    case initialInterfaceIsReady // Later than viewDidLoad; interface is populated.
    case startNewGame
    case userSelectedPickerRow(Int)
    case userSelectedTableRow(IndexPath)
    case viewDidLoad // Earliest action: interface not yet populated.
}
