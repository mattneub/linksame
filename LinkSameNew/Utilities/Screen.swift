import UIKit

/// Protocol characterizing the screen object, so we can mock it for testing.
protocol ScreenType {
    var traitCollection: UITraitCollection { get }
}

final class Screen: ScreenType {
    var traitCollection: UITraitCollection {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return UITraitCollection()
        }
        let screen = scene.screen
        return screen.traitCollection
    }
}
