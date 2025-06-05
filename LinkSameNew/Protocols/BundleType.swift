import Foundation

/// Protocol describing the main bundle, so we can mock it for testing.
@MainActor
protocol BundleType {
    func path(forResource name: String?, ofType ext: String?) -> String?
}

extension Bundle: BundleType {}
