
import UIKit
import QuartzCore

func println(object: Any) {
    #if DEBUG
        Swift.println(object)
    #endif
}

var onPhone : Bool {
    return UIScreen.mainScreen().traitCollection.userInterfaceIdiom == .Phone
}

var on6plus : Bool {
    return UIScreen.mainScreen().traitCollection.displayScale > 2.5
}

func removeObject<T:Equatable>(inout arr:Array<T>, object:T) -> T? {
    if let found = find(arr,object) {
        return arr.removeAtIndex(found)
    }
    return nil
}

func ui(yn:Bool) { // false means no user interaction, true means turn it back on
    if !yn {
        UIApplication.sharedApplication().beginIgnoringInteractionEvents()
    } else {
        UIApplication.sharedApplication().endIgnoringInteractionEvents()
    }
}

let TOPMARGIN : CGFloat = (1.0/8.0)
let BOTTOMMARGIN : CGFloat = (1.0/8.0)
let LEFTMARGIN : CGFloat = (1.0/8.0)
let RIGHTMARGIN : CGFloat = (1.0/8.0)
var OUTER : CGFloat {
    var result : CGFloat = onPhone ? 1.0 : 2.0
    if on6plus { result = 2.0 }
    return result
}


// I was hoping there would be no good reason to be an NSObject derivative
// but it turned out that keyed archiving requires it
// however, unfortunately then my grid gave trouble, probably because it is multidimensional
// but I didn't want to lose that, so I created a grid struct (no need for full-fledged class), 
// which hides (encapsulates) the actual grid

struct Grid {
    var grid : [[Piece?]]
    let xct : Int
    let yct : Int
    init(_ x:Int, _ y:Int) {
        self.xct = x
        self.yct = y
        // and now set up the empty grid with nils
        // hold my beer and watch this!
        self.grid = Array(count:xct, repeatedValue: Array(count:yct, repeatedValue:nil))
    }
    subscript(i:Int) -> [Piece?] {
        get {
            return self.grid[i]
        }
        set(val) {
            self.grid[i] = val
        }
    }
}

final class Board : NSObject, NSCoding {
    
    typealias Point = (Int,Int)
    typealias Path = [Point]
    
    var view: UIView
    var stage = 0
    var showingHint = false
    private var hilitedPieces = [Piece]()
    private var xct : Int { return self.grid.xct }
    private var yct : Int { return self.grid.yct }
    private var movenda = [Piece]()
    private var grid : Grid // can't live without a grid
    private var hintPath : Path?
    private var deckAtStartOfStage = [String]()
    // utility for obtaining a reference to the view that holds the transparency layer
    // we need this so we can switch touch fall-thru on and off
    var pathView : UIView? {
        return self.view.viewWithTag(999)
    }
    // utility for obtaining a reference to the transparency layer
    private var pathLayer : CALayer? {
        return (self.pathView?.layer.sublayers as? [CALayer])?.last
    }

    private lazy var pieceSize : CGSize = {
        // assert(self.view != nil, "Meaningless to ask for piece size with no view.")
        assert((self.xct > 0 && self.yct > 0), "Meaningless to ask for piece size with no grid dimensions.")
        println("calculating piece size")
        // divide view bounds, allow 1 extra plus margins
        let pieceWidth : CGFloat = self.view.bounds.size.width / (CGFloat(self.xct) + OUTER + LEFTMARGIN + RIGHTMARGIN)
        let pieceHeight : CGFloat = self.view.bounds.size.height / (CGFloat(self.yct) + OUTER + TOPMARGIN + BOTTOMMARGIN)
        return CGSizeMake(pieceWidth, pieceHeight)
    }()
    
    init (boardFrame:CGRect, gridSize:(Int,Int)) {
        self.view = UIView(frame:boardFrame)
        self.grid = Grid(gridSize)
        super.init()
        self.createPathView()
    }
    
    private struct Coder {
        static let grid = "gridsw"
        static let x = "xctsw"
        static let y = "yctsw"
        static let stage = "stagesw"
        static let size = "piecesizesw"
        static let frame = "framesw"
    }
    
