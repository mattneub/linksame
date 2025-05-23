import UIKit

/// Extension that allows us easily to turn the window's user interaction off and on
extension UIApplication {
    /// Off/on pairs are nestable; this var keeps track of the current nesting level.
    static var interactionLevel = 0

    /// Turn the user interaction off or on. If you turn it off, you must always subsequently
    /// turn it on! Use _exactly_ one "on" for every "off".
    /// - Parameter interactionOn: Flag stating whether user interaction is to be turned on (true) or off (false).
    ///
    static func userInteraction(_ interactionOn: Bool) {
        guard let window = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first else { return }
        switch interactionOn {
        case false: // turn interaction off, increase nesting level
            print("off")
            window.isUserInteractionEnabled = false
            Self.interactionLevel += 1
        case true: // decrease nesting level; if we reach zero, turn interaction on
            print("on")
            Self.interactionLevel -= 1
            if Self.interactionLevel < 0 {
                Self.interactionLevel = 0
            }
            if Self.interactionLevel == 0 {
                window.isUserInteractionEnabled = true
            }
        }
    }
}

