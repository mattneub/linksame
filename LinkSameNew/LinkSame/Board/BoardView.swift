import UIKit

/// The presenter of the BoardProcessor. It is a view, which is placed into the interface by
/// the coordinator at creation time.
class BoardView: UIView, ReceiverPresenter {

    weak var processor: (any Processor<BoardAction, BoardState, BoardEffect>)?

    /// Constants defining the outer boundary of the piece drawing area in terms of the piece size.
    /// OUTER is the _total_ additional boundary on _both_ sides of the drawing area; so, on the iPhone
    /// where space is tight, the value 1.0 represents _half_ a piece width on all four sides — i.e. just
    /// enough to draw a path that goes outside the pieces to the "center" of a non-existent piece
    /// outside the piece-drawing area. But that is only _just_ enough; the line would be right at
    /// the edge of the screen. So we add an additional 1/8 of a piece on all four sides (the margins).
    private let TOPMARGIN: CGFloat = (1.0/8.0)
    private let BOTTOMMARGIN: CGFloat = (1.0/8.0)
    private let LEFTMARGIN: CGFloat = (1.0/8.0)
    private let RIGHTMARGIN: CGFloat = (1.0/8.0)
    private lazy var OUTER: CGFloat = {
        var result : CGFloat = onPhone ? 1.0 : 2.0
        if on3xScreen { result = 2.0 }
        return result
    }()

    /// The dimensions of piece drawing. This defines our identity, not our state, so it's okay
    /// (philosophically) that we maintain them.
    let columns: Int
    let rows: Int

    /// Constant defining the size of a piece, based on the size of the view and the number of columns
    /// and rows, and our constants.
    lazy var pieceSize: CGSize = {
        let pieceWidth: CGFloat = bounds.width / (CGFloat(self.columns) + OUTER + LEFTMARGIN + RIGHTMARGIN)
        let pieceHeight: CGFloat = bounds.height / (CGFloat(self.rows) + OUTER + TOPMARGIN + BOTTOMMARGIN)
        return CGSize(width: pieceWidth, height: pieceHeight)
    }()

