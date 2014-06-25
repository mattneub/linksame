
import UIKit

class Board : NSObject {
    
    unowned var view: UIView
    var stage = 0
    var showingHint = false
    
    init (boardView:UIView) {
        self.view = boardView
        super.init()
    }
    
    func hint() {
        
    }
    
    func redeal () {
        
    }
    
    func unilluminate () {
        
    }
    
    func setGridSizeX(x:Int, y:Int) {
        
    }
    
    func addPieceAtX(i:Int, y j:Int, withPicture picTitle:String) {
        
    }
    
    func rebuild () {
        
    }
    
    /*
    
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
            self.hilitedPieces.removeObject(p)
        }
        p.toggleHilite()
        if self.hilitedPieces.count == 2 {
            self.checkHilitedPair
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
                let piece = self.pieceAtX(x, Y:y)
                if piece is NSNull {
                    continue
                }
                let picName = piece.picName
                for xx in 0.._xct {
                    for yy in 0.._yct {
                        let piece2 = self.pieceAtX(xx, Y:yy)
                        if piece2 is NSNull {
                            continue
                        }
                        if (x == xx && y == yy) {
                            continue
                        }
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
    
    // public, called by LinkSameViewController to get us to display a legal path
    func hint () {
        let path = self.legalPath()
        if path {
            self.illuminate(path)
        }
        else {
            self.redeal() // should never happen at this point
        }
    }
*/
    
}