
import UIKit

func removeObject<T:Equatable>(inout arr:Array<T>, object:T) -> T? {
    if let found = find(arr,object) {
        return arr.removeAtIndex(found)
    }
    return nil
}

class Board : NSObject {
    
    unowned var view: UIView
    var stage = 0
    var showingHint = false
    var hilitedPieces = Piece[]()
    var _xct = 0
    var _yct = 0
    
    init (boardView:UIView) {
        self.view = boardView
        super.init()
    }
    
    func redeal () {
        
    }
    
    func illuminate (arr: NSValue[]) {
        
    }
    
    func unilluminate () {
        
    }
    
    func setGridSizeX(x:Int, y:Int) {
        
    }
    
    func pieceAtX(i:Int, y j:Int) -> AnyObject { // fix me later
        return Piece()
    }
    
    func addPieceAtX(i:Int, y j:Int, withPicture picTitle:String) {
        
    }
    
    func rebuild () {
        
    }
    
    func checkHilitedPair () {
        
    }
    
    func checkPair(p1:Piece, and p2:Piece) -> NSValue[]? {
        return nil
    }
    
    
    // maintain an ivar pointing to hilited pieces
    // when that list has two items, check them for validity

    func handleTap(g:UIGestureRecognizer) {
        let p = g.view as Piece
        let hilited = p.isHilited
        if !hilited {
            if self.hilitedPieces.count > 1 {
                return
            }
            self.hilitedPieces += p
        } else {
            // okay, this is simply horrible
            var hp = (self.hilitedPieces as NSArray).mutableCopy()
            hp.removeObject(p) // but maybe the answer is to implement Equatable for Piece as object identity?
            // yes, I've worked out how to do it, should fix later; see util function at top
            self.hilitedPieces = hp as Piece[]
        }
        p.toggleHilite()
        if self.hilitedPieces.count == 2 {
            self.checkHilitedPair()
        }
    }
    
    // utility to run thru the entire grid and make sure there is at least one legal path somewhere
    // if the path exists, we return NSArray representing path that joins them; otherwise nil
    // that way, the caller can *show* the legal path if desired
    // but caller can treat result as condition as well
    // the path is simply the path returned from checkPair
    
    func legalPath () -> NSValue[]? {
        for x in 0.._xct {
            for y in 0.._yct {
                let pieceMaybe = self.pieceAtX(x, y:y)
                if pieceMaybe is NSNull {
                    continue
                }
                let piece = pieceMaybe as Piece
                let picName = piece.picName
                for xx in 0.._xct {
                    for yy in 0.._yct {
                        let piece2Maybe = self.pieceAtX(xx, y:yy)
                        if piece2Maybe is NSNull {
                            continue
                        }
                        if (x == xx && y == yy) {
                            continue
                        }
                        let piece2 = piece2Maybe as Piece
                        let picName2 = piece2.picName
                        if picName2 != picName {
                            continue
                        }
                        let path = self.checkPair(piece, and:piece2)
                        if !path {
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
    
    func hint () {
        let path = self.legalPath()
        if path {
            self.illuminate(path!)
        }
        else {
            self.redeal() // should never happen at this point
        }
    }

}