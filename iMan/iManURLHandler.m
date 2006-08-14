//
// iManURLHandler.m
// iMan
// Copyright (c) 2004 by David Reed, distributed under the BSD License.
// see iman-macosx.sourceforge.net for details.
//

#import "iManURLHandler.h"
#import "iManDocument.h"
#import "iManConstants.h"

@implementation iManURLHandler

- performDefaultImplementation
{
	[iManDocument loadURL:[NSURL URLWithString:[self directParameter]]
			inNewDocument:([[NSUserDefaults standardUserDefaults] integerForKey:iManHandleExternalLinks] == k_iManHandleLinkInNewWindow)];
	    
    return nil;
}

@end
