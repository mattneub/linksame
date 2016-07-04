

import UIKit

class MyRightLabel : UILabel {
    override func drawText(in rect: CGRect) {
        var r = rect
        r.size.width -= 10
        super.drawText(in: r)
    }
}
