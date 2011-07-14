//
//  iManSection.h
//  iManEngine
//  Copyright (c) 2004-2011 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.

#import "iManSection.h"

@implementation iManSection

@synthesize name, pages, subsections;
@dynamic contents;

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key
{
	if ([key isEqualToString:@"contents"]) {
		return [[super keyPathsForValuesAffectingValueForKey:key] setByAddingObjectsFromArray:[NSArray arrayWithObjects:@"pages", @"subsections", nil]];
	}
	
	return [super keyPathsForValuesAffectingValueForKey:key];
}

- initWithName:(NSString *)aName
{
	self = [super init];

	if (self != nil) {
		name = [aName copy];
		pages = [[NSMutableArray alloc] init];
		subsections = [[NSMutableArray alloc] init];
	}
	
	return self;
}

- initWithCoder:(NSCoder *)coder
{
	self = [super init];

	if (self != nil) {
		name = [[coder decodeObjectForKey:@"name"] retain];
		pages = [[coder decodeObjectForKey:@"pages"] mutableCopy];
		subsections = [[coder decodeObjectForKey:@"subsections"] mutableCopy];
	}
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
	[aCoder encodeObject:self.name forKey:@"name"];
	[aCoder encodeObject:self.pages forKey:@"page"];
	[aCoder encodeObject:self.subsections forKey:@"subsections"];
}

- (NSArray *)contents
{
	return [[NSArray arrayWithArray:self.pages] arrayByAddingObjectsFromArray:self.subsections];
}

- (void)dealloc
{
	[name release];
	[super dealloc];
}

@end
