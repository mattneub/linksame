import Foundation

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
