// https://stackoverflow.com/a/77663567/341994
extension Dictionary {
    /// Make new dictionary whose keys are transformed by a keyProvider function.
    /// - Parameter keyProvider: Function that takes a key of the original dictionary and outputs
    ///     a new key of some consistent type.
    /// - Returns: The new dictionary.
    func mapKeys<T: Hashable>(_ keyProvider: (Key) -> T) -> [T: Value] {
        reduce(into: [T: Value]()) {
            $0[keyProvider($1.key)] = $1.value
        }
    }
}
