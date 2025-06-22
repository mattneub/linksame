import Foundation
@testable import LinkSame

@MainActor
final class MockGravity: GravityType {
    var grid: Grid?
    var stageNumber: Int?
    var methodsCalled = [String]()
    var movenda = [Movendum]()

    func exerciseGravity(grid: inout Grid, stageNumber: Int) -> [Movendum] {
        methodsCalled.append(#function)
        self.grid = grid
        self.stageNumber = stageNumber
        return movenda
    }
}
