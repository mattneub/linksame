import Foundation

/// Messages from the presenter(s) to the processor.
enum NewGameAction: Equatable {
    case cancelNewGame
    case initialInterfaceIsReady
    case startNewGame
    case userSelectedPickerRow(Int)
    case userSelectedTableRow(IndexPath)
}
