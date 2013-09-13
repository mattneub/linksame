
#import <Foundation/Foundation.h>

@interface Board : NSObject <NSCoding> {
    NSArray* grid;
    UIView* view;
    int xct;
    int yct;
    CGSize pieceSize;
    NSMutableArray* hilitedPieces;
    NSMutableArray* movenda;
    NSNumber* stage;
    BOOL showingHint;
}

@property (nonatomic, assign) UIView* view;
@property (nonatomic, retain) NSNumber* stage;
@property (nonatomic, assign) BOOL showingHint;

- (void) setGridSizeX: (int) x Y: (int) y;
- (void) addPieceAtX: (int) i Y: (int) j withPicture: (NSString*) picTitle;
- (void) hint;
- (void) redeal;
- (void) unilluminate;

- (id) initWithBoardView: (UIView*) bv;
- (void) rebuild;

@end