    private func createPathView() {
        // board is now completely empty
        // place invisible view on top of it; this is where paths will be drawn
        // board will draw directly into its layer using layer delegate's drawLayer:inContext:
        // but we must not set a view's layer's delegate, so we create a sublayer
        let v = UIView(frame: self.view.bounds)
        v.tag = 999
        v.userInteractionEnabled = false // clicks just fall right thru
        let lay = CALayer()
        v.layer.addSublayer(lay)
        lay.frame = v.layer.bounds
        self.view.addSubview(v)
    }
    
    func encodeWithCoder(coder: NSCoder) {
        // coder.encodeObject(self.grid, forKey: "gridsw")
        // but that's never going to work; there are nils in our grid!
        // flatten to single-dimensional array of strings
        var saveableGrid = [String]()
        for i in 0 ..< self.xct {
            for j in 0 ..< self.yct {
                let piece = self.grid[i][j]
                saveableGrid.append( piece?.picName ?? "" )
            }
        }
        coder.encodeObject(saveableGrid, forKey: Coder.grid)
        coder.encodeInteger(self.xct, forKey: Coder.x)
        coder.encodeInteger(self.yct, forKey: Coder.y)
        coder.encodeInteger(self.stage, forKey: Coder.stage)
        coder.encodeCGSize(self.pieceSize, forKey: Coder.size)
        coder.encodeCGRect(self.view.frame, forKey: Coder.frame)
    }
    
    // little-known fact: you have to implement init(coder:), but no law says it cannot be a convenience initializer!
    // thus we can eliminate repetition by calling the other initializer
    
    required convenience init(coder: NSCoder) {
        let xct = coder.decodeIntegerForKey( Coder.x )
        let yct = coder.decodeIntegerForKey( Coder.y )
        let frame = coder.decodeCGRectForKey( Coder.frame )
        self.init(boardFrame:frame, gridSize:(xct,yct))
        
        self.stage = coder.decodeIntegerForKey( Coder.stage )
        self.pieceSize = coder.decodeCGSizeForKey( Coder.size )
        
        var flatGrid = coder.decodeObjectForKey( Coder.grid ) as! [String]
        for i in 0 ..< self.xct {
            for j in 0 ..< self.yct {
                let picname = flatGrid.removeAtIndex(0)
                if !picname.isEmpty {
                    self.addPieceAt((i,j), withPicture: picname)
                }
            }
        }
        self.legalPath() // generate initial hint
    }
    
    func createAndDealDeck() {
        // determine which pieces to use
        let (start1,start2) = Styles.pieces(ud.stringForKey(Default.Style)!)
        // create deck of piece names
        var deck = [String]()
        for ct in 0..<4 {
            for i in start1..<start1+9 {
                deck += [String(i)]
            }
        }
        // determine which additional pieces to use, finish deck of piece names
        let (w,h) = (self.xct, self.yct)
        let howmany : Int = ((w * h) / 4) - 9
        for ct in 0..<4 {
            for i in start2..<start2+howmany {
                deck += [String(i)]
            }
        }
        for ct in 0..<4 {
            deck.shuffle()
        }
        
        // store a copy so we can restart the stage if we have to
        self.deckAtStartOfStage = deck
        
        // deal out the pieces and we're all set! Pieces themselves and Board object take over interactions from here
        for i in 0..<w {
            for j in 0..<h {
                self.addPieceAt((i,j), withPicture: deck.removeLast()) // heh heh, pops and returns
            }
        }
        
        self.legalPath() // generate initial hint
    }
    
    func restartStage() {
        // deal stored deck; we have to remove existing pieces as we go
        var deck = self.deckAtStartOfStage
        for i in 0..<self.xct {
            for j in 0..<self.yct {
                if let oldPiece = self.pieceAt(i,j) {
                    self.removePiece(oldPiece)
                }
                self.addPieceAt((i,j), withPicture: deck.removeLast()) // heh heh, pops and returns
            }
        }
        self.legalPath() // generate initial hint
    }


