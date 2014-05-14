
#import "MutableArrayCategories.h"
#include <stdlib.h>

@implementation NSMutableArray (mycats)

- (void) shuffle {
	for (NSUInteger i = [self count] - 1; i != 0; i--)
		[self exchangeObjectAtIndex:i
				  withObjectAtIndex:arc4random_uniform((u_int32_t)i+1)]; // revised
}

@end
