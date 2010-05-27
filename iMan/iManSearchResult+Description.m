//
//  iManSearchResult+Description.m
//  iMan
//
//  Created by David Reed on 5/23/10.
//  Copyright 2010 David Reed. All rights reserved.
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
