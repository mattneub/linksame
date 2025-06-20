
import UIKit
import AVFoundation

// A Piece is a view that knows the name of an image
// given that, it knows how to draw and hilite itself
// it also has properties so that it can report where it belongs in the grid

final class Piece: UIView {

    // Define equality in terms of piece reducers. In fact, define equality between piece and
    // piece reducer, since we will often have reason to need this.

    static func == (lhs: Piece, rhs: Piece) -> Bool {
        return lhs.toReducer == rhs.toReducer
    }
    static func == (lhs: PieceReducer, rhs: Piece) -> Bool {
        return lhs == rhs.toReducer
    }
    static func == (lhs: Piece, rhs: PieceReducer) -> Bool {
        return lhs.toReducer == rhs
    }

    /// What image we display.
    let picName: String

    /// Where we are slotted.
    let column: Int
    let row: Int

    private var hilite: Bool = false
    var isHilited: Bool {
        return self.hilite
    }

    override var description: String {
        return "picname: \(picName); column: \(column); row: \(row)"
    }

    init(picName: String, column: Int, row: Int) {
        self.picName = picName
        self.column = column
        self.row = row
        super.init(frame: .zero)
    }

    convenience init(piece: PieceReducer) {
        self.init(picName: piece.picName, column: piece.column, row: piece.row)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        let perireal = CGRect(x: 0, y: 0, width: self.bounds.width, height: self.bounds.height)
        let con = UIGraphicsGetCurrentContext()!
        
        con.setLineCap(.square)
        
        // fill: according to highlight state
        let beige = UIColor(red:0.900, green:0.798, blue:0.499, alpha:1.000)
        let purple = UIColor(red:0.898, green:0.502, blue:0.901, alpha:1.000)
        con.setFillColor(self.isHilited ? purple.cgColor : beige.cgColor)
        con.fill(perireal.insetBy(dx: -1, dy: -1)) // outset to ensure full coverage
        
        // frame: draw shade all the way round, then light round two sides
        let shadow = UIColor(red: 0.670, green: 0.537, blue: 0.270, alpha: 1.000)
        con.setStrokeColor(shadow.cgColor)
        let peri = perireal.insetBy(dx: 1, dy: 1)
        con.setLineWidth(1.5)
        con.stroke(peri)
        let lite = UIColor(red: 1.000, green: 0.999, blue: 0.999, alpha: 1.000)
        con.setStrokeColor(lite.cgColor)
        let points = [
            CGPoint(x: peri.minX, y: peri.maxY),
            CGPoint(x: peri.minX, y: peri.minY),
            CGPoint(x: peri.minX, y: peri.minY),
            CGPoint(x: peri.maxX, y: peri.minY)
        ]
        con.strokeLineSegments(between: points)
        
        // get picture; little-known fact, we can have the caching of UIImage(named:) for folder-contained image
        let pic = UIImage(named:"foods/\(self.picName)")!
        // draw centered
        // grapple with what would happen if rect were smaller than pic.size
        let inset: CGFloat = 4
        let maxrect = rect.insetBy(dx: inset, dy: inset)
        var drawrect = AVMakeRect(aspectRatio: pic.size, insideRect: maxrect.insetBy(dx: 10, dy: 10))
        // experiment: make bigger than original image, up to this limit, esp. for Easy ipad size
        if pic.size.width > drawrect.width || pic.size.height > drawrect.height {
            let smallerrect = AVMakeRect(aspectRatio: pic.size, insideRect: maxrect)
            drawrect = maxrect.centeredRectOfSize(smallerrect.size)
        }
        pic.draw(in: drawrect)
    }
    
    func toggleHilite () {
        self.hilite = !self.hilite
        self.setNeedsDisplay()
    }

    var toReducer: PieceReducer {
        PieceReducer(picName: picName, column: column, row: row)
    }
}

/// Reducer for maintaining key information about a Piece.
struct PieceReducer: Equatable, Codable {
    let picName: String
    var column: Int = -1
    var row: Int = -1
}