    func redeal () {
        do {
            ui(false)
            // gather up all pieces (as names), shuffle them, deal them into their current slots
            var deck = [String]()
            for i in 0 ..< self.xct {
                for j in 0 ..< self.yct {
                    let piece = self.pieceAt((i,j))
                    if piece == nil {
                        continue
                    }
                    deck += [piece!.picName]
                }
            }
            deck.shuffle()
            deck.shuffle()
            deck.shuffle()
            deck.shuffle()
            ui(true)
            for i in 0 ..< self.xct {
                for j in 0 ..< self.yct {
                    let piece = self.pieceAt((i,j))
                    if let piece = piece {
                        // very lightweight; we just assign the name, let the piece worry about the picture
                        UIView.transitionWithView(piece, duration: 0.7, options: UIViewAnimationOptions.TransitionFlipFromLeft, animations: {
                            piece.picName = deck.removeLast()
                            piece.setNeedsDisplay()
                            }, completion: nil)
                    }
                }
            }
        } while self.legalPath() == nil
    }
    
    // given a series of CGPoints (wrapped up as NSValue), connect the dots
    // we used to draw this ourselves and flash a view
    // now, however, the view is already there
    // all we do is store the array in the transparency layer and tell the layer it needs drawing
    
    private func illuminate (arr: Path) {
        if let pathLayer = self.pathLayer {
            println("about to draw path: \(arr)")
            pathLayer.delegate = self // tee-hee
            self.pathView?.userInteractionEnabled = true
            // transform path, which is an array of Point, into an NSArray of NSValue wrapping CGPoint
            // so we can store it in the layer
            let arrCGPoints : [CGPoint] = arr.map { CGPointMake(CGFloat($0.0),CGFloat($0.1)) }
            let arrNSValues = arrCGPoints.map { NSValue(CGPoint:$0) }
            pathLayer.setValue(arrNSValues, forKey:"arr")
            pathLayer.setNeedsDisplay()
            self.showingHint = true
        }
    }
    
    // this is the actual path drawing code
    // we are the delegate of the transparency layer so we are called when the layer is told it needs redrawing
    // thus we are handed a context and we can just draw directly into it
    // the layer is holding an array of NSValues wrapping CGPoints that tells us what path to draw!
    
    override func drawLayer(layer: CALayer!, inContext con: CGContext!) {
        let arr = layer.valueForKey("arr") as! [NSValue]
        // unwrap arr to CGPoints, unwrap to a pair of integers
        let arr2 : Path = arr.map {let pt = $0.CGPointValue(); return (Int(pt.x),Int(pt.y))}
        // connect the dots; however, the dots we want to connect are the *centers* of the pieces...
        // whereas we are given piece *origins*, so calculate offsets
        let sz = self.pieceSize
        let offx = sz.width/2.0
        let offy = sz.height/2.0
        CGContextSetLineJoin(con, kCGLineJoinRound)
        CGContextSetRGBStrokeColor(con, 0.4, 0.4, 1.0, 1.0)
        CGContextSetLineWidth(con, 3.0)
        CGContextBeginPath(con)
        for (var i = 0; i < arr2.count - 1; i++) {
            let p1 = arr2[i]
            let p2 = arr2[i+1]
            let orig1 = self.originOf(p1)
            let orig2 = self.originOf(p2)
            CGContextMoveToPoint(con, orig1.x + offx, orig1.y + offy)
            CGContextAddLineToPoint(con, orig2.x + offx, orig2.y + offy)
        }
        CGContextStrokePath(con)
    }
    
    // erase the path by clearing the transparency layer (nil contents)
    
    func unilluminate () {
        if let pathLayer = self.pathLayer {
            pathLayer.delegate = nil
            pathLayer.contents = nil
            self.pathView?.userInteractionEnabled = false // make touches just fall thru once again
            self.showingHint = false
        }
    }
    
    private func pieceAt(p:Point) -> Piece? {
        let (i,j) = p
        // it is legal to ask for piece one slot outside boundaries, but not further
        assert(i >= -1 && i <= self.xct, "Piece requested out of bounds (x)")
        assert(j >= -1 && j <= self.yct, "Piece requested out of bounds (y)")
        // report slot outside boundaries as empty
        if (i == -1 || i == self.xct) { return nil }
        if (j == -1 || j == self.yct) { return nil }
        // report actual value within boundaries
        return self.grid[i][j]
    }
    
    // put a piece in a slot and into interface
    
