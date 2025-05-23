import Foundation

extension CGRect {
    /// Shorthand for the center point of a rect.
    var center: CGPoint { .init(x: self.midX, y: self.midY) }

    /// Calculate rect of given size, centered at the center of a rect.
    /// - Parameter targetSize: The desired size of the resulting rect.
    /// - Returns: The resulting rect.
    func centeredRectOfSize(_ targetSize: CGSize) -> CGRect {
        let myCenter = self.center
        let xOrigin = myCenter.x - targetSize.width / 2.0
        let yOrigin = myCenter.y - targetSize.height / 2.0
        return CGRect(origin: CGPoint(x: xOrigin, y: yOrigin), size: targetSize)
    }
}
