import UIKit

/// Protocol characterizing the UIScreen, so we can mock it for testing.
protocol ScreenType {
    var traitCollection: UITraitCollection { get }
}

extension UIScreen: ScreenType {}