    private func addPieceAt(p:Point, withPicture picTitle:String) {
        let sz = self.pieceSize
        let orig = self.originOf(p)
        let f = CGRect(origin: orig, size: sz)
        let piece = Piece(frame:f)
        piece.picName = picTitle
        // place the Piece in the interface
        // we are conscious that we must not accidentally draw on top of the transparency view
        if let pathView = self.pathView {
            self.view.insertSubview(piece, belowSubview: pathView)
        }
        // also place the Piece in the grid, and tell it where it is
        let (i,j) = p
        self.grid[i][j] = piece
        (piece.x, piece.y) = (i,j)
        println("Point was \(p), pic was \(picTitle)\nCreated \(piece)")
        // set up tap detection
        let t = UITapGestureRecognizer(target: self, action: "handleTap:")
        piece.addGestureRecognizer(t)
        // wow, that was easy
    }
    
    // as pieces are highlighted, we store them in an ivar
    // thus, to unhighlight all highlighted pieces, we just run thru that list
    // now public, because controller might need to cancel existing highlight
    // make no assumptions about how many are in list!
    
    func unhilite() {
        while self.hilitedPieces.count > 0 {
            let p = self.hilitedPieces.removeLast()
            p.toggleHilite()
        }
    }
    
    // bottleneck utility for when user correctly selects a pair
    // flash the path and remove the two pieces
    
    private func removePairAndIlluminatePath(path:Path) {
        ui(false)
        self.illuminate(path)
        delay(0.2) {
            self.unilluminate()
            delay(0.1) {
                ui(true)
                self.reallyRemovePair()
            }
        }
    }
    
    // utility to determine whether the line from p1 to p2 consists entirely of nil
    
    private func lineIsClearFrom(p1:(x:Int,y:Int), to p2:(x:Int,y:Int)) -> Bool {
        if !(p1.x == p2.x || p1.y == p2.y) {
            return false // they are not even on the same line
        }
        // determine which dimension they share, then which way they are ordered
        var start:Point, end:Point
        if p1.x == p2.x {
            if p1.y < p2.y {
                (start,end) = (p1,p2)
            } else {
                (start,end) = (p2,p1)
            }
            for i in start.1+1 ..< end.1 {
                if self.pieceAt((p1.x,i)) != nil {
                    return false
                }
            }
        } else { // p1.y == p2.y
            if p1.x < p2.x {
                (start,end) = (p1,p2)
            } else {
                (start,end) = (p2,p1)
            }
            for i in start.0+1 ..< end.0 {
                if self.pieceAt((i,p1.y)) != nil {
                    return false
                }
            }
        }
        return true
    }
    
    // utility to remove a piece from the interface and from the grid (i.e. replace it by nil)
    // no more NSNull!
    
    private func removePiece(p:Piece) {
        self.grid[p.x][p.y] = nil
        p.removeFromSuperview()
    }
    
    // utility to learn whether the grid is empty, indicating that the game is over
    
    private func gameOver () -> Bool {
        // return true // testing game end
        for x in 0..<self.xct {
            for y in 0..<self.yct {
                if self.pieceAt((x,y)) != nil {
                    return false
                }
            }
        }
        return true
    }
    
    // given a piece's place in the grid, where should it be physically drawn on the view?
    
    private func originOf(p:Point) -> CGPoint {
        let (i,j) = p
        assert(i >= -1 && i <= self.xct, "Position requested out of bounds (x)")
        assert(j >= -1 && j <= self.yct, "Position requested out of bounds (y)")
        // divide view bounds, allow 2 extra on all sides
        let pieceWidth = self.pieceSize.width
        let pieceHeight = self.pieceSize.height
        let x = ((OUTER/2.0 + LEFTMARGIN) * pieceWidth) + (CGFloat(i) * pieceWidth)
        let y = ((OUTER/2.0 + TOPMARGIN) * pieceHeight) + (CGFloat(j) * pieceHeight) + (onPhone ? 0 : 64/2) // allow for toolbar
        return CGPointMake(x,y)

    }
    
    // my finest hour!
    // utility to slide piece to a new position
    // the problem is that we must do this for many pieces at once
    // the solution is that caller calls this utility repeatedly
    // this utility *prepares* the pieces to be moved but does not physically move them
    // it also puts the pieces in movenda
    // the caller then calls moveMovenda and the slide actually happens
 
