

#import <UIKit/UIKit.h>


@interface Piece : UIView <NSCoding>

@property (nonatomic, copy) NSString* picName;
@property (nonatomic) int x, y;
@property (nonatomic, readonly, getter=isHilited) BOOL hilite;
- (void) toggleHilite;

@end
