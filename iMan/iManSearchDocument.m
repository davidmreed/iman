//
// iManSearchDocument.m
// iMan
// Copyright (c) 2006 by David Reed, distributed under the BSD License.
// see iman-macosx.sourceforge.net for details.
//

#import "iManSearchDocument.h"
#import "iManDocument.h"
#import "iManConstants.h"
#import "iManIndexingWindowController.h"
#import <iManEngine/iManEngine.h>

// Constants for tab view indices.
enum {
    kiManSearchDocumentResultsTabIndex,
    kiManSearchDocumentProgressTabIndex
};

@implementation iManSearchDocument

#pragma mark -
#pragma mark NSDocument Overrides

- (void)windowControllerDidLoadNib:(NSWindowController *)windowController;
{
	NSEnumerator *anEnumerator;
	id anObject;
	
    [super windowControllerDidLoadNib:windowController];

	[searchTypeMenu removeAllItems];
	anEnumerator = [[iManSearch searchTypes] objectEnumerator];
	
	while ((anObject = [anEnumerator nextObject]) != nil)  {
		[searchTypeMenu addItemWithTitle:[iManSearch localizedNameForSearchType:anObject]];
		[[searchTypeMenu lastItem] setRepresentedObject:anObject];
	}

    [tableView setDoubleAction:@selector(openPage:)];
    [tableView setAutoresizesOutlineColumn:NO];
}

- (NSString *)windowNibName
{
    return @"iManSearchDocument";
}

- (NSString *)displayName
{
    if (search_ != nil)
        return [NSString stringWithFormat:NSLocalizedString(@"Search: %@", nil), [[self search] term]];

    return NSLocalizedString(@"Search", nil);
}

#pragma mark -
#pragma mark Accessors


- (iManSearch *)search
{
	return search_;
}

- (void)setSearch:(iManSearch *)search
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:iManSearchDidCompleteNotification object:search_];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:iManSearchDidFailNotification object:search_];

	[search retain];
	[search_ release];
	search_ = search;
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(searchDidComplete:) name:iManSearchDidCompleteNotification object:search_];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(searchDidFail:) name:iManSearchDidFailNotification object:search_];	
}
	
#pragma mark -
#pragma mark IBActions

- (IBAction)go:(id)sender
{
	iManIndex *index = [iManSearch indexForSearchType:[[searchTypeMenu selectedItem] representedObject]];
	
	if ([index isValid]) {
		[searchTypeMenu setEnabled:NO];
		[goButton setEnabled:NO];
		[searchField setEnabled:NO];
		[tabView selectTabViewItemAtIndex:kiManSearchDocumentProgressTabIndex];
		[[[[[self windowControllers] lastObject] window] standardWindowButton:NSWindowCloseButton] setEnabled:NO];
		[progressMeter startAnimation:self];

		[self setSearch:[iManSearch searchWithTerm:[searchField stringValue] 
										searchType:[[searchTypeMenu selectedItem] representedObject]]];
		[[self search] search];
	} else {
		NSBeginAlertSheet(NSLocalizedString(@"Index out of date.", nil), 
						  NSLocalizedString(@"Update", nil),
						  NSLocalizedString(@"Cancel", nil),
						  nil,
						  [[[self windowControllers] lastObject] window],
						  self,
						  @selector(shouldUpdateIndexPanelDidEnd:returnCode:contextInfo:),
						  NULL,
						  NULL,
						  NSLocalizedString(@"The index for the search type \"%@\" needs to be updated before it can be searched. Do you want to update the index now?", nil),
						  [searchTypeMenu titleOfSelectedItem]);
	}
}

- (void)shouldUpdateIndexPanelDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];
	
	if (returnCode == NSOKButton) {
		iManIndexingWindowController *indexingWindowController =  [[iManIndexingWindowController alloc] initWithSelectedIndexes:[NSArray arrayWithObject:[iManSearch indexForSearchType:[[searchTypeMenu selectedItem] representedObject]]]];
		int returnCode;
		
		returnCode = [indexingWindowController doRunModalUpdateWindow];
		
		if (returnCode == NSOKButton)
			[self performSelector:@selector(go:) withObject:self afterDelay:0.01];
		
		// Ignore cancel, ignore failure (indexing window will notify user of failure).
		
		[indexingWindowController release];
	}
}

