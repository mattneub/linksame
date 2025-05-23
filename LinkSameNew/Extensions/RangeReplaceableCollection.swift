import Foundation

extension RangeReplaceableCollection where Iterator.Element: Equatable {
    /// Remove the first occurrence of the specified object (by equality) from the collection.
    /// If not present, nothing happens and no harm done.
    /// - Parameter object: Object to remove.
    mutating func remove(object: Self.Iterator.Element) {
        if let found = self.firstIndex(of: object) {
            self.remove(at: found)
        }
    }
}
