import UIKit

/// UILabel that supplies a small right margin. You are expected to set the label's text alignment
/// to be right. Used for the score labels.
final class MyRightLabel: UILabel {
    override func drawText(in rect: CGRect) {
        var rect = rect
        rect.size.width -= 10
        super.drawText(in: rect)
    }
}