- (IBAction)openPage:(id)sender
{
    id item = [tableView itemAtRow:[tableView clickedRow]];

    if ([item isKindOfClass:[NSArray class]])
        item = [item objectAtIndex:0];

	[iManDocument loadURL:[NSURL URLWithString:[NSString stringWithFormat:@"man:%@", item]]
			inNewDocument:([[NSUserDefaults standardUserDefaults] integerForKey:iManHandleSearchResults] == k_iManHandleLinkInNewWindow)];
}

#pragma mark -
#pragma mark Search Engine delegate methods

- (void)searchDidComplete:(NSNotification *)notification
{
	[sortedResults release];
	sortedResults = [[[[[self search] results] allKeys] sortedArrayUsingSelector:@selector(iManResultSort:)] retain];
	
    [progressMeter stopAnimation:self];
	[[[[[self windowControllers] lastObject] window] standardWindowButton:NSWindowCloseButton] setEnabled:YES];
    [searchTypeMenu setEnabled:YES];
    [goButton setEnabled:YES];
    [searchField setEnabled:YES];
    [tabView selectTabViewItemAtIndex:kiManSearchDocumentResultsTabIndex];
    [[[self windowControllers] lastObject] synchronizeWindowTitleWithDocumentName];
	
    [tableView reloadData];
}

- (void)searchDidFail:(NSNotification *)notification
{
	[progressMeter stopAnimation:self];
	[[[[[self windowControllers] lastObject] window] standardWindowButton:NSWindowCloseButton] setEnabled:YES];
    [searchTypeMenu setEnabled:YES];
    [goButton setEnabled:YES];
    [searchField setEnabled:YES];
    [tabView selectTabViewItemAtIndex:kiManSearchDocumentResultsTabIndex];
    [[[self windowControllers] lastObject] synchronizeWindowTitleWithDocumentName];
	NSBeginInformationalAlertSheet(NSLocalizedString(@"Search Failed", nil),
								   NSLocalizedString(@"OK", nil),
								   nil,
								   nil,
								   [self windowForSheet],
								   nil,
								   NULL,
								   NULL,
								   NULL,
								   NSLocalizedString(@"The search failed due to the following error:\n\n%@", nil), 
								   [[notification userInfo] objectForKey:iManSearchError]);
}	

#pragma mark -
#pragma mark Results Outline View Data Source

- (id)outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item
{
    if (item == nil) 
        return [sortedResults objectAtIndex:index];

    return [item objectAtIndex:index];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    return [item isKindOfClass:[NSArray class]];
}

- (int)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
    if (item == nil)
        return [sortedResults count];

    return [(NSArray *)item count];
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{    
    if ([[tableColumn identifier] isEqualToString:@"Page"]) {
        if ([item isKindOfClass:[NSArray class]]) { // if it is a multiple-page entry
            return [[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:NSLocalizedString(@"%@ (%d pages)", nil), [(NSArray *)item objectAtIndex:0], [(NSArray *)item count]]
                                                    attributes:[NSDictionary dictionaryWithObject:[NSColor disabledControlTextColor] forKey:NSForegroundColorAttributeName]] autorelease];
        } else {
            return item;
        }
    } else {
        id ret = [[[self search] results] objectForKey:item];

        return (ret == nil) ? @"" : ret;
    }

    return @"";
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    return NO;
}

#pragma mark -
#pragma mark Cleanup

- (void)dealloc
{
	[search_ release];
    [sortedResults release];
    [super dealloc];
}

@end

// This category is for sorting the results of an apropos/whatis search,
// where one result might have many names. The results are stored in a
// dictionary whose keys are either arrays of names or simply strings.
// This category sorts that list, by sorting arrays as their first
// element would be sorted (it is guaranteed to be a string).

@interface NSObject (iManSorting)

- (NSComparisonResult)iManResultSort:(id)other;

@end

@implementation NSObject (iManSorting)

- (NSComparisonResult)iManResultSort:(id)other
{
    id this, anOther;
    
    if ([self isKindOfClass:[NSArray class]])
        this = [(NSArray *)self objectAtIndex:0];
    else
        this = self;

    if ([other isKindOfClass:[NSArray class]])
        anOther = [(NSArray *)other objectAtIndex:0];
    else
        anOther = other;
    return [this localizedCompare:anOther];
}

@end