    // yeah, very clever, but you gotta wonder whether I could do better now that I understand how animation works
    // TODO: look into it
    
    private func movePiece(p:Piece, to newPoint:(Int,Int)) {
        assert(self.pieceAt(newPoint) == nil, "Slot to move piece to must be empty")
        // move the piece within the *grid*
        let s = p.picName
        let oldFrame = p.frame
        self.removePiece(p)
        self.addPieceAt(newPoint, withPicture:s)
        // however, we are not yet redrawn, so now...
        // return piece to its previous position! but add to movenda
        // later call to moveMovenda will thus animate it into correct position
        let pnew = self.pieceAt(newPoint)!
        pnew.frame = oldFrame
        self.movenda += [pnew]
    }

    private func checkStuck() {
        let path = self.legalPath()
        if path == nil {
            self.redeal()
        }
    }
    
    private func reallyRemovePair () {
        ui(false)
        // notify (so score can be incremented)
        nc.postNotificationName("userMoved", object: self)
        // actually remove the pieces (we happen to know there must be exactly two)
        for piece in self.hilitedPieces {
            self.removePiece(piece)
        }
        self.hilitedPieces.removeAll()
        // game over? if so, notify along with current stage and we're out of here!
        if self.gameOver() {
            delay(0.1) { // added this delay in swift, since I've never like what happens at game end
                ui(true)
                nc.postNotificationName("gameOver", object: self, userInfo: ["stage":self.stage])
            }
            return
        }
        // close up! depends on what stage we are in
        // the following code is really ugly and repetitive, every case being modelled on the same template
        // but C doesn't seem to give me a good way around that; will swift help? find out...
        switch self.stage {
        case 0:
            // no gravity, do nothing
            break
        case 1: // gravity down
            for (var x = 0; x < self.xct; x++) {
                for (var y = self.yct - 1; y > 0; y--) {
                    let piece = self.pieceAt((x,y))
                    if piece == nil {
                        for (var yt = y-1; yt >= 0; yt--) {
                            let piece2 = self.pieceAt((x,yt))
                            if piece2 == nil {
                                continue
                            }
                            self.movePiece(piece2!, to:(x,y))
                            break
                        }
                    }
                }
            }
        case 2: // gravity left
            for (var y = 0; y < self.yct; y++) {
                for (var x = self.xct - 1; x > 0; x--) {
                    let piece = self.pieceAt((x,y))
                    if piece == nil {
                        for (var xt = x-1; xt >= 0; xt--) {
                            let piece2 = self.pieceAt((xt,y))
                            if piece2 == nil {
                                continue
                            }
                            self.movePiece(piece2!, to:(x,y))
                            break
                        }
                    }
                }
            }
        case 3: // gravity toward central horiz line
            let center = self.yct/2 // integer div, deliberate
            // exactly like 1 except we have to do it twice in two directions
            for (var x = 0; x < self.xct; x++) {
                for (var y = center - 1; y > 0; y--) {
                    let piece = self.pieceAt((x,y))
                    if piece == nil {
                        for (var yt = y-1; yt >= 0; yt--) {
                            let piece2 = self.pieceAt((x,yt))
                            if piece2 == nil {
                                continue
                            }
                            self.movePiece(piece2!, to:(x,y))
                            break
                        }
                    }
                }
                for (var y = center; y <= self.yct - 1; y++) {
                    let piece = self.pieceAt((x,y))
                    if piece == nil {
                        for (var yt = y+1; yt < self.yct; yt++) {
                            let piece2 = self.pieceAt((x,yt))
                            if piece2 == nil {
                                continue
                            }
                            self.movePiece(piece2!, to:(x,y))
                            break
                        }
                    }
                }
            }
        case 4: // gravity toward central vertical line
            // exactly like 3 except the other orientation
            let center = self.xct/2 // integer div, deliberate
            for (var y = 0; y < self.yct; y++) {
                for (var x = center-1; x > 0; x--) {
                    let piece = self.pieceAt((x,y))
                    if piece == nil {
                        for (var xt = x-1; xt >= 0; xt--) {
                            let piece2 = self.pieceAt((xt,y))
                            if piece2 == nil {
                                continue
                            }
                            self.movePiece(piece2!, to:(x,y))
                            break
                        }
                    }
                }
                for (var x = center; x <= self.xct - 1; x++) {
                    let piece = self.pieceAt((x,y))
                    if piece == nil {
                        for (var xt = x+1; xt < self.xct; xt++) {
                            let piece2 = self.pieceAt((xt,y))
                            if piece2 == nil {
                                continue
                            }
                            self.movePiece(piece2!, to:(x,y))
                            break
                        }
                    }
                }
            }
        case 5: // gravity away from central horiz line
            // exactly like 3 except we walk from the outside to the center
            let center = self.yct/2 // integer div, deliberate
            for (var x = 0; x < self.xct; x++) {
                for (var y = self.yct-1; y > center; y--) {
                    let piece = self.pieceAt((x,y))
                    if piece == nil {
                        for (var yt = y-1; yt >= center; yt--) {
                            let piece2 = self.pieceAt((x,yt))
                            if piece2 == nil {
                                continue
                            }
                            self.movePiece(piece2!, to:(x,y))
                            break
                        }
                    }
                }
                for (var y = 0; y < center-1; y++) {
                    let piece = self.pieceAt((x,y))
                    if piece == nil {
                        for (var yt = y+1; yt < center; yt++) {
                            let piece2 = self.pieceAt((x,yt))
                            if piece2 == nil {
                                continue
                            }
                            self.movePiece(piece2!, to:(x,y))
                            break
                        }
                    }
                }
            }
        case 6: // gravity away from central vertical line
            // exactly like 4 except we start at the outside
            let center = self.xct/2 // integer div, deliberate
            for (var y = 0; y < self.yct; y++) {
                for (var x = self.xct-1; x > center; x--) {
                    let piece = self.pieceAt((x,y))
                    if piece == nil {
                        for (var xt = x-1; xt >= center; xt--) {
                            let piece2 = self.pieceAt((xt,y))
                            if piece2 == nil {
                                continue
                            }
                            self.movePiece(piece2!, to:(x,y))
                            break
                        }
                    }
                }
                for (var x = 0; x < center-1; x++) {
                    let piece = self.pieceAt((x,y))
                    if piece == nil {
                        for (var xt = x+1; xt < center; xt++) {
                            let piece2 = self.pieceAt((xt,y))
                            if piece2 == nil {
                                continue
                            }
                            self.movePiece(piece2!, to:(x,y))
                            break
                        }
                    }
                }
            }
        case 7: // gravity down in one half, gravity up in the other half
            // like doing 1 in two pieces with the second piece in reverse direction
            let center = self.xct/2;
            for (var x = 0; x < center; x++) {
                for (var y = self.yct - 1; y > 0; y--) {
                    let piece = self.pieceAt((x,y))
                    if piece == nil {
                        for (var yt = y-1; yt >= 0; yt--) {
                            let piece2 = self.pieceAt((x,yt))
                            if piece2 == nil {
                                continue
                            }
                            self.movePiece(piece2!, to:(x,y))
                            break
                        }
                    }
                }
            }
            for (var x = center; x < self.xct; x++) {
                for (var y = 0; y < self.yct-1; y++) {
                    let piece = self.pieceAt((x,y))
                    if piece == nil {
                        for (var yt = y+1; yt < self.yct; yt++) {
                            let piece2 = self.pieceAt((x,yt))
                            if piece2 == nil {
                                continue
                            }
                            self.movePiece(piece2!, to:(x,y))
                            break
                        }
                    }
                }
            }
        case 8: // gravity left in one half, gravity right in other half
            // like doing 2 in two pieces with second in reverse direction
            let center = self.yct/2
            for (var y = 0; y < center; y++) {
                for (var x = self.xct - 1; x > 0; x--) {
                    let piece = self.pieceAt((x,y))
                    if piece == nil {
                        for (var xt = x-1; xt >= 0; xt--) {
                            let piece2 = self.pieceAt((xt,y))
                            if piece2 == nil {
                                continue
                            }
                            self.movePiece(piece2!, to:(x,y))
                            break
                        }
                    }
                }
            }
            for (var y = center; y < self.yct; y++) {
                for (var x = 0; x < self.xct-1; x++) {
                    let piece = self.pieceAt((x,y))
                    if piece == nil {
                        for (var xt = x+1; xt < self.xct; xt++) {
                            let piece2 = self.pieceAt((xt,y))
                            if piece2 == nil {
                                continue
                            }
                            self.movePiece(piece2!, to:(x,y))
                            break
                        }
                    }
                }
            }

        default:
            break
        }
        // animate!
        // and then check for stuck, in the delegate handler for moveMovenda
    
        // slide pieces into their correct place
        // okay, so all the pieces in movenda have the following odd feature:
        // they are internally consistent (they are in the right place in the grid, and they know that place)
        // but they are *physically* in the wrong place
        // thus all we have to do is move them into the right place
        // the big lesson here is that animations run in another thread...
        // so as an animation begins, the interface is refreshed first
        // thus it doesn't matter that we moved the piece into its right place;
        // we also moved the piece back into its wrong place, and that is what the user will see when the animation starts
        // looking at it another way, it is up to us to configure the interface to be right before the start of the animation
        
        UIView.animateWithDuration(0.15, delay: 0.1, options: UIViewAnimationOptions.CurveLinear, animations: {
            while self.movenda.count > 0 {
                let p = self.movenda.removeLast()
                var f = p.frame
                f.origin = self.originOf((p.x, p.y))
                println("Will change frame of piece \(p)")
                println("From \(p.frame)")
                println("To \(f)")
                p.frame = f // this is the move that will be animated
            }
            }, completion: {
                _ in
                self.checkStuck()
                ui(true)
                // we do this after the slide animation is over, so we can get two animations in row, cool
            })
    }
    

    
    // main game logic utility! this is how we know whether two pieces form a legal pair
    // the day I figured out how to do this is the day I realized I could write this game
    // we hand back the legal path joining the pieces, rather than a bool, so that the caller can draw the path
    
