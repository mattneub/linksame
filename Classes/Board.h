
#import <Foundation/Foundation.h>

@interface Board : NSObject <NSCoding>

@property (nonatomic, weak) UIView* view;
@property (nonatomic, strong) NSNumber* stage;
@property (nonatomic, assign) BOOL showingHint;

- (void) setGridSizeX: (int) x Y: (int) y;
- (void) addPieceAtX: (int) i Y: (int) j withPicture: (NSString*) picTitle;
- (void) hint;
- (void) redeal;
- (void) unilluminate;

- (id) initWithBoardView: (UIView*) bv;
- (void) rebuild;

@end
