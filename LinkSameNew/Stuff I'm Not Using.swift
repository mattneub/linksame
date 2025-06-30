// okay, so previously I had this functionality spread over two methods
// board illuminate() and unilluminate(), plus remembering to set the state property
// plus I was skankily handing the path to draw into the layer itself
// that is just the kind of thing I wanted to clean up
// so I put it all into a little helper class
@MainActor
final class LegalPathShower : NSObject {
    // view whose draw defers to us
    unowned private let board : BoardProcessor
    fileprivate init(board:BoardProcessor) {self.board = board}
    private var pathToIlluminate : Path?
    fileprivate private(set) var isIlluminating = false {
        didSet {
            // TODO: Restore this, just commenting out so I can compile
            //                switch self.isIlluminating {
            //                case false:
            //                    self.pathToIlluminate = nil
            //                    self.board.pathView.isUserInteractionEnabled = false // make touches just fall thru once again
            //                    self.board.pathView.setNeedsDisplay()
            //                case true:
            //                    self.board.pathView.isUserInteractionEnabled = true // block touches
            //                    self.board.pathView.setNeedsDisplay()
            //                }
        }
    }
    fileprivate func illuminate(path:Path) {
        self.pathToIlluminate = path
        self.isIlluminating = true
    }
    fileprivate func unilluminate() {
        self.isIlluminating = false
    }
    deinit {
        print("farewell from LegalPathShower")
    }
}

private lazy var legalPathShower = LegalPathShower(board:self)

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