    private func checkPair(p1:Piece, and p2:Piece) -> Path? {
        // if not a pair, return nil
        // if a pair, return an array of successive xy positions showing the legal path
        let pt1 = (x:p1.x, y:p1.y)
        let pt2 = (x:p2.x, y:p2.y)
        // 1. first check: are they on the same line with nothing between them?
        if self.lineIsClearFrom(pt1, to:pt2) {
            return [pt1,pt2]
        }
        println("failed straight line test")
        // 2. second check: are they at the corners of a rectangle with nothing on one pair of sides between them?
        let midpt1 = (p1.x, p2.y)
        let midpt2 = (p2.x, p1.y)
        if self.pieceAt(midpt1) == nil {
            if self.lineIsClearFrom(pt1, to:midpt1) && self.lineIsClearFrom(midpt1, to:pt2) {
                return [pt1, midpt1, pt2]
            }
        }
        if self.pieceAt(midpt2) == nil {
            if self.lineIsClearFrom(pt1, to:midpt2) && self.lineIsClearFrom(midpt2, to:pt2) {
                return [pt1, midpt2, pt2]
            }
        }
        println("failed two-segment test")
        // 3. third check: The Way of the Moving Line
        // (this was the algorithmic insight that makes the whole thing possible)
        // connect the x or y coordinates of the pieces by a vertical or horizontal line;
        // move that line through the whole grid including outside the boundaries,
        // and see if all three resulting segments are clear
        // the only drawback with this approach is that if there are multiple paths...
        // we may find a longer one before we find a shorter one, which is counter-intuitive
        // so, accumulate all found paths and submit only the shortest
        var marr = [Path]()
        println("=======")
        func addPathIfValid(midpt1:Point,midpt2:Point) {
            println("about to check triple segment \(pt1) \(midpt1) \(midpt2) \(pt2)")
            // new in swift, reject if same midpoint
            if midpt1.0 == midpt2.0 && midpt1.1 == midpt2.1 {return}
            if self.pieceAt(midpt1) == nil && self.pieceAt(midpt2) == nil {
                if self.lineIsClearFrom(pt1, to:midpt1) &&
                    self.lineIsClearFrom(midpt1, to:midpt2) &&
                    self.lineIsClearFrom(midpt2, to:pt2) {
                        marr.append([pt1,midpt1,midpt2,pt2])
                }
            }
        }
        for y in -1...self.yct {
            addPathIfValid((pt1.x,y),(pt2.x,y))
        }
        for x in -1...self.xct {
            addPathIfValid((x,pt1.y),(x,pt2.y))
        }
        if marr.count > 0 { // got at least one! find the shortest and submit it
            func distance(pt1:Point, pt2:Point) -> Double {
                // utility to learn physical distance between two points (thank you, M. Descartes)
                let deltax = pt1.0 - pt2.0
                let deltay = pt1.1 - pt2.1
                return sqrt(Double(deltax * deltax + deltay * deltay))
            }
            var shortestLength = -1.0
            var shortestPath = Path()
            for thisPath in marr {
                var thisLength = 0.0
                for ix in 0..<(thisPath.count-1) {
                    thisLength += distance(thisPath[ix],thisPath[ix+1])
                }
                if shortestLength < 0 || thisLength < shortestLength {
                    shortestLength = thisLength
                    shortestPath = thisPath
                }
            }
            assert(shortestPath.count > 0, "We must have a path to illuminate by now")
            return shortestPath
        }
        // no dice
        return nil
    }
    
