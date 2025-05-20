
import UIKit
import AVFoundation

// A Piece is a view that knows the name of an image
// given that, it knows how to draw and hilite itself
// it also has properties so that it can report where it belongs in the grid

final class Piece: UIView, Encodable, @preconcurrency Decodable {

    // define equality as identity
    static func == (lhs:Piece, rhs:Piece) -> Bool {
        return lhs === rhs
    }

    // what image we display
    nonisolated(unsafe) var picName : String

    // where we are slotted
    nonisolated(unsafe) var x : Int = 0
    nonisolated(unsafe) var y : Int = 0

    private var hilite : Bool = false
    var isHilited : Bool {
        return self.hilite
    }

    override var description : String {
        return "picname: \(picName); x: \(x); y: \(y)"
    }

    init(picName:String, frame:CGRect) {
        self.picName = picName
        super.init(frame:frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    enum CodingKeys : String, CodingKey {
        case x
        case y
        case picName
    }
    
    // because we are subclass of class with designated initializer, must implement `init(from:)` ourselves
    init(from decoder: any Decoder) throws {
        let con = try! decoder.container(keyedBy: CodingKeys.self)
        self.x = try! con.decode(Int.self, forKey: .x)
        self.y = try! con.decode(Int.self, forKey: .y)
        self.picName = try! con.decode(String.self, forKey: .picName)
        super.init(frame:.zero)
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
        let shadow = UIColor(red:0.670, green:0.537, blue:0.270, alpha:1.000)
        con.setStrokeColor(shadow.cgColor)
        let peri = perireal.insetBy(dx: 1, dy: 1)
        con.setLineWidth(1.5)
        con.stroke(peri)
        let lite = UIColor(red:1.000, green:0.999, blue:0.999, alpha:1.000)
        con.setStrokeColor(lite.cgColor)
        let points = [
            CGPoint(x: peri.minX, y: peri.maxY),
            CGPoint(x: peri.minX, y: peri.minY),
            CGPoint(x: peri.minX, y: peri.minY),
            CGPoint(x: peri.maxX, y: peri.minY)
        ]
        con.strokeLineSegments(between: points)
        
//        let path = Bundle.main.path(forResource: self.picName, ofType: "png", inDirectory:"foods")!
//        let pic = UIImage(contentsOfFile:path)!
        // get picture; little-known fact, we can have the caching of UIImage(named:) for folder-contained image
        let pic = UIImage(named:"foods/\(self.picName)")!
        // draw centered
        // grapple with what would happen if rect were smaller than pic.size
        let inset : CGFloat = 4
        let maxrect = rect.insetBy(dx: inset, dy: inset)
        var drawrect = maxrect.centeredRectOfSize(pic.size)
        if pic.size.width > maxrect.width || pic.size.height > maxrect.height {
            let smallerrect = AVMakeRect(aspectRatio: pic.size, insideRect: maxrect)
            drawrect = maxrect.centeredRectOfSize(smallerrect.size)
        }
        pic.draw(in: drawrect)
    }
    
    func toggleHilite () {
        self.hilite = !self.hilite
        self.setNeedsDisplay()
    }
    
}
