import UIKit

// space savers

@MainActor
let nc = NotificationCenter.default

// determination of hardware environment
@MainActor
var onPhone : Bool {
    return services.screen.traitCollection.userInterfaceIdiom == .phone
}

@MainActor
var on3xScreen : Bool {
    return services.screen.traitCollection.displayScale > 2.5
}

// =========================================
/// The sole global instance of the services.
@MainActor
var services: Services = Services.shared

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]?) -> Bool {
        unlessTesting {
            bootstrap()
        }
        return true
    }

    func bootstrap() {
        services.persistence.register([
            .size: Sizes.easy,
            .style: Styles.snacks,
            .lastStage: 8, // meaning 0-thru-8, so there will be nine
        ])
    }
}
