
#import "MutableArrayCategories.h"
#include <stdlib.h>

@implementation NSMutableArray (mycats)

- (void) shuffle {
	for (int i = [self count] - 1; i != 0; i--)
		[self exchangeObjectAtIndex:i
				  withObjectAtIndex:arc4random_uniform(i+1)]; // revised
}

@end
