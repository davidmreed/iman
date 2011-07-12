//
//  iManSearchResult+Description.m
//  iMan
//  Copyright (c) 2004-2010 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import "iManSearchResult+Description.h"

@implementation iManSearchResult (Description)

- (NSAttributedString *)formattedDescription
{
	
	// If this page documents more than one command, prepend a string enumerating all the commands.
	if ([[self pageNames] count] > 1) {
		NSMutableAttributedString *ret = [[NSMutableAttributedString alloc] init];

		[ret appendAttributedString:[[[NSAttributedString alloc] initWithString:[[self pageNames] componentsJoinedByString:@", "] attributes:[NSDictionary dictionaryWithObject:[NSColor grayColor] forKey:NSForegroundColorAttributeName]] autorelease]];
		[ret appendAttributedString:[[[NSAttributedString alloc] initWithString:@"\n\n"] autorelease]];
		[ret appendAttributedString:[[[NSAttributedString alloc] initWithString:[self description]] autorelease]];
		
		return [ret autorelease];
	}
	
	return [[[NSAttributedString alloc] initWithString:[self description]] autorelease];
}

@end
