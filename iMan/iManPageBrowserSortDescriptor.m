//
//  iManPageBrowserSortDescriptor.m
//  iMan
//  Copyright (c) 2004-2010 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import "iManPageBrowserSortDescriptor.h"

@class iManSection;

@implementation iManPageBrowserSortDescriptor

- (NSComparisonResult)compareObject:(id)object1 toObject:(id)object2
{
	if ([object1 isKindOfClass:[object2 class]])
		return [super compareObject:object1 toObject:object2];
	
	if ([object1 isKindOfClass:[iManSection class]] && [object2 isKindOfClass:[NSString class]])
		return NSOrderedAscending;
	if ([object1 isKindOfClass:[NSString class]] && [object2 isKindOfClass:[iManSection class]])
		return NSOrderedDescending;
	
	return [super compareObject:object1 toObject:object2];
}

@end
