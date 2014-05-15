//
//  MyRightLabel.m
//  LinkSame
//
//  Created by Matt Neuburg on 5/14/14.
//
//

#import "MyRightLabel.h"

@implementation MyRightLabel

// pad right side; otherwise, the shadow is clipped

-(void)drawTextInRect:(CGRect)rect {
    CGRect r = rect;
    r.size.width -= 10;
    [super drawTextInRect:r];
}

@end