    private func checkHilitedPair () {
        assert(self.hilitedPieces.count == 2, "Must have a pair to check")
        for piece in self.hilitedPieces {
            assert(piece.superview == self.view, "Pieces to check must be displayed on board")
        }
        ui(false)
        let p1 = self.hilitedPieces[0]
        let p2 = self.hilitedPieces[1]
        if p1.picName != p2.picName {
            self.unhilite()
            ui(true)
            return
        }
        if let path = self.checkPair(p1, and:p2) {
            self.removePairAndIlluminatePath(path)
        } else {
            self.unhilite()
        }
        ui(true)
    }
    
    // tab gesture recognizer action handler
    // maintain an ivar pointing to hilited pieces
    // when that list has two items, check them for validity

    @objc private func handleTap(g:UIGestureRecognizer) {
        ui(false)
        let p = g.view as! Piece
        let hilited = p.isHilited
        if !hilited {
            if self.hilitedPieces.count > 1 {
                ui(true)
                return
            }
            self.hilitedPieces += [p]
        } else {
            removeObject(&self.hilitedPieces, p) // see utility at top
        }
        p.toggleHilite()
        if self.hilitedPieces.count == 2 {
            println("========")
            println("about to check hilited pair \(self.hilitedPieces)")
            self.checkHilitedPair()
        }
        ui(true)
    }
    
