//
//  iManIndexingWindowController.m
//  iMan
//  Copyright (c) 2006-2009 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import "iManIndexingWindowController.h"
#import <iManEngine/iManIndex.h>

NSString *const iManIndexingCanceledNotification = @"iManIndexingCanceledNotification";
NSString *const iManIndexingFailedNotification = @"iManIndexingFailedNotification";
NSString *const iManIndexingCompletedNotification = @"iManIndexingCompletedNotification";

@implementation iManIndexingWindowController

- (iManIndexingWindowController *)initWithSelectedIndexes:(NSArray *)indexes
{
	self = [super initWithWindowNibName:@"iManIndexPanel"];
	
	if (indexes)
		selectedIndexes_ = [indexes mutableCopy];
	else
		selectedIndexes_ = [[iManIndex availableIndexes] mutableCopy];
	
	indexing_ = NO;
	
	return self;
}

- (NSArray *)selectedIndexes
{
	return [[selectedIndexes_ copy] autorelease];
}

- (void)setSelectedIndexes:(NSArray *)indexes
{
	if (!indexing_) {
		[selectedIndexes_ setArray:indexes];
		[indexList reloadData];
	}
}

- (IBAction)runModalUpdateWindow:(id)sender
{
	if (!indexing_)
		(void)[self doRunModalUpdateWindow];
}

- (int)doRunModalUpdateWindow
{
	if (!indexing_)
		return [NSApp runModalForWindow:[self window]];
	
	return NSAlertOtherReturn;
}

- (IBAction)cancel:(id)sender
{
	[NSApp stopModalWithCode:NSCancelButton];
	[[self window] orderOut:self];
	[[NSNotificationCenter defaultCenter] postNotificationName:iManIndexingCanceledNotification object:self userInfo:nil];
}

- (IBAction)update:(id)sender
{
	NSWindow *wind = [self window];
	int deltaX = (NSWidth([[wind contentView] frame]) - NSWidth([progressView frame]));
	int deltaY = (NSHeight([[wind contentView] frame]) - NSHeight([progressView frame]));
	
	indexing_ = YES;
	
	// "Morph" the window -- delete the list view, resize the window around its current center, and add the progress bar.
	[wind setFrame:NSMakeRect(NSMinX([wind frame]) + floor(deltaX / 2),
							  NSMinY([wind frame]) + floor(deltaY / 2),
							  NSWidth([progressView frame]),
							  NSHeight([progressView frame]) + (NSHeight([wind frame]) - NSHeight([listView frame])))
		   display:YES 
		   animate:YES];
	
	[progressBar startAnimation:self];
	currentIndex_ = [[selectedIndexes_ objectAtIndex:0] retain];
	[selectedIndexes_ removeObjectAtIndex:0];
	[textField setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Updating index \"%@\". Please wait...", nil), [currentIndex_ name]]];

	[wind setContentView:progressView];

	// Register for notifications from the asynchronous update.
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_indexDidUpdate:) name:iManIndexDidUpdateNotification object:currentIndex_];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_indexDidNotUpdate:) name:iManIndexDidFailUpdateNotification object:currentIndex_];

	[currentIndex_ update];
}

- (void)_indexDidUpdate:(NSNotification *)notification
{
	[currentIndex_ release];
	currentIndex_ = nil;
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	if ([selectedIndexes_ count] > 0) {
		// If there are more indices to update, set the UI accordingly and trigger the update.
		currentIndex_ = [[selectedIndexes_ objectAtIndex:0] retain]; 
		[selectedIndexes_ removeObjectAtIndex:0];
		[textField setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Updating index \"%@\". Please wait...", nil), [currentIndex_ name]]];
	
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_indexDidUpdate:) name:iManIndexDidUpdateNotification object:currentIndex_];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_indexDidNotUpdate:) name:iManIndexDidFailUpdateNotification object:currentIndex_];
		
		[currentIndex_ update];
	} else {
		// Updates are complete. Dismiss the window and post the appropriate notification so anything waiting on index completion (search windows) can continue.
		[NSApp stopModalWithCode:NSOKButton];
		[[self window] orderOut:self];
		[[NSNotificationCenter defaultCenter] postNotificationName:iManIndexingCompletedNotification 
															object:self
														  userInfo:nil];
	}
}

- (void)_indexDidNotUpdate:(NSNotification *)notification
{
	NSBeginAlertSheet(NSLocalizedString(@"Updating index failed.", nil),
					  NSLocalizedString(@"OK", nil),
					  nil, nil, 
					  [self window],
					  nil, NULL, NULL, NULL,
					  NSLocalizedString(@"The index \"%@\" could not be updated.", nil), [currentIndex_ name]);
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[currentIndex_ release];
	currentIndex_ = nil;
	
	[[NSNotificationCenter defaultCenter] postNotificationName:iManIndexingFailedNotification object:self userInfo:nil];
	
	[NSApp stopModalWithCode:NSAlertOtherReturn];
	[[self window] orderOut:self];
}

- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [[iManIndex availableIndexes] count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	if ([[tableColumn identifier] isEqualToString:@"checkboxes"])
		return [NSNumber numberWithInt:([selectedIndexes_ containsObject:[[iManIndex availableIndexes] objectAtIndex:row]] ? NSOnState : NSOffState)];
	else 
		return [[[iManIndex availableIndexes] objectAtIndex:row] name];
	
	return nil;
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	if ([[tableColumn identifier] isEqualToString:@"checkboxes"]) {
		if ([object intValue] == NSOnState)
			[selectedIndexes_ addObject:[[iManIndex availableIndexes] objectAtIndex:row]];
		else
			[selectedIndexes_ removeObjectAtIndex:row];
	}
}

- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	return ([[tableColumn identifier] isEqualToString:@"checkboxes"]);
}

- (void)dealloc
{
	// Don't release progressView. Apparently NSWindowController automatically handles releasing top-level nib objects.
	// (The damn thing crashes if we do).
	[selectedIndexes_ release];
	[super dealloc];
}

@end
