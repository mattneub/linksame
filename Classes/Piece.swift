

// define equality as identity
func == (lhs:Piece, rhs:Piece) -> Bool {
    return lhs === rhs
}

extension CGRect {
    var center : CGPoint {
        return CGPointMake(CGRectGetMidX(self), CGRectGetMidY(self))
    }
    func centeredRectOfSize(sz:CGSize) -> CGRect {
        let c = self.center
        let x = c.x - sz.width/2.0
        let y = c.y - sz.height/2.0
        return CGRect(origin:CGPointMake(x,y), size:sz)
    }
}

import UIKit
import AVFoundation

class Piece : UIView, NSCoding, Equatable, Printable {
    
    private var pic : UIImage!
    var picName : String = "" {
        didSet {
            // when name is set, we also fetch picture and set it
            // that way, we don't have to fetch picture each time we draw ourself
            // perhaps this is no savings of time and a waste of memory, I've no idea
            // but hey, the pictures are tiny
            let path = NSBundle.mainBundle().pathForResource(self.picName, ofType: "png", inDirectory:"foods")
            self.pic = UIImage(contentsOfFile:path!)
        }
    }
    
    var x : Int = 0, y : Int = 0 // where we are slotted
    
    private var hilite : Bool = false
    var isHilited : Bool {
        return self.hilite
    }
    
    override var description : String {
        return "picname: \(picName); x: \(x); y: \(y)"
    }
    
    // interestingly, we MUST implement initWithFrame, even though we do nothing
    // we cannot merely inherit it
    
    override init(frame:CGRect) {
        super.init(frame:frame)
    }
    
    override func encodeWithCoder(coder: NSCoder) {
        coder.encodeInteger(self.x, forKey:"x")
        coder.encodeInteger(self.y, forKey:"y")
        coder.encodeObject(self.picName, forKey:"picName")
    }
    
    required init(coder: NSCoder) {
        self.x = coder.decodeIntegerForKey("x")
        self.y = coder.decodeIntegerForKey("y")
        self.picName = coder.decodeObjectForKey("picName") as! String
        super.init(frame:CGRectMake(0,0,0,0)) // dummy value
    }
    
    override func drawRect(rect: CGRect) {
        let perireal = CGRectMake(0, 0, self.bounds.width, self.bounds.height)
        let context = UIGraphicsGetCurrentContext()
        
        CGContextSetLineCap(context, kCGLineCapSquare)
        
        // fill: according to highlight state
        let beige = UIColor(red:0.900, green:0.798, blue:0.499, alpha:1.000)
        let purple = UIColor(red:0.898, green:0.502, blue:0.901, alpha:1.000)
        CGContextSetFillColorWithColor(context, self.isHilited ? purple.CGColor : beige.CGColor)
        CGContextFillRect(context, CGRectInset(perireal, -1, -1)) // outset to ensure full coverage
        
        // frame: draw shade all the way round, then light round two sides
        let shadow = UIColor(red:0.670, green:0.537, blue:0.270, alpha:1.000)
        CGContextSetStrokeColorWithColor(context, shadow.CGColor)
        let peri = CGRectInset(perireal, 1, 1)
        CGContextSetLineWidth(context, 1.5)
        CGContextStrokeRect(context, peri)
        let lite = UIColor(red:1.000, green:0.999, blue:0.999, alpha:1.000)
        CGContextSetStrokeColorWithColor(context, lite.CGColor)
        let points = [
            CGPointMake(peri.minX, peri.maxY),
            CGPointMake(peri.minX, peri.minY),
            CGPointMake(peri.minX, peri.minY),
            CGPointMake(peri.maxX, peri.minY)
        ]
        CGContextStrokeLineSegments(context, points, 4)
        
        // draw centered
        // grapple with what would happen if rect were smaller than pic.size
        let inset : CGFloat = 4
        let maxrect = rect.rectByInsetting(dx: inset, dy: inset)
        var drawrect = maxrect.centeredRectOfSize(pic.size)
        if pic.size.width > maxrect.width || pic.size.height > maxrect.height {
            let smallerrect = AVMakeRectWithAspectRatioInsideRect(pic.size, maxrect)
            drawrect = maxrect.centeredRectOfSize(smallerrect.size)
        }
        self.pic.drawInRect(drawrect)
    }
    
    func toggleHilite () {
        self.hilite = !self.hilite
        self.setNeedsDisplay()
    }
    
}