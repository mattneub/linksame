import UIKit

/// Globally available externalities.
@MainActor
final class Services {
    // I don't like the singleton pattern, but it's an elegant way to ensure there can be only one.
    static var shared: Services = Services.init()
    private init() {}

    var bundle: any BundleType = Bundle.main
    var persistence: any PersistenceType = Persistence()
    var screen: any ScreenType = UIScreen.main
}
