//
//  Piece.swift
//  LinkSame
//
//  Created by Matt Neuburg on 6/22/14.
//
//


// define equality as identity
func == (lhs:Piece, rhs:Piece) -> Bool {
    return lhs === rhs
}

import UIKit

class Piece : UIView, NSCoding, Equatable, Printable {
    
    /*
@property (nonatomic, copy) NSString* picName;
@property (nonatomic) int x, y;
@property (nonatomic, readonly, getter=isHilited) BOOL hilite;
- (void) toggleHilite;
*/
    var pic : UIImage!
    var picName : String = "" {
    didSet {
        // when name is set, we also fetch picture and set it
        // that way, we don't have to fetch picture each time we draw ourself
        // perhaps this is no savings of time and a waste of memory, I've no idea
        // also set actual picture at this time; outside world deals only with the name
        let path = NSBundle.mainBundle().pathForResource(self.picName, ofType: "png", inDirectory:"foods")
        self.pic = UIImage(contentsOfFile:path)
    }
    }
    var x : Int = 0, y : Int = 0
    var hilite : Bool = false
    var isHilited : Bool {
    return self.hilite
    }
    
    override var description : String {
    return "picname: \(picName); x: \(x); y: \(y)"
    }
    
    // interestingly, we MUST implement initWithFrame, even though we do nothing
    // we cannot merely inherit it
    
    init(frame:CGRect) {
        super.init(frame:frame)
    }
    
    override func encodeWithCoder(coder: NSCoder!) {
        coder.encodeInteger(self.x, forKey:"x")
        coder.encodeInteger(self.y, forKey:"y")
        coder.encodeObject(self.picName, forKey:"picName")
    }
    
    init(coder: NSCoder!) {
        self.x = coder.decodeIntegerForKey("x")
        self.y = coder.decodeIntegerForKey("y")
        self.picName = coder.decodeObjectForKey("picName") as String
        super.init(frame:CGRectMake(0,0,0,0)) // dummy value
    }
    
    override func drawRect(rect: CGRect) {
        let perireal = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height)
        let context = UIGraphicsGetCurrentContext()
        
        CGContextSetLineCap(context, kCGLineCapSquare) // notice nothing fancy happens with these pure c types
        
        // fill, according to highlight state
        let beige = UIColor(red:0.900, green:0.798, blue:0.499, alpha:1.000)
        let purple = UIColor(red:0.898, green:0.502, blue:0.901, alpha:1.000)
        CGContextSetFillColorWithColor(context, self.hilite ? purple.CGColor : beige.CGColor)
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
        
        // draw picture centered
        let ppic = self.pic.CGImage
        let picw = CGFloat(CGImageGetWidth(ppic))
        let pich = CGFloat(CGImageGetHeight(ppic))
        // flip!
        CGContextTranslateCTM(context, 0, self.bounds.size.height)
        CGContextScaleCTM(context, 1, -1)
        CGContextDrawImage(context,
            CGRectInset(peri,
                (peri.width - picw)/2.0,
                (peri.height - pich)/2.0),
            self.pic.CGImage)
    }
    
    func toggleHilite () {
        self.hilite = !self.hilite
        self.setNeedsDisplay()
    }
    
}