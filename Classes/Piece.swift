

// define equality as identity
func == (lhs:Piece, rhs:Piece) -> Bool {
    return lhs === rhs
}

extension CGRect {
    var center : CGPoint {
        return CGPoint(x: self.midX, y: self.midY)
    }
    func centeredRectOfSize(_ sz:CGSize) -> CGRect {
        let c = self.center
        let x = c.x - sz.width/2.0
        let y = c.y - sz.height/2.0
        return CGRect(origin:CGPoint(x: x,y: y), size:sz)
    }
}

import UIKit
import AVFoundation

class Piece : UIView {
    
    var picName : String
    
    var x : Int = 0, y : Int = 0 // where we are slotted
    
    fileprivate var hilite : Bool = false
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
    
    struct CoderKey {
        static let x = "x"
        static let y = "y"
        static let picName = "picName"
    }
    
    override func encode(with coder: NSCoder) {
        coder.encode(self.x, forKey:CoderKey.x)
        coder.encode(self.y, forKey:CoderKey.y)
        coder.encode(self.picName, forKey:CoderKey.picName)
    }
    
    required init(coder: NSCoder) {
        self.x = coder.decodeInteger(forKey:CoderKey.x)
        self.y = coder.decodeInteger(forKey:CoderKey.y)
        self.picName = coder.decodeObject(forKey:CoderKey.picName) as! String
        super.init(frame:CGRect(x: 0,y: 0,width: 0,height: 0)) // dummy value
    }
    
    override func draw(_ rect: CGRect) {
        let perireal = CGRect(x: 0, y: 0, width: self.bounds.width, height: self.bounds.height)
        let context = UIGraphicsGetCurrentContext()
        
        context?.setLineCap(.square)
        
        // fill: according to highlight state
        let beige = UIColor(red:0.900, green:0.798, blue:0.499, alpha:1.000)
        let purple = UIColor(red:0.898, green:0.502, blue:0.901, alpha:1.000)
        context?.setFillColor(self.isHilited ? purple.cgColor : beige.cgColor)
        context?.fill(perireal.insetBy(dx: -1, dy: -1)) // outset to ensure full coverage
        
        // frame: draw shade all the way round, then light round two sides
        let shadow = UIColor(red:0.670, green:0.537, blue:0.270, alpha:1.000)
        context?.setStrokeColor(shadow.cgColor)
        let peri = perireal.insetBy(dx: 1, dy: 1)
        context?.setLineWidth(1.5)
        context?.stroke(peri)
        let lite = UIColor(red:1.000, green:0.999, blue:0.999, alpha:1.000)
        context?.setStrokeColor(lite.cgColor)
        let points = [
            CGPoint(x: peri.minX, y: peri.maxY),
            CGPoint(x: peri.minX, y: peri.minY),
            CGPoint(x: peri.minX, y: peri.minY),
            CGPoint(x: peri.maxX, y: peri.minY)
        ]
        context?.strokeLineSegments(between: points)
        
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
