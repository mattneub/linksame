/*
 
 The Board is the game logic and interface control workhorse (pure model-controller).
 It consists of a grid (array of array) of Pieces; it also places those Pieces on the view.
 It is responsible for piece tap detection, for momentary display of paths in the transparency layer,
 and for deciding what to do after a tap (and doing it).
 It knows nothing of the LinkSameViewController; it communicates back via notification when a stage ends.
 
 A new Board object is created for every stage.
 
 */

#import "Board.h"
#import "Piece.h"
#import "MutableArrayCategories.h"

@interface Board (){
    
    int _xct;
    int _yct;
    CGSize _pieceSize;
    
    
}

@property (nonatomic, strong) NSArray* grid;
@property (nonatomic, strong) NSMutableArray* hilitedPieces;
@property (nonatomic, strong) NSMutableArray* movenda;


@end

@implementation Board

- (id) initWithBoardView: (UIView*) bv {
    self = [super init];
    if (self) {
        _hilitedPieces = [[NSMutableArray alloc] init];
        _movenda = [[NSMutableArray alloc] init];
        _view = bv;
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super init];
    _hilitedPieces = [[NSMutableArray alloc] init];
    _movenda = [[NSMutableArray alloc] init];
    _grid = [coder decodeObjectForKey: @"grid"];
    _xct = [coder decodeIntForKey:@"xct"];
    _yct = [coder decodeIntForKey:@"yct"];
    _stage = [coder decodeObjectForKey:@"stage"];
    // board is not actually ready rock and roll...
    // ...but we must wait until we are told to rebuild
    return self;
}

- (void) rebuild {
    NSAssert(_hilitedPieces && _movenda && _grid && _xct && _yct && _stage,
             @"Meaningless to ask to rebuild when we are not initialized from coder");
    NSAssert(_view, @"Meaningless to ask to rebuild when we have no view");
    for (int i=0; i<_xct; i++) {
        for (int j=0; j<_yct; j++) {
            id piece = [self pieceAtX:i Y:j];
            if (piece == [NSNull null])
                continue;
            // simply remove piece and restore it, causing it to appear in view
            // removePiece will attempt to remove from superview and fail, but no penalty
            [self removePieceAtX:i Y:j];
            [self addPieceAtX:i Y:j withPicture:[piece picName]];
        }
    }
}


- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.grid forKey: @"grid"];
    [coder encodeInt:_xct forKey:@"xct"];
    [coder encodeInt:_yct forKey:@"yct"];
    [coder encodeObject:self.stage forKey:@"stage"];
}    


- (void) redeal {
    // takes time, turn off interactions
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    do {
        // gather up all pieces (as names), shuffle them, deal them into their current slots
        NSMutableArray* deck = [NSMutableArray array];
        for (int i=0; i<_xct; i++) {
            for (int j=0; j<_yct; j++) {
                id piece = [self pieceAtX:i Y:j];
                if (piece == [NSNull null])
                    continue;
                [deck addObject:[(Piece*)piece picName]];
            }
        }
        [deck shuffle];
        [deck shuffle];
        [deck shuffle];
        [deck shuffle];
        for (int i=0; i<_xct; i++) {
            for (int j=0; j<_yct; j++) {
                id piece = [self pieceAtX:i Y:j];
                if (piece == [NSNull null])
                    continue;
                // very lightweight; we just assign the name, let the Piece worry about the picture
                ((Piece*)piece).picName = [deck lastObject];
                [deck removeLastObject];
                [UIView beginAnimations:nil context:NULL];
                [UIView setAnimationDuration:0.7];
                [UIView setAnimationTransition:UIViewAnimationTransitionFlipFromRight forView:piece cache:YES];
                [piece setNeedsDisplay]; // important, piece won't be redrawn otherwise
                [UIView commitAnimations];
            }
        }
    } while (![self legalPath]); // guarantee that this deal results in legal position
    [[UIApplication sharedApplication] performSelector:@selector(endIgnoringInteractionEvents) withObject:nil afterDelay:0.8];
}

// initialize the grid model and store info about its dimensions
// originally I imagined that it might be possible to reset the grid size
// but in fact this now never happens, because a new Board object is created any time a new stage is created
// it is LinkSameView's responsibility to initialize us with a grid size the instant we are created

- (void) setGridSizeX: (int) x Y: (int) y {
     // otiose, since in fact there was never a previous grid
    // the grid is just an array of arrays
    // think of every entry in the grid as a "slot"
    // then every slot is filled either by a piece or by NSNull
    NSMutableArray* outer = [[NSMutableArray alloc] init];
    for (int i=0; i<x; i++) {
        NSMutableArray* inner = [[NSMutableArray alloc] init];
        for (int j=0; j<y; j++)
            [inner addObject: [NSNull null]];
        [outer addObject: inner];
    }
    self.grid = [outer copy];
    // remember dimensions
    self->_xct = x;
    self->_yct = y;
}

