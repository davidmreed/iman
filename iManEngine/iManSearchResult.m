//
//  iManSearchResult.m
//  iManEngine
//
//  Created by David Reed on 5/20/10.
//  Copyright 2010 David Reed. All rights reserved.
//

#import "iManSearchResult.h"


@implementation iManSearchResult

+ searchResultWithPageNames:(NSArray *)names description:(NSString *)description
{
	return [[[iManSearchResult alloc] initWithPageNames:names description:description] autorelease];
}

- initWithPageNames:(NSArray *)names description:(NSString *)description
{
	self = [super init];
	if (self != nil) {
		_names = [names copy];
		_description = [description retain];
	}
	return self;
}

- (NSString *)firstPageName
{
	return [[self pageNames] objectAtIndex:0];
}

- (NSArray *)pageNames
{
	return _names;
}

- (NSString *)description
{
	return _description;
}

- (NSComparisonResult)compare:(id)other
{
	if ([other isKindOfClass:[self class]])
		return [[self firstPageName] localizedCompare:[other firstPageName]];
	
	return NSOrderedSame;
}

- (void)dealloc
{
	[_names release];
	[_description release];
	[super dealloc];
}

@end
