import Foundation

/// State sent by the processor to the presenter for reflection in the interface.
struct NewGameState: Equatable {
    var tableViewSections = [NewGameSection]()
    let maximumStages = 9
}

/// Description of a single section of the table view interface.
struct NewGameSection: Equatable {
    let title: String
    let rows: [String]
    var checkmarkedRow = -1
}