    /// View that holds the path drawing. It goes in front of all pieces.
    /// It is tappable, but user interaction is generally disabled, so taps fall thru to the pieces.
    lazy var pathView: PathView = {
        let pathView = PathView(frame: .zero)
        pathView.isUserInteractionEnabled = false // clicks just fall right thru
        let tap = UITapGestureRecognizer(target: self, action: #selector(tappedPathView))
        addGestureRecognizer(tap)
        return pathView
    }()

    /// Currently displayed pieces.
    var pieces: [Piece] {
        subviews(ofType: Piece.self)
    }

    /// Initializer. Called by the coordinator at creation time.
    /// - Parameters:
    ///   - columns: Number of columns for drawing pieces.
    ///   - rows: Number of rows for drawing pieces.
    init(columns: Int, rows: Int) {
        self.columns = columns
        self.rows = rows
        super.init(frame: .zero)
        setUp()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Called once, by our initializer. Create and insert the path view, where paths are drawn.
    /// It goes in front of where the pieces will go.
    func setUp() {
        addSubview(pathView)
        pathView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: pathView.topAnchor),
            bottomAnchor.constraint(equalTo: pathView.bottomAnchor),
            leadingAnchor.constraint(equalTo: pathView.leadingAnchor),
            trailingAnchor.constraint(equalTo: pathView.trailingAnchor),
        ])
    }

    func present(_ state: BoardState) async {
        // highlighted pieces
        for piece in pieces {
            if state.hilitedPieces.contains(where: { $0 == piece }) {
                if !piece.isHilited {
                    piece.toggleHilite()
                }
            } else {
                if piece.isHilited {
                    piece.toggleHilite()
                }
            }
        }
    }

    func receive(_ effect: BoardEffect) async {
        switch effect {
        case .illuminate(path: let path):
            await pathView.receive(.illuminate(path.map { centerOf(column: $0.column, row: $0.row) }))
        case .insert(let piece):
            insert(piece: piece)
        case .remove(let piece):
            remove(piece: piece)
        case .transition(let piece, let picture):
            guard let realPiece = pieces.first(where: { $0 == piece }) else {
                return
            }
            services.view.transition(with: realPiece, duration: 0.7, options: .transitionFlipFromLeft, animations: {
                realPiece.picName = picture
                realPiece.setNeedsDisplay()
            })
        case .userInteraction(let onOff):
            type(of: services.application).userInteraction(onOff)
        case .unilluminate:
            await pathView.receive(.unilluminate)
        }
    }

    /// Insert a piece into the interface at the correct frame.
    /// - Parameter piece: The piece to insert, expressed as a reducer.
    func insert(piece: PieceReducer) {
        // Make an actual Piece.
        let piece = Piece(piece: piece)
        // Calculate and set the frame of the piece,
        // based on the piece's knowledge of its slot in the grid.
        let size = self.pieceSize
        let origin = self.originOf(column: piece.column, row: piece.row)
        let frame = CGRect(origin: origin, size: size)
        piece.frame = frame
        // Place the piece in the interface.
        // We are conscious that we must not accidentally place it in front of the path view!
        insertSubview(piece, belowSubview: self.pathView)
        // Give the piece tap detection.
        let count = piece.gestureRecognizers?.count ?? 0
        if count == 0 {
            let tap = MyTapGestureRecognizer(target: self, action: #selector(tappedPiece))
            piece.addGestureRecognizer(tap)
            // Extra gesture recognizer just for me personally while testing.
            if ProcessInfo.processInfo.environment["TESTING"] != nil {
                let tap2 = UITapGestureRecognizer(target: self, action: #selector(developerDoubleTappedPiece))
                tap2.numberOfTapsRequired = 2
                piece.addGestureRecognizer(tap2)
            }
        }
    }
    
    /// Remove the piece described by the reducer.
    /// - Parameter piece: Reducer describing the piece to be removed.
    func remove(piece: PieceReducer) {
        if let realPiece = pieces.first(where: { $0 == piece }) {
            realPiece.removeFromSuperview()
        }
    }

    // TODO: Should probably come up with a better name for this.
    /// Utility: Given a piece's slot in the grid, where should it be physically drawn on the view?
    /// - Parameters:
    ///   - column: The column address of the piece's slot.
    ///   - row: The row address of the piece's slot
    /// - Returns: The top-left origin point of the piece. Together with `pieceSize`, this defines
    ///   the piece's frame.
    func originOf(column: Int, row: Int) -> CGPoint {
        assert(column >= -1 && column <= self.columns, "Position requested out of bounds (column)")
        assert(row >= -1 && row <= self.rows, "Position requested out of bounds (row)")
        // Divide view bounds, allow 2 extra on all sides.
        let pieceWidth = self.pieceSize.width
        let pieceHeight = self.pieceSize.height
        let x = (
            ((OUTER/2.0 + LEFTMARGIN) * pieceWidth)
            + (CGFloat(column) * pieceWidth)
        )
        let y = (
            ((OUTER/2.0 + TOPMARGIN) * pieceHeight)
            + (CGFloat(row) * pieceHeight)
            + (onPhone ? 0 : 64/2) // allow for toolbar
        )
        return CGPoint(x: x, y: y)
    }

    /// Utility: Given a piece's slot in the grid, where is its center in the view?
    /// - Parameters:
    ///   - column: The column address of the piece's slot.
    ///   - row: The row address of the piece's slot
    /// - Returns: The center of the piece, if there were a piece at this slot.
    func centerOf(column: Int, row: Int) -> CGPoint {
        CGRect(origin: originOf(column: column, row: row), size: pieceSize).center
    }

    @objc func tappedPathView() {}

    @objc func tappedPiece(_ gestureRecognizer: UITapGestureRecognizer) {
        guard let piece = gestureRecognizer.view as? Piece else {
            return
        }
        Task {
            await processor?.receive(.tapped(piece.toReducer))
        }
    }

    @objc func developerDoubleTappedPiece() {}
}
