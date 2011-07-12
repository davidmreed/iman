//
//  NSString+iManPathExtensions.m
//  iManEngine
//  Copyright (c) 2004-2010 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import "NSString+iManPathExtensions.h"


@implementation NSString (iManPathExtensions)

- (NSString *)pageSection
{
	if ([[self pathExtension] isEqualToString:@"gz"]) {
		return [[self stringByDeletingPathExtension] pathExtension];
	} else {
		return [self pathExtension];
	}
}

- (NSString *)pageName
{
	if ([[self pathExtension] isEqualToString:@"gz"]) {
		return [[[self lastPathComponent] stringByDeletingPathExtension] stringByDeletingPathExtension];
	} else {
		return [[self lastPathComponent] stringByDeletingPathExtension];
	}
}

@end