// utilities about where to draw a piece

// there is (from outside in) a thin margin, then a one-piece margin, then the grid of drawn pieces
// we need the one-piece margin because we have to be able to draw paths in it

#define TOPMARGIN (1.0/8.0)
#define BOTTOMMARGIN (1.0/8.0)
#define LEFTMARGIN (1.0/8.0)
#define RIGHTMARGIN (1.0/8.0)

- (CGSize) pieceSize {
    NSAssert(self.view, @"Meaningless to ask for piece size with no view.");
    NSAssert((_xct > 0 && _yct > 0), @"Meaningless to ask for piece size with no grid dimensions.");
    // memoize piece size as an ivar
    // you may ask why I didn't just set the piece size when I set the grid
    // this actually feels neater, though
    if (!self->_pieceSize.width) {
        // divide view bounds, allow 1 extra plus margins
        CGFloat pieceWidth, pieceHeight;
        pieceWidth = self.view.bounds.size.width / (_xct + 2.0 + LEFTMARGIN + RIGHTMARGIN);
        pieceHeight = self.view.bounds.size.height / (_yct + 2.0 + TOPMARGIN + BOTTOMMARGIN);
        self->_pieceSize = CGSizeMake(pieceWidth, pieceHeight);
    }
    return self->_pieceSize;
}

// given a piece's place in the grid, where should it be physically drawn on the view?

- (CGPoint) originOfX: (int) i Y: (int) j {
    NSAssert(self.view, @"Meaningless to ask for piece position with no view.");
    // it is legal to ask for position one slot outside the boundaries
    NSAssert(i >= -1 && i <= _xct, @"Position requested out of bounds (x)");
    NSAssert(j >= -1 && j <= _yct, @"Position requested out of bounds (y)");
    // divide view bounds, allow 2 extra on all sides
    CGFloat pieceWidth = [self pieceSize].width;
    CGFloat pieceHeight = [self pieceSize].height;
    CGFloat x = ((1.0 + LEFTMARGIN) * pieceWidth) + (i * pieceWidth);
    CGFloat y = ((1.0 + TOPMARGIN) * pieceHeight) + (j * pieceHeight);
    return CGPointMake(x,y);
}

// public interface for putting a piece in a slot

- (void) addPieceAtX: (int) i Y: (int) j withPicture: (NSString*) picTitle {
    // make the Piece, setting its frame so it will be drawn in the right place
    CGSize sz = [self pieceSize];
    CGPoint orig = [self originOfX: i Y: j];
    CGRect f = { orig, sz };
    Piece* piece = [[Piece alloc] initWithFrame:f];
    piece.picName = picTitle;
    // place the Piece in the interface
    // we are conscious of the fact that we must not accidentally draw on top of the transparency view
    [self.view insertSubview:piece belowSubview:[self.view viewWithTag:999]];
    // also place the Piece in the grid, and tell it where it is
    ((NSMutableArray*)(self.grid)[i])[j] = piece;
    piece.x = i; piece.y = j;
    // set up tap detections so we are notified when a Piece is tapped
    UITapGestureRecognizer* t = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    [piece addGestureRecognizer:t];
    // wow, that was easy
}

- (id) pieceAtX: (int) i Y: (int) j {
    // it is legal to ask for piece one slot outside the boundaries (but not further outside)
    NSAssert(i >= -1 && i <= _xct, @"Piece requested out of bounds (x)");
    NSAssert(j >= -1 && j <= _yct, @"Piece requested out of bounds (y)");
    // report slot outside boundaries as empty
    if (i == -1 || i == _xct) return [NSNull null];
    if (j == -1 || j == _yct) return [NSNull null];
    // report actual value within boundaries
    return ((NSMutableArray*)(self.grid)[i])[j];
}

