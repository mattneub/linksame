// a Piece knows its spot in the grid and how to draw itself according its hilite state
// tap detection is handled thru a gesture recognizer assigned by the Board

#import "Piece.h"

@interface Piece ()
@property (nonatomic, retain) UIImage* pic;
@end

@implementation Piece
@synthesize pic, x, y, picName, hilite;

- (void) encodeWithCoder: (NSCoder*) coder {
    [coder encodeInt:x forKey:@"x"];
    [coder encodeInt:y forKey:@"y"];
    [coder encodeObject:picName forKey:@"picName"];
}

- (id) initWithCoder: (NSCoder*) coder {
    self = [super init];
    x = [coder decodeIntForKey:@"x"];
    y = [coder decodeIntForKey:@"y"];
    picName = [coder decodeObjectForKey:@"picName"];
    [picName retain];
    return self;
}


// when name is set, we also fetch picture and set it
// that way, we don't have to fetch picture each time we draw ourself
// perhaps this is no savings of time and a waste of memory, I've no idea

- (void) setPicName: (NSString*) newPicName {
    NSString* newPicNameCopy = [newPicName copy];
    [self->picName release];
    self->picName = newPicNameCopy;
    // also set actual picture at this time; outside world deals only with the name
    NSString* path = [[NSBundle mainBundle] pathForResource:self->picName ofType:@"png" inDirectory:@"foods"];
    UIImage* im = [[UIImage alloc] initWithContentsOfFile:path];
    self.pic = im;
    [im release];
}

- (void)drawRect:(CGRect)rect {
    CGRect peri = CGRectMake(0.0, 0.0, self.bounds.size.width, self.bounds.size.height);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSetLineCap(context, kCGLineCapSquare);
    
    // fill, according to highlight state
    UIColor *beige = [UIColor colorWithRed:0.900 green:0.798 blue:0.499 alpha:1.000];
    UIColor *purple = [UIColor colorWithRed:0.898 green:0.502 blue:0.901 alpha:1.000];
    CGContextSetFillColorWithColor(context, (self->hilite ? [purple CGColor] : [beige CGColor]));
    CGContextFillRect(context, CGRectInset(peri, -1.0, -1.0)); // "outset" to ensure full coverage
    
    // frame: draw shade all the way round, then light round two sides
    UIColor *shadow = [UIColor colorWithRed:0.670 green:0.537 blue:0.270 alpha:1.000];
    CGContextSetStrokeColorWithColor(context, [shadow CGColor]);
    peri = CGRectInset(peri, 1.0, 1.0);
    CGContextSetLineWidth(context, 1.5);
    CGContextStrokeRect(context, peri);
    UIColor *lite = [UIColor colorWithRed:1.000 green:0.999 blue:0.999 alpha:1.000];
    CGContextSetStrokeColorWithColor(context, [lite CGColor]);
    CGPoint points[] = {
        CGPointMake(CGRectGetMinX(peri), CGRectGetMaxY(peri)), 
        CGPointMake(CGRectGetMinX(peri), CGRectGetMinY(peri)),
        CGPointMake(CGRectGetMinX(peri), CGRectGetMinY(peri)), 
        CGPointMake(CGRectGetMaxX(peri), CGRectGetMinY(peri)) 
    };
    CGContextStrokeLineSegments(context, points, 4);
    
    // draw picture centered
    CGImageRef ppic = [self.pic CGImage];
    size_t picw = CGImageGetWidth(ppic);
    size_t pich = CGImageGetHeight(ppic);
    // flip! not sure why, I never understand these things
    CGContextTranslateCTM (context, 0, self.bounds.size.height);
    CGContextScaleCTM (context, 1.0, -1.0);
    CGContextDrawImage(context, 
                       CGRectInset(peri, 
                                   (CGRectGetWidth(peri) - picw)/2.0, 
                                   (CGRectGetHeight(peri) - pich)/2.0), 
                       [pic CGImage]);
}

- (void)dealloc {
    [pic release];
    [picName release];
    [super dealloc];
}

- (void) toggleHilite {
    self->hilite = !(self->hilite);
    [self setNeedsDisplay];
}


@end
