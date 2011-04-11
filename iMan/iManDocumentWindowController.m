//
//  iManDocumentWindowController.m
//  iMan
//  Copyright (c) 2004-2010 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import "iManDocumentWindowController.h"
#import "iManConstants.h"

@implementation iManDocumentWindowController

- (void)windowDidLoad
{
	// If the user has previously resized a window, create this window at the same size.
	if ([[NSUserDefaults standardUserDefaults] objectForKey:iManLastViewingWindowSize] != nil) {
		NSSize size = NSSizeFromString([[NSUserDefaults standardUserDefaults] objectForKey:iManLastViewingWindowSize]);
		
		[[self window] setFrame:NSMakeRect(NSMinX([[self window] frame]),
										   NSMaxY([[self window] frame]), 
										   size.width, 
										   size.height) 
						display:NO];
	}
	[[self window] setDelegate:self];
}	

- (void)windowDidResize:(NSNotification *)notification
{
	[[NSUserDefaults standardUserDefaults] setObject:NSStringFromSize([[self window] frame].size) forKey:iManLastViewingWindowSize];
}

@end