// this code is no longer used, because instead of drawing into a bitmap we now draw directly into a layer context
// however, I'm leaving it here because it worked, and I will want an example of how to do this later on
// however however, I later learned that this code is unnecessary! the simple approach is to call UIGraphicsBeginImageContext
// you then fetch the current context, draw, and call UIGraphicsGetImageFromCurrentImageContext to extract the bitmap as an image 
CGContextRef MyCreateBitmapContext (int pixelsWide, int pixelsHigh) {
    // almost directly from Apple's example code
    int bitmapBytesPerRow = (pixelsWide * 4);
    int bitmapByteCount = (bitmapBytesPerRow * pixelsHigh);
    
    void* bitmapData = malloc(bitmapByteCount);
    if (!bitmapData)
        return NULL;
    CGContextRef context = NULL;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    context = CGBitmapContextCreate (bitmapData,
                                     pixelsWide,
                                     pixelsHigh,
                                     8,
                                     bitmapBytesPerRow,
                                     colorSpace,
                                     kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(colorSpace);
    if (!context) {
        free (bitmapData);
        return NULL;
    }
    return context;
}

// this is the actual path drawing code
// we are the delegate of the transparency layer so we are called when the layer is told it needs redrawing
// thus we are handed a context and we can just draw directly into it
// the layer is holding an array that tells us what path to draw

- (void) drawLayer:(CALayer *)layer inContext:(CGContextRef)con {
    NSArray* arr = [layer valueForKey:@"arr"];
    // arr is a series of CGPoints (wrapped up as NSValue); connect the dots
    // however, we want to connect the *centers* of pieces, whereas we are given piece *origins*
    // so calculate offsets
    CGSize sz = [self pieceSize];
    CGFloat offx = sz.width/2.0;
    CGFloat offy = sz.width/2.0;
    // no need to flip (as usual, I never understand why this is)
    CGContextSetLineJoin(con, kCGLineJoinRound);
    CGContextSetRGBStrokeColor(con, 0.4, 0.4, 1.0, 1.0);
    CGContextSetLineWidth(con, 3.0);
    CGContextBeginPath(con);
    for (int i = 0; i < [arr count] - 1; i++) {
        CGPoint p1 = [(NSValue*)arr[i] CGPointValue];
        CGPoint p2 = [(NSValue*)arr[i+1] CGPointValue];
        CGPoint orig1 = [self originOfX: p1.x Y: p1.y];
        CGPoint orig2 = [self originOfX: p2.x Y: p2.y];
        CGContextMoveToPoint(con, orig1.x + offx, orig1.y + offy);
        CGContextAddLineToPoint(con, orig2.x + offx, orig2.y + offy);
    }
    CGContextStrokePath(con);
}

// utility for obtaining a reference to the transparency layer
// it is the only sublayer of the layer of subview 999

- (CALayer*) pathLayer {
    UIView* trans = [self.view viewWithTag:999];
    CALayer* lay1 = [trans layer];
    CALayer* pathLayer = [[lay1 sublayers] lastObject];
    return pathLayer;
}

// utility for obtaining a reference to the view that holds the transparency layer
// we need this so we can switch touch fall-thru on and off

- (UIView*) pathView {
    return [self.view viewWithTag:999];
}

// given a series of CGPoints (wrapped up as NSValue), connect the dots
// we used to draw this ourselves and flash a view
// now, however, the view is already there
// all we have to do is store the array in the transparency layer and tell the layer it needs drawing

- (void) illuminate: (NSArray*) arr {
    CALayer* pathLayer = [self pathLayer];
    pathLayer.delegate = self;
    [self pathView].userInteractionEnabled = YES; // block touches while path is showing, balanced in unilluminate
    [pathLayer setValue:arr forKey:@"arr"];
    [pathLayer setNeedsDisplay];
    self.showingHint = YES;
    //[self performSelector:@selector(unilluminate:) withObject:nil afterDelay:0.2];
    return;
    /* OLD CODE, interesting because it shows how to draw into a bitmap from scratch and derive an image
    // arr is a series of CGPoints (wrapped up as NSValue); connect the dots
    // however, we want to connect the centers of pieces, whereas we are given piece coordinates
    // so we will need to convert, and to do so, we need the offset from the origin to the center
    CGSize sz = [self pieceSize];
    CGFloat offx = sz.width/2.0;
    CGFloat offy = sz.width/2.0;
    // ready to draw; create context and draw into it
    CGContextRef con = MyCreateBitmapContext(self.view.bounds.size.width, self.view.bounds.size.height);
    if (!con)
        return;
    // flip
    CGContextTranslateCTM (con, 0, self.view.bounds.size.height);
    CGContextScaleCTM (con, 1.0, -1.0);
    // draw
    CGContextSetLineJoin(con, kCGLineJoinRound);
    CGContextSetRGBStrokeColor(con, 0.4, 0.4, 1.0, 1.0);
    CGContextSetLineWidth(con, 3.0);
    CGContextBeginPath(con);
    for (int i = 0; i < [arr count] - 1; i++) {
        CGPoint p1 = [(NSValue*)[arr objectAtIndex: i] CGPointValue];
        CGPoint p2 = [(NSValue*)[arr objectAtIndex: i+1] CGPointValue];
        CGPoint orig1 = [self originOfX: p1.x Y: p1.y];
        CGPoint orig2 = [self originOfX: p2.x Y: p2.y];
        CGContextMoveToPoint(con, orig1.x + offx, orig1.y + offy);
        CGContextAddLineToPoint(con, orig2.x + offx, orig2.y + offy);
    }
    CGContextStrokePath(con);
    // create image, release drawing context
    CGImageRef im = CGBitmapContextCreateImage(con);
    char* bitmap = CGBitmapContextGetData(con);
    CGContextRelease(con);
    if (bitmap)
        free(bitmap);
    // create view, stuff image into its layer
    UIView* v = [[UIView alloc] initWithFrame:self.view.bounds];
    v.layer.contents = (id) im;
    CGImageRelease(im);
    v.tag = 111;
    [self.view addSubview:v];
    [v release];
    [self performSelector:@selector(unilluminate:) withObject:v afterDelay:0.2];
     */
}

// erase the path by clearing the transparency layer (nil contents)

- (void) unilluminate {
    CALayer* pathLayer = [self pathLayer];
    pathLayer.delegate = nil;
    pathLayer.contents = nil;
    [self pathView].userInteractionEnabled = NO; // make touches just fall thru once again
    self.showingHint = NO;
    return;
    // this is how we used to do it when were putting up and tearing down a view
    // [[self.view viewWithTag:111] removeFromSuperview];
}

// utility to determine whether the line from p1 to p2 consists entirely of NSNull

- (BOOL) lineIsClearFrom: (CGPoint) p1 to: (CGPoint) p2 {
    if (!((p1.x == p2.x) || (p1.y == p2.y)))
        return NO; // they are not even on the same line
    CGPoint start, end;
    // determine which dimension they share
    if (p1.x == p2.x) {
        if (p1.y < p2.y) {
            start = p1; end = p2;
        } else {
            start = p2; end = p1;
        }
        for (int i = start.y + 1; i < end.y; i++) {
            if ([self pieceAtX: p1.x Y: i] != [NSNull null]) {
                return NO;
            }
        }        
    }
    if (p1.y == p2.y) {
        if (p1.x < p2.x) {
            start = p1; end = p2;
        } else {
            start = p2; end = p1;
        }
        for (int i = start.x + 1; i < end.x; i++) {
            if ([self pieceAtX: i Y: p1.y] != [NSNull null]) {
                return NO;
            }
        }        
    }
    return YES;
}

// as pieces are highlighted, we store them in an ivar
// thus, to unhighlight all highlighted piece, we just run thru that list

- (void) cancelPair {
    [(Piece*)[self->_hilitedPieces lastObject] toggleHilite];
    [self->_hilitedPieces removeLastObject];
    [(Piece*)[self->_hilitedPieces lastObject] toggleHilite];
    [self->_hilitedPieces removeLastObject];
}

// utility to learn whether the grid is empty, indicating that the game is over

- (BOOL) gameOver {
    for (int x = 0; x < _xct; x++)
        for (int y = 0; y < _yct; y++)
            if ([self pieceAtX:x Y:y] != [NSNull null])
                return NO;
    return YES;
}

// utility to remove a piece from the interface and from the grid (i.e. replace it by NSNull)

- (void) removePieceAtX: (int) x Y: (int) y {
    //NSLog(@"%i %i", x, y);
    Piece* piece = [self pieceAtX:x Y:y];
    [piece removeFromSuperview];
    ((NSMutableArray*)(self.grid)[x])[y] = [NSNull null];
}

// bottleneck utility for when user correctly selects a pair
// flash the path and remove the two pieces

- (void) removePairAndIlluminatePath: (NSArray*) path {
    [self illuminate: path];
    // unilluminate will be called 0.2 later
    [self performSelector:@selector(unilluminate) withObject:nil afterDelay:0.2];
    // and delay even longer before really removing pieces
    [self performSelector:@selector(reallyRemovePair:) withObject:nil afterDelay:0.3];
}

// my finest hour!
// utility to slide piece to a new position
// the problem is that we must do this for many pieces at once
// the solution is that caller calls this utility repeatedly
// this utility *prepares* the pieces to be moved but does not physically move them
// it also puts the pieces in movenda
// the caller then calls moveMovenda and the slide actually happens

- (void) movePiece: (Piece*) p toX: (int) x Y: (int) y {
    NSAssert([self pieceAtX:x Y:y] == [NSNull null], @"Slot to move piece to must be empty");
    // move the piece within the *grid*
    NSString* s = [p picName];
    [self removePieceAtX:p.x Y:p.y];
    [self addPieceAtX:x Y:y withPicture:s];
    // however, we are not yet redrawn, so now...
    // return piece to its previous position! but add to movenda
    // later call to moveMovenda will thus animate it into correct position
    Piece* pnew = [self pieceAtX:x Y:y];
    CGRect f = pnew.frame;
    f.origin = [self originOfX:p.x Y:p.y];
    pnew.frame = f;
    [self.movenda addObject:pnew];
}

// utility to animate slide of pieces into their correct place
// okay, so all the pieces in movenda have the following odd feature:
// they are internally consistent (they are in the right place in the grid, and they know that place)
// but they are *physically* in the wrong place
// thus all we have to do is move them into the right place
// the big lesson here is that animations run in another thread...
// so as an animation begins, the interface is refreshed first
// thus it doesn't matter that we moved the piece into its right place;
// we also moved the piece back into its wrong place, and that is what the user will see when the animation starts
// looking at it another way, it is up to us to configure the interface to be right before the start of the animation

- (void) moveMovenda {
    [UIView beginAnimations:@"moveMovenda" context:nil];
    [UIView setAnimationDuration:0.15];
    [UIView setAnimationCurve:UIViewAnimationCurveLinear];
    // interactions are not turned off for us
    // so we must turn them off ourselves and turn them back on in the delegate notification
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
    while ([self.movenda count]) {
        Piece* p = [self.movenda lastObject];
        [self.movenda removeLastObject];
        CGRect f = p.frame;
        f.origin = [self originOfX:p.x Y:p.y];
        p.frame = f; // this is the move that will be animated
    }    
    [UIView commitAnimations];
}

- (void) checkStuck {
    NSArray* path = [self legalPath];
    if (!path)
        [self redeal];    
}

- (void)animationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context {
    if ([animationID isEqualToString:@"moveMovenda"]) { // should always be
        [[UIApplication sharedApplication] endIgnoringInteractionEvents];
        [self checkStuck]; // we do this after the slide animation is over, so we can get two animations in row, cool
    }
}

// utility for actually removing pieces listed in our hilitedPieces ivar

- (void) reallyRemovePair: (id) dummy {
    // notify (so score can be incremented)
    [[NSNotificationCenter defaultCenter] postNotificationName:@"userMoved" object:self];
    // actually remove the pieces (we happen to know there must be exactly two)
    Piece* piece = [self.hilitedPieces lastObject];
    [self removePieceAtX: piece.x Y: piece.y];
    [self.hilitedPieces removeLastObject];
    piece = [self.hilitedPieces lastObject];
    [self removePieceAtX: piece.x Y: piece.y];
    [self.hilitedPieces removeLastObject];
    // game over? if so, notify along with current stage and we're out of here!
    if ([self gameOver]) {
        NSDictionary* d = @{@"stage": self.stage};
        [[NSNotificationCenter defaultCenter] postNotificationName:@"gameOver" object:self userInfo:d];
        return;
    }
    // close up! depends on what stage we are in
    // the following code is really ugly and repetitive, every case being modelled on the same template
    // but C doesn't seem to give me a good way around that
    int s = [self.stage intValue];
    if (s == 0) {
        // no gravity
    }
    if (s == 1) {
        // gravity down
        for (int x = 0; x < _xct; x++) {
            for (int y = _yct - 1; y > 0; y--) {
                id piece = [self pieceAtX:x Y:y];
                if (piece == [NSNull null]) {
                    for (int yt = y-1; yt >= 0; yt--) {   
                        id piece2 = [self pieceAtX:x Y:yt];
                        if (piece2 == [NSNull null])
                            continue;
                        [self movePiece: piece2 toX:x Y:y];
                        break;
                    }
                }
            }
        }
    }
    if (s == 2) {
        // gravity left
        for (int y = 0; y < _yct; y++) {
            for (int x = _xct - 1; x > 0; x--) {
                id piece = [self pieceAtX:x Y:y];
                if (piece == [NSNull null]) {
                    for (int xt = x-1; xt >= 0; xt--) {
                        id piece2 = [self pieceAtX:xt Y:y];
                        if (piece2 == [NSNull null])
                            continue;
                        [self movePiece: piece2 toX:x Y:y];
                        break;
                    }
                }
            }
        }
    }
    if (s == 3) {
        // gravity toward central horiz line
        int center = _yct/2; // integer div, deliberate
        // exactly like 1 except we have to do it twice in two directions
        for (int x = 0; x < _xct; x++) {
            for (int y = center-1; y > 0; y--) {
                id piece = [self pieceAtX:x Y:y];
                if (piece == [NSNull null]) {
                    for (int yt = y-1; yt >= 0; yt--) {
                        id piece2 = [self pieceAtX:x Y:yt];
                        if (piece2 == [NSNull null])
                            continue;
                        [self movePiece: piece2 toX:x Y:y];
                        break;
                    }
                }
            }
            for (int y = center; y <= _yct - 1; y++) {
                id piece = [self pieceAtX:x Y:y];
                if (piece == [NSNull null]) {
                    for (int yt = y+1; yt < _yct; yt++) {
                        id piece2 = [self pieceAtX:x Y:yt];
                        if (piece2 == [NSNull null])
                            continue;
                        [self movePiece: piece2 toX:x Y:y];
                        break;
                    }
                }
            }            
        }
    }
    if (s == 4) {
        // gravity toward central vertical line
        int center = _xct/2; // integer div, deliberate
        // exactly like 3 except the other orientation
        for (int y = 0; y < _yct; y++) {
            for (int x = center-1; x > 0; x--) {
                id piece = [self pieceAtX:x Y:y];
                if (piece == [NSNull null]) {
                    for (int xt = x-1; xt >= 0; xt--) {
                        id piece2 = [self pieceAtX:xt Y:y];
                        if (piece2 == [NSNull null])
                            continue;
                        [self movePiece: piece2 toX:x Y:y];
                        break;
                    }
                }
            }
            for (int x = center; x <= _xct - 1; x++) {
                id piece = [self pieceAtX:x Y:y];
                if (piece == [NSNull null]) {
                    for (int xt = x+1; xt < _xct; xt++) {
                        id piece2 = [self pieceAtX:xt Y:y];
                        if (piece2 == [NSNull null])
                            continue;
                        [self movePiece: piece2 toX:x Y:y];
                        break;
                    }
                }
            }            
        }
    }
    if (s == 5) {
        // gravity away from central horiz line
        int center = _yct/2; // integer div, deliberate
        // exactly like 3 except we walk from the outside to the center
        for (int x = 0; x < _xct; x++) {
            for (int y = _yct-1; y > center; y--) {
                id piece = [self pieceAtX:x Y:y];
                if (piece == [NSNull null]) {
                    for (int yt = y-1; yt >= center; yt--) {
                        id piece2 = [self pieceAtX:x Y:yt];
                        if (piece2 == [NSNull null])
                            continue;
                        [self movePiece: piece2 toX:x Y:y];
                        break;
                    }
                }
            }
            for (int y = 0; y < center-1; y++) {
                id piece = [self pieceAtX:x Y:y];
                if (piece == [NSNull null]) {
                    for (int yt = y+1; yt < center; yt++) {
                        id piece2 = [self pieceAtX:x Y:yt];
                        if (piece2 == [NSNull null])
                            continue;
                        [self movePiece: piece2 toX:x Y:y];
                        break;
                    }
                }
            }            
        }
    }
    if (s == 6) {
        // gravity toward central vertical line
        int center = _xct/2; // integer div, deliberate
        // exactly like 4 except we start at the outside
        for (int y = 0; y < _yct; y++) {
            for (int x = _xct-1; x > center; x--) {
                id piece = [self pieceAtX:x Y:y];
                if (piece == [NSNull null]) {
                    for (int xt = x-1; xt >= center; xt--) {
                        id piece2 = [self pieceAtX:xt Y:y];
                        if (piece2 == [NSNull null])
                            continue;
                        [self movePiece: piece2 toX:x Y:y];
                        break;
                    }
                }
            }
            for (int x = 0; x < center-1; x++) {
                id piece = [self pieceAtX:x Y:y];
                if (piece == [NSNull null]) {
                    for (int xt = x+1; xt < center; xt++) {
                        id piece2 = [self pieceAtX:xt Y:y];
                        if (piece2 == [NSNull null])
                            continue;
                        [self movePiece: piece2 toX:x Y:y];
                        break;
                    }
                }
            }            
        }
    }
    if (s == 7) {
        // gravity down in one half, gravity up in the other half
        // like doing 1 in two pieces with the second piece in reverse direction
        int center = _xct/2;
        for (int x = 0; x < center; x++) {
            for (int y = _yct - 1; y > 0; y--) {
                id piece = [self pieceAtX:x Y:y];
                if (piece == [NSNull null]) {
                    for (int yt = y-1; yt >= 0; yt--) {
                        id piece2 = [self pieceAtX:x Y:yt];
                        if (piece2 == [NSNull null])
                            continue;
                        [self movePiece: piece2 toX:x Y:y];
                        break;
                    }
                }
            }
        }
        for (int x = center; x < _xct; x++) {
            for (int y = 0; y < _yct-1; y++) {
                id piece = [self pieceAtX:x Y:y];
                if (piece == [NSNull null]) {
                    for (int yt = y+1; yt < _yct; yt++) {
                        id piece2 = [self pieceAtX:x Y:yt];
                        if (piece2 == [NSNull null])
                            continue;
                        [self movePiece: piece2 toX:x Y:y];
                        break;
                    }
                }
            }
        }        
    }
    if (s == 8) {
        // gravity left in one half, gravity right in other half
        // like doing 2 in two pieces with second in reverse direction
        int center = _yct/2;
        for (int y = 0; y < center; y++) {
            for (int x = _xct - 1; x > 0; x--) {
                id piece = [self pieceAtX:x Y:y];
                if (piece == [NSNull null]) {
                    for (int xt = x-1; xt >= 0; xt--) {
                        id piece2 = [self pieceAtX:xt Y:y];
                        if (piece2 == [NSNull null])
                            continue;
                        [self movePiece: piece2 toX:x Y:y];
                        break;
                    }
                }
            }
        }
        for (int y = center; y < _yct; y++) {
            for (int x = 0; x < _xct-1; x++) {
                id piece = [self pieceAtX:x Y:y];
                if (piece == [NSNull null]) {
                    for (int xt = x+1; xt < _xct; xt++) {
                        id piece2 = [self pieceAtX:xt Y:y];
                        if (piece2 == [NSNull null])
                            continue;
                        [self movePiece: piece2 toX:x Y:y];
                        break;
                    }
                }
            }
        }
    }
    // animate!
    [self moveMovenda]; // and then check for stuck, in the delegate handler for moveMovenda
}

// utility to learn physical distance between two points (thank you, M. Descartes)

CGFloat distance(CGPoint pt1, CGPoint pt2) {
    CGFloat deltax = pt1.x - pt2.x;
    CGFloat deltay = pt1.y - pt2.y;
    return sqrtf(deltax * deltax + deltay * deltay);
}

// main game logic utility! this is how we know whether two pieces form a legal pair
// the day I figured out how to do this is the day I realized I could write this game
// we hand back the legal path joining the pieces, rather than a bool, so that the caller can draw the path

- (NSArray*) checkPair: (Piece*) p1 and: (Piece*) p2 {
    // if not a pair, return nil
    // if a pair, return an array of successive CGPoints (wrapped up in NSValues) representing path between them
    CGPoint pt1 = CGPointMake(p1.x, p1.y);
    CGPoint pt2 = CGPointMake(p2.x, p2.y);
    // 1. first check: are they on the same line with nothing between them?
    if ([self lineIsClearFrom: pt1 to: pt2]) {
        return @[[NSValue valueWithCGPoint:pt1],
                [NSValue valueWithCGPoint:pt2]];
    }
    // 2. second check: are they at the corners of a rectangle with nothing on one pair of sides between them?
    CGPoint midpt1 = CGPointMake(p1.x, p2.y);
    CGPoint midpt2 = CGPointMake(p2.x, p1.y);
    if ([self pieceAtX:midpt1.x Y:midpt1.y] == [NSNull null]) {
        if ([self lineIsClearFrom: pt1 to: midpt1] && [self lineIsClearFrom: midpt1 to: pt2]) {
            return @[[NSValue valueWithCGPoint:pt1],
                    [NSValue valueWithCGPoint:midpt1],
                    [NSValue valueWithCGPoint:pt2]];
        }
    }
    if ([self pieceAtX:midpt2.x Y:midpt2.y] == [NSNull null]) {
        if ([self lineIsClearFrom: pt1 to: midpt2] && [self lineIsClearFrom: midpt2 to: pt2]) {
            return @[[NSValue valueWithCGPoint:pt1],
                    [NSValue valueWithCGPoint:midpt2],
                    [NSValue valueWithCGPoint:pt2]];            
        }
    }
    // 3. third check: The Way of the Moving Line
    // (this was the algorithmic insight that makes the whole thing possible)
    // connect the x or y coordinates of the pieces by a vertical or horizontal line;
    // move that line through the whole grid including outside the boundaries,
    // and see if all three resulting segments are clear
    // the only drawback with this approach is that if there are multiple paths...
    // we may find a longer one before we find a shorter one, which is counter-intuitive
    // so, accumulate all found paths and submit only the shortest
    NSMutableArray* marr = [NSMutableArray array];
    for (int y = -1; y <= _yct; y++) {
        CGPoint midpt1 = CGPointMake(pt1.x,y);
        CGPoint midpt2 = CGPointMake(pt2.x,y);
        if ([self pieceAtX:midpt1.x Y:midpt1.y] == [NSNull null] && 
            [self pieceAtX:midpt2.x Y:midpt2.y] == [NSNull null]) {
            if ([self lineIsClearFrom: pt1 to: midpt1] && 
                [self lineIsClearFrom: midpt1 to: midpt2] && 
                [self lineIsClearFrom: midpt2 to: pt2]) {
                [marr addObject:
                 @[[NSValue valueWithCGPoint:pt1],
                  [NSValue valueWithCGPoint:midpt1],
                  [NSValue valueWithCGPoint:midpt2],
                  [NSValue valueWithCGPoint:pt2]]];            
            }
        }
    }
    for (int x = -1; x <= _xct; x++) {
        CGPoint midpt1 = CGPointMake(x,pt1.y);
        CGPoint midpt2 = CGPointMake(x,pt2.y);
        if ([self pieceAtX:midpt1.x Y:midpt1.y] == [NSNull null] && 
            [self pieceAtX:midpt2.x Y:midpt2.y] == [NSNull null]) {
            if ([self lineIsClearFrom: pt1 to: midpt1] && 
                [self lineIsClearFrom: midpt1 to: midpt2] && 
                [self lineIsClearFrom: midpt2 to: pt2]) {
                [marr addObject:
                 @[[NSValue valueWithCGPoint:pt1],
                  [NSValue valueWithCGPoint:midpt1],
                  [NSValue valueWithCGPoint:midpt2],
                  [NSValue valueWithCGPoint:pt2]]];            
            }
        }
    }
    if ([marr count] > 0) {
        // got at least one! find the shortest and submit it
        CGFloat shortestLength = -1.0;
        NSArray* shortestPath = nil;
        for (NSArray* thisPath in marr) {
            CGFloat thisLength = 0;
            for (int ix=0; ix < [thisPath count] - 1; ix++) {
                thisLength += distance([thisPath[ix] CGPointValue], [thisPath[ix+1] CGPointValue]);
            }
            if ((shortestLength < 0) || (thisLength < shortestLength)) {
                shortestLength = thisLength;
                shortestPath = thisPath;
            }
        }
        NSAssert(shortestPath, @"Should never get here; we must have a path to illuminate by now.");
        return shortestPath;
    }
    // no dice
    return nil;
}

// the hilited pair is in our ivar hilitedPieces
// if it is legal, illuminate its path and remove it
// otherwise quietly unhilite it

- (void) checkHilitedPair {
    NSAssert([self.hilitedPieces count] == 2, @"Must have a pair to check");
    for (Piece* piece in self.hilitedPieces)
        NSAssert(piece.superview == self.view, @"Pieces to check must be on displayed on board");
    Piece* p1 = (self.hilitedPieces)[0];
    Piece* p2 = (self.hilitedPieces)[1];
    if (![p1.picName isEqualToString: p2.picName]) {
        [self cancelPair];
        return;
    }
    NSArray* path = [self checkPair: p1 and: p2];
    if (path)
        [self removePairAndIlluminatePath:path];
    else
        [self cancelPair];
}

// this really shows why gesture recognizers are so cool
// I can be notified only just in case there is a simple tap on a piece
// and *I* am notified, not the piece

// maintain an ivar pointing to hilited pieces
// when that list has two items, check them for validity

- (void) handleTap: (UIGestureRecognizer*) g {
    Piece* p = (Piece*)[g view];
    BOOL hilited = p.isHilited;
    if (!hilited) {
        if ([self.hilitedPieces count] > 1) {
            return;
        }
        [self.hilitedPieces addObject:p];
    } else {
        [self.hilitedPieces removeObject:p];
    }
    [p toggleHilite];
    if ([self.hilitedPieces count] == 2)
        [self checkHilitedPair];
}

// utility to run thru the entire grid and make sure there is at least one legal path somewhere
// if the path exists, we return NSArray representing path that joins them; otherwise nil
// that way, the caller can *show* the legal path if desired
// but caller can treat result as condition as well
// the path is simply the path returned from checkPair

- (NSArray*) legalPath {
    for (int x = 0; x < _xct; x++) {
        for (int y = 0; y < _yct; y++) {
            id piece = [self pieceAtX:x Y:y];
            if (piece == [NSNull null])
                continue;
            NSString* picName = [(Piece*)piece picName];
            for (int xx = 0; xx < _xct; xx++) {
                for (int yy = 0; yy < _yct; yy++) {
                    id piece2 = [self pieceAtX:xx Y:yy];
                    if (piece2 == [NSNull null])
                        continue;
                    if (x == xx && y == yy)
                        continue;
                    NSString* picName2 = [(Piece*)piece2 picName];
                    if (![picName2 isEqualToString: picName])
                        continue;
                    NSArray* path = [self checkPair:piece and:piece2];
                    if (!path)
                        continue;
                    // got one!
                    return path;
                }
            }
        }
    }
    return nil;
}

// public, called by LinkSameViewController to get us to display a legal path

- (void) hint {
    NSArray* path = [self legalPath];
    if (path)
        [self illuminate:path];
    else
        [self redeal]; // should never happen at this point
}

@end
