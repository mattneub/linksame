
import UIKit
import QuartzCore


fileprivate let TOPMARGIN : CGFloat = (1.0/8.0)
fileprivate let BOTTOMMARGIN : CGFloat = (1.0/8.0)
fileprivate let LEFTMARGIN : CGFloat = (1.0/8.0)
fileprivate let RIGHTMARGIN : CGFloat = (1.0/8.0)
fileprivate var OUTER : CGFloat {
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
    private var grid : [[Piece?]]
    let xct : Int
    let yct : Int
    init(_ x:Int, _ y:Int) {
        self.xct = x
        self.yct = y
        // and now set up the empty grid with nils
        // hold my beer and watch this!
        self.grid = Array(repeating: Array(repeating: nil, count: yct), count: xct)
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

final class Board : NSObject, NSCoding, CALayerDelegate {
    
    typealias Point = (x:Int, y:Int)
    typealias Path = [Point]
    
    let view: UIView
    var stage = 0
    var showingHint : Bool { return self.hintShower.isIlluminating }
    fileprivate var hilitedPieces = [Piece]()
    fileprivate var xct : Int { return self.grid.xct }
    fileprivate var yct : Int { return self.grid.yct }
    fileprivate var grid : Grid // can't live without a grid, but it is mutable
    fileprivate var hintPath : Path?
    fileprivate var deckAtStartOfStage = [String]() // in case we are asked to restore this
    
    // reference to the view that holds the transparency layer
    // we need this so we can switch touch fall-thru on and off
    let pathView : UIView
    // reference to the transparency layer
    fileprivate lazy var pathLayer = self.pathView.layer.sublayers!.last!

    fileprivate lazy var pieceSize : CGSize = {
        // assert(self.view != nil, "Meaningless to ask for piece size with no view.")
        assert((self.xct > 0 && self.yct > 0), "Meaningless to ask for piece size with no grid dimensions.")
        // print("calculating piece size")
        // divide view bounds, allow 1 extra plus margins
        let pieceWidth : CGFloat = self.view.bounds.size.width / (CGFloat(self.xct) + OUTER + LEFTMARGIN + RIGHTMARGIN)
        let pieceHeight : CGFloat = self.view.bounds.size.height / (CGFloat(self.yct) + OUTER + TOPMARGIN + BOTTOMMARGIN)
        return CGSize(width: pieceWidth, height: pieceHeight)
    }()
    
    init (boardFrame:CGRect, gridSize:(Int,Int)) {
        self.view = UIView(frame:boardFrame)
        self.grid = Grid(gridSize.0, gridSize.1) // used to have Grid(gridSize) but now deprecated! :(

        // create the path view; this is where paths will be drawn
        // board will draw directly into its layer using layer delegate's drawLayer:inContext:
        // but we must not set a view's layer's delegate, so we create a sublayer
        let v = UIView(frame: self.view.bounds)
        v.isUserInteractionEnabled = false // clicks just fall right thru
        let lay = CALayer()
        v.layer.addSublayer(lay)
        lay.frame = v.layer.bounds
        self.view.addSubview(v)
        self.pathView = v
        
        super.init()

    }
    
    fileprivate struct CoderKey {
        static let grid = "gridsw"
        static let x = "xctsw"
        static let y = "yctsw"
        static let stage = "stagesw"
        static let size = "piecesizesw"
        static let frame = "framesw"
    }
    
    func encode(with coder: NSCoder) {
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
        coder.encode(saveableGrid, forKey: CoderKey.grid)
        coder.encode(self.xct, forKey: CoderKey.x)
        coder.encode(self.yct, forKey: CoderKey.y)
        coder.encode(self.stage, forKey: CoderKey.stage)
        coder.encode(self.pieceSize, forKey: CoderKey.size)
        coder.encode(self.view.frame, forKey: CoderKey.frame)
    }
    
    // little-known fact: you have to implement init(coder:), but no law says it cannot be a convenience initializer!
    // thus we can eliminate repetition by calling the other initializer
    
    required convenience init(coder: NSCoder) {
        let xct = coder.decodeInteger( forKey: CoderKey.x )
        let yct = coder.decodeInteger( forKey: CoderKey.y )
        let frame = coder.decodeCGRect( forKey: CoderKey.frame )
        self.init(boardFrame:frame, gridSize:(xct,yct))
        
        self.stage = coder.decodeInteger( forKey: CoderKey.stage )
        self.pieceSize = coder.decodeCGSize( forKey: CoderKey.size )
        
        var flatGrid = coder.decodeObject( forKey: CoderKey.grid ) as! [String]
        for i in 0 ..< self.xct {
            for j in 0 ..< self.yct {
                let picname = flatGrid.remove(at: 0)
                if !picname.isEmpty {
                    self.addPieceAt((i,j), withPicture: picname)
                }
            }
        }
        self.hintPath = self.legalPath() // generate initial hint
    }
    
    func createAndDealDeck() {
        // determine which pieces to use
        let (start1,start2) = Styles.pieces(ud.string(forKey: Default.style)!)
        // create deck of piece names
        var deck = [String]()
        for _ in 0..<4 {
            for i in start1..<start1+9 {
                deck += [String(i)]
            }
        }
        // determine which additional pieces to use, finish deck of piece names
        let (w,h) = (self.xct, self.yct)
        let howmany : Int = ((w * h) / 4) - 9
        for _ in 0..<4 {
            for i in start2..<start2+howmany {
                deck += [String(i)]
            }
        }
        for _ in 0..<4 {
            deck.shuffle()
        }
        
        // store a copy so we can restart the stage if we have to
        self.deckAtStartOfStage = deck
        
        // create actual pieces and we're all set!
        for i in 0..<w {
            for j in 0..<h {
                self.addPieceAt((i,j), withPicture: deck.removeLast()) // heh heh, pops and returns
            }
        }
        
        self.hintPath = self.legalPath() // generate initial hint
    }
    
    func restartStage() {
        // deal stored deck; we have to remove existing pieces as we go
        var deck = self.deckAtStartOfStage
        for i in 0..<self.xct {
            for j in 0..<self.yct {
                if let oldPiece = self.piece(at:(i,j)) {
                    self.removePiece(oldPiece)
                }
                self.addPieceAt((i,j), withPicture: deck.removeLast()) // heh heh, pops and returns
            }
        }
        self.hintPath = self.legalPath() // generate initial hint
    }


    func redeal () {
        repeat {
            ui(false)
            // gather up all pieces (as names), shuffle them, deal them into their current slots
            var deck = [String]()
            for i in 0 ..< self.xct {
                for j in 0 ..< self.yct {
                    let piece = self.piece(at:(i,j))
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
                    let piece = self.piece(at:(i,j))
                    if let piece = piece {
                        // very lightweight; we just assign the name, let the piece worry about the picture
                        UIView.transition(
                            with: piece, duration: 0.7, options: .transitionFlipFromLeft, animations: {
                                piece.picName = deck.removeLast()
                                piece.setNeedsDisplay()
                        })
                    }
                }
            }
        } while self.legalPath() == nil
    }
    
    
    // okay, so previously I had this functionality spread over two methods
    // board illuminate() and unilluminate(), plus remembering to set the state property
    // plus I was skankily handing the path to draw into the layer itself
    // that is just the kind of thing I wanted to clean up
    // so I put it all into a little helper class
    class LegalPathShower : NSObject, CALayerDelegate {
        unowned private var board : Board
        init(board:Board) {self.board = board}
        private var pathToIlluminate : Path?
        private(set) var isIlluminating = false {
            didSet {
                switch self.isIlluminating {
                case false:
                    self.pathToIlluminate = nil
                    self.board.pathView.isUserInteractionEnabled = false // make touches just fall thru once again
                    self.board.pathLayer.setNeedsDisplay()
                case true:
                    self.board.pathLayer.delegate = self // tee-hee
                    self.board.pathView.isUserInteractionEnabled = true // block touches
                    self.board.pathLayer.setNeedsDisplay()
                }
            }
        }
        deinit {
            // self.board.pathLayer.delegate = nil // crucial or we can crash
        }
        func illuminate(path:Path) {
            self.pathToIlluminate = path
            self.isIlluminating = true
        }
        func unilluminate() {
            self.isIlluminating = false
        }
        func draw(_ layer: CALayer, in con: CGContext) {
            self.draw(intoIlluminationContext: con)
        }
        private func draw(intoIlluminationContext con: CGContext) {
            // if no path, do nothing, thus causing the layer to become empty
            guard let arr = self.pathToIlluminate else {return}
            // okay, we have a path
            // connect the dots; however, the dots we want to connect are the *centers* of the pieces...
            // whereas we are given piece *origins*, so calculate offsets
            let sz = self.board.pieceSize
            let offx = sz.width/2.0
            let offy = sz.height/2.0
            con.setLineJoin(.round)
            con.setStrokeColor(red: 0.4, green: 0.4, blue: 1.0, alpha: 1.0)
            con.setLineWidth(3.0)
            con.beginPath()
            con.addLines(between: arr.map {piece in
                let origin = self.board.originOf(piece)
                return CGPoint(x: origin.x + offx, y: origin.y + offy)
            })
            con.strokePath()
        }
    }
    
    lazy var hintShower = LegalPathShower(board:self)
    
    fileprivate func piece(at p:Point) -> Piece? {
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
    
    fileprivate func addPieceAt(_ p:Point, withPicture picTitle:String) {
        let sz = self.pieceSize
        let orig = self.originOf(p)
        let f = CGRect(origin: orig, size: sz)
        let piece = Piece(picName:picTitle, frame:f)
        // place the Piece in the interface
        // we are conscious that we must not accidentally draw on top of the transparency view
        self.view.insertSubview(piece, belowSubview: self.pathView)
        // also place the Piece in the grid, and tell it where it is
        let (i,j) = p
        self.grid[i][j] = piece
        (piece.x, piece.y) = (i,j)
        // print("Point was \(p), pic was \(picTitle)\nCreated \(piece)")
        // set up tap detection
        let t = UITapGestureRecognizer(target: self, action: #selector(handleTap))
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
    
    // utility to determine whether the line from p1 to p2 consists entirely of nil
    
    fileprivate func lineIsClearFrom(_ p1:(x:Int,y:Int), to p2:(x:Int,y:Int)) -> Bool {
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
                if self.piece(at:(p1.x,i)) != nil {
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
                if self.piece(at:(i,p1.y)) != nil {
                    return false
                }
            }
        }
        return true
    }
    
    // utility to remove a piece from the interface and from the grid (i.e. replace it by nil)
    // no more NSNull!
    
    fileprivate func removePiece(_ p:Piece) {
        self.grid[p.x][p.y] = nil
        p.removeFromSuperview()
    }
    
    // utility to learn whether the grid is empty, indicating that the game is over
    
    fileprivate func gameOver () -> Bool {
        // return true // testing game end
        for x in 0..<self.xct {
            for y in 0..<self.yct {
                if self.piece(at:(x,y)) != nil {
                    return false
                }
            }
        }
        return true
    }
    
    // given a piece's place in the grid, where should it be physically drawn on the view?
    
    fileprivate func originOf(_ p:Point) -> CGPoint {
        let (i,j) = p
        assert(i >= -1 && i <= self.xct, "Position requested out of bounds (x)")
        assert(j >= -1 && j <= self.yct, "Position requested out of bounds (y)")
        // divide view bounds, allow 2 extra on all sides
        let pieceWidth = self.pieceSize.width
        let pieceHeight = self.pieceSize.height
        let x = ((OUTER/2.0 + LEFTMARGIN) * pieceWidth) + (CGFloat(i) * pieceWidth)
        let y = ((OUTER/2.0 + TOPMARGIN) * pieceHeight) + (CGFloat(j) * pieceHeight) + (onPhone ? 0 : 64/2) // allow for toolbar
        return CGPoint(x: x,y: y)

    }
    
    fileprivate func reallyRemovePair () {
        var movenda = [Piece]() // we will maintain a list of all pieces that need to animate a position change
        // utility to prepare pieces for position change
        // configure the piece internally and grid-wise for its new position, 
        // but keep it physically in the old position
        // store it in movenda so we can animate it into its new position at the end of this method
        func movePiece(_ p:Piece, to newPoint:(Int,Int)) {
            assert(self.piece(at:newPoint) == nil, "Slot to move piece to must be empty")
            // move the piece within the *grid*
            let s = p.picName
            let oldFrame = p.frame
            self.removePiece(p)
            self.addPieceAt(newPoint, withPicture:s)
            // however, we are not yet redrawn, so now...
            // return piece to its previous position! but add to movenda
            // later we will animate it into correct position
            let pnew = self.piece(at:newPoint)!
            pnew.frame = oldFrame
            movenda += [pnew]
        }

        ui(false)
        // notify (so score can be incremented)
        nc.post(name: .userMoved, object: self)
        // actually remove the pieces (we happen to know there must be exactly two)
        for piece in self.hilitedPieces {
            self.removePiece(piece)
        }
        self.hilitedPieces.removeAll()
        // game over? if so, notify along with current stage and we're out of here!
        if self.gameOver() {
            delay(0.1) { // added this delay in swift, since I've never like what happens at game end
                ui(true)
                nc.post(name: .gameOver, object: self, userInfo: ["stage":self.stage])
            }
            return
        }
        // close up! depends on what stage we are in
        // the following code is really ugly and repetitive, every case being modelled on the same template
        // but C doesn't seem to give me a good way around that; will swift help? find out...
        switch self.stage {
        case 0: // no gravity, do nothing
            // fallthrough // debugging later cases
            break
        case 1: // gravity down
            // fallthrough // debugging later cases
            // for (var x = 0; x < self.xct; x++) {
            for x in 0..<self.xct {
                // for (var y = self.yct - 1; y > 0; y--) {
                for y in self.yct>>>0 { // not an exact match for my original C version, but simpler
                    let piece = self.piece(at:(x,y))
                    if piece == nil {
                        // for (var yt = y-1; yt >= 0; yt--) {
                        for yt in y>>>0 {
                            let piece2 = self.piece(at:(x,yt))
                            if piece2 == nil {
                                continue
                            }
                            movePiece(piece2!, to:(x,y))
                            break
                        }
                    }
                }
            }
        case 2: // gravity right
            // fallthrough // debugging later cases
            // for (var y = 0; y < self.yct; y++) {
            for y in 0..<self.yct {
                // for (var x = self.xct - 1; x > 0; x--) {
                for x in self.xct>>>0 {
                    let piece = self.piece(at:(x,y))
                    if piece == nil {
                        // for (var xt = x-1; xt >= 0; xt--) {
                        for xt in x>>>0 {
                            let piece2 = self.piece(at:(xt,y))
                            if piece2 == nil {
                                continue
                            }
                            movePiece(piece2!, to:(x,y))
                            break
                        }
                    }
                }
            }
        case 3: // gravity toward central horiz line
            // fallthrough // debugging later cases
            let center = self.yct/2 // integer div, deliberate
            // exactly like 1 except we have to do it twice in two directions
            // for (var x = 0; x < self.xct; x++) {
            for x in 0..<self.xct {
                // for (var y = center - 1; y > 0; y--) {
                for y in center>>>0 {
                    let piece = self.piece(at:(x,y))
                    if piece == nil {
                        // for (var yt = y-1; yt >= 0; yt--) {
                        for yt in y>>>0 {
                            let piece2 = self.piece(at:(x,yt))
                            if piece2 == nil {
                                continue
                            }
                            movePiece(piece2!, to:(x,y))
                            break
                        }
                    }
                }
                // for (var y = center; y <= self.yct - 1; y++) {
                for y in center..<self.yct {
                    let piece = self.piece(at:(x,y))
                    if piece == nil {
                        // for (var yt = y+1; yt < self.yct; yt++) {
                        for yt in y+1..<self.yct {
                            let piece2 = self.piece(at:(x,yt))
                            if piece2 == nil {
                                continue
                            }
                            movePiece(piece2!, to:(x,y))
                            break
                        }
                    }
                }
            }
        case 4: // gravity toward central vertical line
            // fallthrough // debugging later cases
            // exactly like 3 except the other orientation
            let center = self.xct/2 // integer div, deliberate
            // for (var y = 0; y < self.yct; y++) {
            for y in 0..<self.yct {
                // for (var x = center-1; x > 0; x--) {
                for x in center>>>0 {
                    let piece = self.piece(at:(x,y))
                    if piece == nil {
                        // for (var xt = x-1; xt >= 0; xt--) {
                        for xt in x>>>0 {
                            let piece2 = self.piece(at:(xt,y))
                            if piece2 == nil {
                                continue
                            }
                            movePiece(piece2!, to:(x,y))
                            break
                        }
                    }
                }
                // for (var x = center; x <= self.xct - 1; x++) {
                for x in center..<self.xct {
                    let piece = self.piece(at:(x,y))
                    if piece == nil {
                        // for (var xt = x+1; xt < self.xct; xt++) {
                        for xt in x+1..<self.xct {
                            let piece2 = self.piece(at:(xt,y))
                            if piece2 == nil {
                                continue
                            }
                            movePiece(piece2!, to:(x,y))
                            break
                        }
                    }
                }
            }
        case 5: // gravity away from central horiz line
            // fallthrough // debugging later cases
            // exactly like 3 except we walk from the outside to the center
            let center = self.yct/2 // integer div, deliberate
            // for (var x = 0; x < self.xct; x++) {
            for x in 0..<self.xct {
                // for (var y = self.yct-1; y > center; y--) {
                for y in self.yct>>>center { // not identical to C loop, moved pivot
                    let piece = self.piece(at:(x,y))
                    if piece == nil {
                        // for (var yt = y-1; yt >= center; yt--) {
                        for yt in y>>>center {
                            let piece2 = self.piece(at:(x,yt))
                            if piece2 == nil {
                                continue
                            }
                            movePiece(piece2!, to:(x,y))
                            break
                        }
                    }
                }
                // for (var y = 0; y < center-1; y++) {
                for y in 0..<center {
                    let piece = self.piece(at:(x,y))
                    if piece == nil {
                        // for (var yt = y+1; yt < center; yt++) {
                        for yt in y+1..<center {
                            let piece2 = self.piece(at:(x,yt))
                            if piece2 == nil {
                                continue
                            }
                            movePiece(piece2!, to:(x,y))
                            break
                        }
                    }
                }
            }
        case 6: // gravity away from central vertical line
            // fallthrough // debugging later cases
            // exactly like 4 except we start at the outside
            let center = self.xct/2 // integer div, deliberate
            // for (var y = 0; y < self.yct; y++) {
            for y in 0..<self.yct {
                // for (var x = self.xct-1; x > center; x--) {
                for x in self.xct>>>center {
                    let piece = self.piece(at:(x,y))
                    if piece == nil {
                        // for (var xt = x-1; xt >= center; xt--) {
                        for xt in x>>>center {
                            let piece2 = self.piece(at:(xt,y))
                            if piece2 == nil {
                                continue
                            }
                            movePiece(piece2!, to:(x,y))
                            break
                        }
                    }
                }
                // for (var x = 0; x < center-1; x++) {
                for x in 0..<center {
                    let piece = self.piece(at:(x,y))
                    if piece == nil {
                        // for (var xt = x+1; xt < center; xt++) {
                        for xt in x..<center { // not identical
                            let piece2 = self.piece(at:(xt,y))
                            if piece2 == nil {
                                continue
                            }
                            movePiece(piece2!, to:(x,y))
                            break
                        }
                    }
                }
            }
        case 7: // gravity down in one half, gravity up in the other half
            // fallthrough // debugging later cases
            // like doing 1 in two pieces with the second piece in reverse direction
            let center = self.xct/2;
            // for (var x = 0; x < center; x++) {
            for x in 0..<center {
                // for (var y = self.yct - 1; y > 0; y--) {
                for y in self.yct>>>0 {
                    let piece = self.piece(at:(x,y))
                    if piece == nil {
                        // for (var yt = y-1; yt >= 0; yt--) {
                        for yt in y>>>0 {
                            let piece2 = self.piece(at:(x,yt))
                            if piece2 == nil {
                                continue
                            }
                            movePiece(piece2!, to:(x,y))
                            break
                        }
                    }
                }
            }
            // for (var x = center; x < self.xct; x++) {
            for x in center..<self.xct {
                // for (var y = 0; y < self.yct-1; y++) {
                for y in 0..<self.yct {
                    let piece = self.piece(at:(x,y))
                    if piece == nil {
                        // for (var yt = y+1; yt < self.yct; yt++) {
                        for yt in y..<self.yct {
                            let piece2 = self.piece(at:(x,yt))
                            if piece2 == nil {
                                continue
                            }
                            movePiece(piece2!, to:(x,y))
                            break
                        }
                    }
                }
            }
        case 8: // gravity left in one half, gravity right in other half
            // like doing 2 in two pieces with second in reverse direction
            let center = self.yct/2
            // for (var y = 0; y < center; y++) {
            for y in 0..<center {
                // for (var x = self.xct - 1; x > 0; x--) {
                for x in self.xct>>>0 {
                    let piece = self.piece(at:(x,y))
                    if piece == nil {
                        // for (var xt = x-1; xt >= 0; xt--) {
                        for xt in x>>>0 {
                            let piece2 = self.piece(at:(xt,y))
                            if piece2 == nil {
                                continue
                            }
                            movePiece(piece2!, to:(x,y))
                            break
                        }
                    }
                }
            }
            // for (var y = center; y < self.yct; y++) {
            for y in center..<self.yct {
                // for (var x = 0; x < self.xct-1; x++) {
                for x in 0..<self.xct {
                    let piece = self.piece(at:(x,y))
                    if piece == nil {
                        // for (var xt = x+1; xt < self.xct; xt++) {
                        for xt in x..<self.xct {
                            let piece2 = self.piece(at:(xt,y))
                            if piece2 == nil {
                                continue
                            }
                            movePiece(piece2!, to:(x,y))
                            break
                        }
                    }
                }
            }

        default:
            break
        }
        
        // animate!
        // and then check for stuck
    
        // slide pieces into their correct place
        // okay, so all the pieces in movenda have the following odd feature:
        // they are internally consistent (they are in the right place in the grid, and they know that place)
        // but they are *physically* in the wrong place
        // thus all we have to do is move them visibly into the right place
        // the big lesson here is that animations run in another thread...
        // so as an animation begins, the interface is refreshed first
        // thus it doesn't matter that we moved the piece into its right place;
        // we also moved the piece back into its wrong place, 
        // and that is what the user will see when the animation starts
        
        UIView.animate(withDuration: 0.15, delay: 0.1, options: .curveLinear, animations: {
            while movenda.count > 0 {
                let p = movenda.removeLast()
                var f = p.frame
                f.origin = self.originOf((p.x, p.y))
                // print("Will change frame of piece \(p)")
                // print("From \(p.frame)")
                // print("To \(f)")
                p.frame = f // this is the move that will be animated
            }
        }, completion: { _ in
            self.hintPath = self.legalPath() // okay, assess the situation; either way, we need a new hint ready
            if self.hintPath == nil {
                self.redeal()
            }
            // we do this after the slide animation is over, so we can get two animations in row, cool
            ui(true)
        })
    }
    

    
    // main game logic utility! this is how we know whether two pieces form a legal pair
    // the day I figured out how to do this is the day I realized I could write this game
    // we hand back the legal path joining the pieces, rather than a bool, so that the caller can draw the path
    
    fileprivate func checkPair(_ p1:Piece, and p2:Piece) -> Path? {
        // if not a pair, return nil
        // if a pair, return an array of successive xy positions showing the legal path
        let pt1 : Point = (x:p1.x, y:p1.y)
        let pt2 : Point = (x:p2.x, y:p2.y)
        // 1. first check: are they on the same line with nothing between them?
        if self.lineIsClearFrom(pt1, to:pt2) {
            return [pt1,pt2]
        }
        // print("failed straight line test")
        // 2. second check: are they at the corners of a rectangle with nothing on one pair of sides between them?
        let midpt1 : Point = (p1.x, p2.y)
        let midpt2 : Point = (p2.x, p1.y)
        if self.piece(at:midpt1) == nil {
            if self.lineIsClearFrom(pt1, to:midpt1) && self.lineIsClearFrom(midpt1, to:pt2) {
                return [pt1, midpt1, pt2]
            }
        }
        if self.piece(at:midpt2) == nil {
            if self.lineIsClearFrom(pt1, to:midpt2) && self.lineIsClearFrom(midpt2, to:pt2) {
                return [pt1, midpt2, pt2]
            }
        }
        // print("failed two-segment test")
        // 3. third check: The Way of the Moving Line
        // (this was the algorithmic insight that makes the whole thing possible)
        // connect the x or y coordinates of the pieces by a vertical or horizontal line;
        // move that line through the whole grid including outside the boundaries,
        // and see if all three resulting segments are clear
        // the only drawback with this approach is that if there are multiple paths...
        // we may find a longer one before we find a shorter one, which is counter-intuitive
        // so, accumulate all found paths and submit only the shortest
        var marr = [Path]()
        // print("=======")
        func addPathIfValid(_ midpt1:Point, _ midpt2:Point) {
            // print("about to check triple segment \(pt1) \(midpt1) \(midpt2) \(pt2)")
            // new in swift, reject if same midpoint
            if midpt1.0 == midpt2.0 && midpt1.1 == midpt2.1 {return}
            if self.piece(at:midpt1) == nil && self.piece(at:midpt2) == nil {
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
            func distance(_ pt1:Point, _ pt2:Point) -> Double {
                // utility to learn physical distance between two points (thank you, M. Descartes)
                let deltax = pt1.0 - pt2.0
                let deltay = pt1.1 - pt2.1
                return Double(deltax * deltax + deltay * deltay).squareRoot()
            }
            var shortestLength = -1.0
            var shortestPath = Path()
            for thisPath in marr {
                var thisLength = 0.0
                for ix in thisPath.indices.dropLast() {
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
    
    fileprivate func checkHilitedPair () {
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
            // flash the path and remove the two pieces
            self.hintShower.illuminate(path:path)
            delay(0.2) {
                self.hintShower.unilluminate()
                delay(0.1) {
                    ui(true)
                    self.reallyRemovePair()
                }
            }
        } else {
            ui(true)
            self.unhilite()
        }
    }
    
    // tap gesture recognizer action handler
    // maintain an ivar pointing to hilited pieces
    // when that list has two items, check them for validity

    @objc fileprivate func handleTap(_ g:UIGestureRecognizer) {
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
            self.hilitedPieces.remove(object:p) // see utility at top
        }
        p.toggleHilite()
        if self.hilitedPieces.count == 2 {
            // print("========")
            // print("about to check hilited pair \(self.hilitedPieces)")
            ui(true)
            self.checkHilitedPair()
        } else {
            ui(true)
        }
    }
    
    // utility to run thru the entire grid and make sure there is at least one legal path somewhere
    // if the path exists, we return NSArray representing path that joins them; otherwise nil
    // that way, the caller can *show* the legal path if desired
    // but caller can treat result as condition as well
    // the path is simply the path returned from checkPair
    
    fileprivate func legalPath () -> Path? {
        for x in 0..<self.xct {
            for y in 0..<self.yct {
                let piece = self.piece(at:(x,y))
                if piece == nil {
                    continue
                }
                let picName = piece!.picName
                for xx in 0..<self.xct {
                    for yy in 0..<self.yct {
                        let piece2 = self.piece(at:(xx,yy))
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
                        // print("========")
                        // print("About to check \(piece!) vs. \(piece2!)")
                        let path = self.checkPair(piece!, and:piece2!)
                        if path == nil {
                            continue
                        }
                        // got one!
                        return path
                    }
                }
            }
        }
        return nil
    }
    
    // public, called by LinkSameViewController to ask us to display hint
    func hint () {
        // no need to waste time calling legalPath(); path is ready (or not) in hintPath
        if let path = self.hintPath {
            self.hintShower.illuminate(path:path)
        } else { // this part shouldn't happen, but just in case, waste time after all
            self.hintPath = self.legalPath()
            if self.hintPath != nil {
                self.hint() // try again, and this time we'll succeed
            } else {
                self.redeal() // should _really_ never happen, but just in case
            }
        }
    }
    
    // public, for the same reason: if LinkSameViewController tells us to hint,
    // we stay hinted until we are told to unhint
    func unhint () {
        self.hintShower.unilluminate()
    }

    deinit {
        self.pathLayer.delegate = nil // take no chances
        print("farewell from board")
    }
    

}
