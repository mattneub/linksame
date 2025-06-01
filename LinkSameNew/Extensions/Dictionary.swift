// https://stackoverflow.com/a/77663567/341994
extension Dictionary {
    func mapKeys<T>(_ keyProvider: (Key) -> T) -> [T: Value] {
        reduce(into: [T: Value]()) {
            $0[keyProvider($1.key)] = $1.value
        }
    }
}
