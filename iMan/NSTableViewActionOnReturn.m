//
//  NSTableViewActionOnReturn.m
//  iMan
//  Copyright (c) 2004-2010 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import "NSTableViewActionOnReturn.h"

@implementation NSTableViewActionOnReturn

- (void)keyDown:(NSEvent *)event
{
	if ([[NSCharacterSet newlineCharacterSet] characterIsMember:[[event charactersIgnoringModifiers] characterAtIndex:0]]) {
		if ([self doubleAction] != NULL) {
			[NSApp sendAction:[self doubleAction] to:[self target] from:self];
			return;
		}
	}
	[super keyDown:event];
}

@end
