import UIKit

/// Protocol characterizing the UIScreen, so we can mock it for testing.
@MainActor
protocol ScreenType {
    var traitCollection: UITraitCollection { get }
}

extension UIScreen: ScreenType {}
