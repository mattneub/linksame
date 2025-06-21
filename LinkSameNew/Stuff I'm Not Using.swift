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
