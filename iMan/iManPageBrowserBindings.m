//
//  iManPageBrowserBindings.m
//  iMan
//  Copyright (c) 2004-2011 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import "iManPageBrowserBindings.h"

@implementation iManSection (iManPageBrowser)

+ (NSArray *)keyPathsForValuesAffectingIManPageBrowserContents
{
	return [NSArray arrayWithObject:@"contents"];
}

+ (NSArray *)keyPathsForValuesAffectingIManPageBrowserTitle
{
	return [NSArray arrayWithObject:@"name"];
}

- (BOOL)iManPageBrowserIsLeaf
{
	return NO;
}

- (NSArray *)iManPageBrowserContents
{
	return self.contents;
}

- (NSString *)iManPageBrowserTitle
{
	return NSLocalizedStringFromTable(self.name, @"SectionNames", nil);
}

@end

@implementation NSString (iManPageBrowser)

- (BOOL)iManPageBrowserIsLeaf
{
	return YES;
}

- (NSArray *)iManPageBrowserContents
{
	return nil;
}

- (NSString *)iManPageBrowserTitle
{
	return [self pageName];
}

@end