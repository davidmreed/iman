//
//  iManAproposResultsSorting.m
//  iMan
//  Copyright (c) 2006-2009 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import "iManAproposResultsSorting.h"

@implementation NSObject (iManSorting)

- (NSComparisonResult)iManResultSort:(id)other
{
    id this, anOther;
    
    if ([self isKindOfClass:[NSArray class]])
        this = [(NSArray *)self objectAtIndex:0];
    else
        this = self;
	
    if ([other isKindOfClass:[NSArray class]])
        anOther = [(NSArray *)other objectAtIndex:0];
    else
        anOther = other;
    return [this localizedCompare:anOther];
}

@end