    // utility to run thru the entire grid and make sure there is at least one legal path somewhere
    // if the path exists, we return NSArray representing path that joins them; otherwise nil
    // that way, the caller can *show* the legal path if desired
    // but caller can treat result as condition as well
    // the path is simply the path returned from checkPair
    
    private func legalPath () -> Path? {
        for x in 0..<self.xct {
            for y in 0..<self.yct {
                let piece = self.pieceAt((x,y))
                if piece == nil {
                    continue
                }
                let picName = piece!.picName
                for xx in 0..<self.xct {
                    for yy in 0..<self.yct {
                        let piece2 = self.pieceAt((xx,yy))
                        if piece2 == nil {
                            continue
                        }
                        if (x == xx && y == yy) {
                            continue
                        }
                        let picName2 = piece2!.picName
                        if picName2 != picName {
                            continue
                        }
                        println("========")
                        println("About to check \(piece!) vs. \(piece2!)")
                        let path = self.checkPair(piece!, and:piece2!)
                        if path == nil {
                            continue
                        }
                        // got one!
                        self.hintPath = path // store so hint can fetch it
                        return path
                    }
                }
            }
        }
        self.hintPath = nil // store so hint can fetch it (should not happen)
        return nil
    }
    
    func hint () {
        let path = self.hintPath // no need to waste time calling legalPath()
        if path != nil {
            self.illuminate(path!)
        }
        else { // just in case hintPath was somehow never set
            let path = self.legalPath()
            if path != nil {
                self.illuminate(path!)
                return
            }
            self.redeal() // should never happen at this point
        }
    }
    

}