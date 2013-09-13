

#import <UIKit/UIKit.h>


@interface Piece : UIView <NSCoding> {
    UIImage* pic;
    NSString* picName;
    int x, y;
    BOOL hilite;
}
@property (nonatomic) int x, y;
@property (nonatomic, copy) NSString* picName;
@property (nonatomic, readonly, getter=isHilited) BOOL hilite;

- (void) toggleHilite;

@end
