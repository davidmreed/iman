//
//  iManPageView.m
//  iMan
//  Copyright (c) 2004-2010 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import "iManPageView.h"


@implementation iManPageView

- (void)keyDown:(NSEvent *)theEvent
{
	if ([[theEvent characters] isEqualToString:@" "])
		[self pageDown:self];
	else 
		[super keyDown:theEvent];
}

@end
