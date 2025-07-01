import UIKit

/// Bar button item subclass that (1) accepts an action _handler_ rather than an entire UIAction,
/// and (2) _stores_ that handler in a public ivar so that we can easily call it for testing.
/// Also it stores the system item for testing.
final class MyBarButtonItem: UIBarButtonItem {
    /// The action handler passed in the initializer.
    var actionHandler: UIActionHandler?

    /// The system item passed in the initializer.
    var systemItem: UIBarButtonItem.SystemItem?

    /// Initializer that sits in front of `init(systemItem:primaryAction)`.
    /// - Parameters:
    ///   - systemItem: The system item that this bar button item represents.
    ///   - handler: Action handler to be performed when the item is tapped.
    ///
    convenience init(systemItem: UIBarButtonItem.SystemItem, handler: @escaping UIActionHandler) {
        self.init(systemItem: systemItem, primaryAction: UIAction(handler: handler))
        self.actionHandler = handler
        self.systemItem = systemItem
    }
}
