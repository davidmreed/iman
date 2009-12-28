//
//  iManURLHandler.m
//  iMan
//  Copyright (c) 2004-2009 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import "iManURLHandler.h"
#import "iMan.h"
#import "iManConstants.h"

@implementation iManURLHandler

- performDefaultImplementation
{
	[iMan loadExternalURL:[NSURL URLWithString:[self directParameter]]];	    
    return nil;
}

@end
