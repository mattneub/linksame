class Dummy {
    /// If `showActionSheet` is called, it posts a reference to its continuation here,
    /// so we can resume it when dismissing the action sheet externally (in `dismiss`).
    var actionSheetContinuation: CheckedContinuation<String?, Never>?

    /// Note that when you do this, you will leak a continuation if you dismiss the action sheet
    /// externally. That is why this implementation unfolds the continuation, so you can
    /// resume it when you dismiss.
    func showActionSheet(title: String?, options: [String]) async -> String? {
        await withCheckedContinuation { continuation in
            self.actionSheetContinuation = continuation
            let alert = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
            for option in options {
                alert.addAction(UIAlertAction(title: option, style: .default, handler: { action in
                    self.actionSheetContinuation = nil
                    continuation.resume(returning: action.title)
                }))
            }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
                self.actionSheetContinuation = nil
                continuation.resume(returning: nil)
            }))
            rootViewController?.present(alert, animated: unlessTesting(true))
        }
    }
}

