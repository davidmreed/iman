//
//  iManURLHandler.m
//  iMan
//  Copyright (c) 2004-2010 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import "iManURLHandler.h"
#import "iMan.h"
#import "iManConstants.h"

@implementation iManURLHandler

- performDefaultImplementation
{
	[[NSApp delegate] loadExternalURL:[NSURL URLWithString:[self directParameter]]];	    
    return nil;
}

@end
