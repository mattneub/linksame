import Foundation
@testable import LinkSame

@MainActor
final class MockBundle: BundleType {
    var pathToReturn: String?
    var methodsCalled = [String]()
    var name: String?
    var ext: String?

    func path(forResource name: String?, ofType ext: String?) -> String? {
        methodsCalled.append(#function)
        self.name = name
        self.ext = ext
        return pathToReturn
    }
}
