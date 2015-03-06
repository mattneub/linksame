

import UIKit

class MyRightLabel : UILabel {
    override func drawTextInRect(rect: CGRect) {
        var r = rect
        r.size.width -= 10
        super.drawTextInRect(r)
    }
}