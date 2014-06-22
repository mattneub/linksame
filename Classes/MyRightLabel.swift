//
//  MyRightLabel.swift
//  LinkSame
//
//  Created by Matt Neuburg on 6/22/14.
//
//

import UIKit

@objc(MyRightLabel) class MyRightLabel : UILabel { // so that old nib can see it
    override func drawTextInRect(rect: CGRect) {
        var r = rect
        r.size.width -= 10
        super.drawTextInRect(r)
    }
}