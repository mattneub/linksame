
//#import <Foundation/Foundation.h>
@import UIKit;

@interface Board : NSObject <NSCoding>

@property (nonatomic, weak) UIView* view;
@property (nonatomic, strong) NSNumber* stage;
@property (nonatomic, assign) BOOL showingHint;

- (void) setGridSizeX: (NSInteger) x Y: (NSInteger) y;
- (void) addPieceAtX: (NSInteger) i Y: (NSInteger) j withPicture: (NSString*) picTitle;
- (void) hint;
- (void) redeal;
- (void) unilluminate;

- (id) initWithBoardView: (UIView*) bv;
- (void) rebuild;

@end
