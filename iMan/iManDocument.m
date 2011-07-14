//
//  iManDocument.m
//  iMan
//  Copyright (c) 2004-2010 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import "iManDocument.h"
#import "iManFindResult.h"
#import "iManPageBrowserSortDescriptor.h"
#import <iManEngine/iManEngine.h>
#import <unistd.h>
#import "iMan.h"
#import "iManConstants.h"
#import "iManDocumentWindowController.h"
#import "iManIndexingWindowController.h"
#import "iManHistoryQueue.h"
#import "NSUserDefaults+DMRArchiving.h"
#import "RegexKitLite.h"
#import "RegexKitLiteSupport/RKLMatchEnumerator.h"

// Indices of tab view panes.
enum {
    kiManPageTabIndex,
    kiManNoPageTabIndex,
    kiManLoadingTabIndex
};

enum {
	iManAproposTabDisplaying,
	iManAproposTabSearching
};

// Tags of search field menu items.
enum {
	kiManMatchCaseMenuItemTag = 10,
	kiManUseRegularExpressionsMenuItemTag
};

@implementation iManDocument

@synthesize useRegexps, caseSensitive, browserTree = _browserTree;

#pragma mark -
#pragma mark NSDocument Overrides

- init
{
	self = [super init];
	
	if (self != nil) {
		_documentState = iManDocumentStateNone;
		_history = [[iManHistoryQueue alloc] init];
		[self setBrowserTree:[[[NSApp delegate] sharedPageDatabase] sections]];
		[NSApp addObserver:self forKeyPath:@"delegate.sharedPageDatabase.sections" options:0 context:NULL];
		[self setCaseSensitive:NO];
		[self setUseRegexps:NO];
	}
	
	return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"delegate.sharedPageDatabase.sections"]) {
		[self setBrowserTree:[[[NSApp delegate] sharedPageDatabase] sections]];
	} else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}

}

- (NSURL *)fileURL
{
	// Override NSDocument method to return a correct file URL for the current page, regardless of whether it was loaded directly or searched.
	if ([self page] != nil) 		
		return [NSURL fileURLWithPath:[[self page] path]];
	
	return nil;
}

- (void)windowControllerDidLoadNib:(NSWindowController *)windowController;
{
    NSScrollView *scrollView = (NSScrollView *)[[manpageView superview] superview];
    NSTextContainer *textContainer = [manpageView textContainer];
		
    // Set the scroll view, text container, and text view up to behave properly (no wrapping).
    // This is largely derived from Apple's TextSizingExample code.
    // Note: 1.0e7 is the "LargeNumberForText" used there, it should not be changed.
    
	[textContainer setWidthTracksTextView:NO];
    [textContainer setHeightTracksTextView:NO];
    [textContainer setContainerSize:NSMakeSize(1.0e7, 1.0e7)];
	
	[manpageView setMinSize:[scrollView contentSize]];
    [manpageView setMaxSize:NSMakeSize(1.0e7, 1.0e7)];
    [manpageView setHorizontallyResizable:YES];
    [manpageView setVerticallyResizable:YES];
    [manpageView setAutoresizingMask:NSViewNotSizable];
	
	// Set up the sort descriptors and double-click action for the browser
	[browserController setSortDescriptors:[NSArray arrayWithObject:[[[iManPageBrowserSortDescriptor alloc] initWithKey:@"iManPageBrowserTitle" ascending:YES] autorelease]]];
	[pageBrowser setTarget:self];
	[pageBrowser setDoubleAction:@selector(browserGoToPage:)];
	
	// Setup the search field menu. 
	for (id anObject in [iManSearch searchTypes]) {
		NSMenuItem *menuItem;
		
		[aproposFieldMenu insertItemWithTitle:[iManSearch localizedNameForSearchType:anObject]
										  action:@selector(setAproposFieldSearchType:)
								   keyEquivalent:@""
									  atIndex:0];
		menuItem = [[aproposFieldMenu itemArray] objectAtIndex:0]; 
		[menuItem setRepresentedObject:anObject];
		
		// The default is apropos.
		if ([anObject isEqualToString:iManSearchTypeApropos])
			[menuItem setState:NSOnState];
		[menuItem setTarget:self];
	}
	_savedSearchType = [iManSearchTypeApropos retain];
	[[aproposField cell] setSearchMenuTemplate:aproposFieldMenu];
	
	// Setup the in-page search field menu.
	[[findDrawerSearchFieldMenu itemWithTag:kiManUseRegularExpressionsMenuItemTag] setState:[self useRegexps]];
	[[findDrawerSearchFieldMenu itemWithTag:kiManMatchCaseMenuItemTag] setState:[self caseSensitive]];
	[[findDrawerSearchField cell] setSearchMenuTemplate:findDrawerSearchFieldMenu];
	
	// Setup the search results view.
	[aproposResultsView setDoubleAction:@selector(openSearchResultPage:)];
		
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(displayFontDidChange:)
                                                 name:iManStyleChangedNotification
                                               object:nil];
	
	[self synchronizeUIWithDocumentState];
}

- (void)makeWindowControllers
{
	iManDocumentWindowController *wc = [[iManDocumentWindowController alloc] initWithWindowNibName:@"iManDocument" owner:self];
	
	[self addWindowController:wc];
	[wc release];
}

- (BOOL)readFromFile:(NSString *)fileName ofType:(NSString *)type
{
    [self loadPage:[iManPage pageWithPath:fileName]];
	
    return ([self page] != nil);
}

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem
{
	SEL action = [anItem action];
    // Only allow printing/exporting/searching if a man page is being displayed.
    if ((action == @selector(printDocument:)) ||
		(action == @selector(reload:)) ||
        (action == @selector(export:)) ||
		(action == @selector(toggleFindDrawer:)) ||
		(action == @selector(performSearch:)))
        return ([self documentState] == iManDocumentStateDisplayingPage);

    // Check undo manager for these.
    if (action == @selector(back:))
        return ([[self history] canGoBack]);
    if (action == @selector(forward:))
        return ([[self history] canGoForward]);
			
    return [super validateUserInterfaceItem:anItem];
}

- (NSString *)displayName
{
    // Construct a string of the form "page(section)". 
	// We rely on our state rather than the page object's -isLoading methods because there are some weird issues with those yielding incorrect values (race conditions based on when the notification is posted, I think).
	if ([self documentState] == iManDocumentStateDisplayingPage) {
		return [NSString stringWithFormat:NSLocalizedString(@"%@(%@)", nil), [[self page] pageName], [[self page] pageSection]];
	} else if ([self documentState] == iManDocumentStateLoadingPage) {
		return NSLocalizedString(@"Loading...", nil);
	}
	
    return NSLocalizedString(@"iMan", nil);
}

- (void)printShowingPrintPanel:(BOOL)flag
{
    NSPrintInfo *printInfo = [self printInfo];
	
    // Need to set NSFitPagination so that the page is scaled horizontally to fit
    // otherwise it is annoyingly clipped at right.
    [printInfo setHorizontalPagination:NSFitPagination];
    [self runModalPrintOperation:[NSPrintOperation printOperationWithView:manpageView
                                                                printInfo:printInfo]
                        delegate:nil
                  didRunSelector:NULL
                     contextInfo:NULL];
}

#pragma mark -
#pragma mark IBActions

- (IBAction)toggleFindDrawer:(id)sender
{
	if (([findDrawer state] == NSDrawerOpeningState) || ([findDrawer state] == NSDrawerOpenState)) {
		[findDrawer close];
	} else {
		if (([aproposDrawer state] == NSDrawerOpeningState) || ([aproposDrawer state] == NSDrawerOpenState))
			[aproposDrawer close];
	
		[findDrawer open];
	}
}

- (IBAction)toggleAproposDrawer:(id)sender
{
	if (([aproposDrawer state] == NSDrawerOpeningState) || ([aproposDrawer state] == NSDrawerOpenState)) {
		[aproposDrawer close];
	} else {
		if (([findDrawer state] == NSDrawerOpeningState) || ([findDrawer state] == NSDrawerOpenState))
			[findDrawer close];
		
		[aproposDrawer open];
		[aproposField becomeFirstResponder];
	}
}

- (IBAction)export:(id)sender
{
    NSSavePanel *savePanel = [NSSavePanel savePanel];

    if (accessoryView == nil)
        [NSBundle loadNibNamed:@"iManSavePanelAccessory" owner:self];

    [savePanel setAccessoryView:accessoryView];
    [savePanel setRequiredFileType:@"rtf"];
    [savePanel setExtensionHidden:NO];
    [formatMenu selectItemAtIndex:0];


    [savePanel beginSheetForDirectory:nil
                                 file:[[[self page] pageName] stringByAppendingPathExtension:@"rtf"]
                       modalForWindow:[[[self windowControllers] lastObject] window]
                        modalDelegate:self
                       didEndSelector:@selector(exportPanelDidEnd:returnCode:contextInfo:)
                          contextInfo:NULL];
    
}

- (IBAction)performSearch:(id)sender
{
	NSMutableArray *results;
	
	if (([self page] == nil) || (![[self page] isLoaded]))
		return;

	results = [[NSMutableArray alloc] init];

    if (useRegexps) {
        NSEnumerator *enumerator;
        NSString *string = [[manpageView textStorage] string];
		NSValue *match;
		
        enumerator = [string matchEnumeratorWithRegex:[findDrawerSearchField stringValue] options: (caseSensitive ? RKLNoOptions : RKLNoOptions | RKLCaseless)];

        while ((match = [enumerator nextObject]) != nil) {  
			[results addObject:[iManFindResult findResultWithRange:[match rangeValue] inAttributedString:[manpageView textStorage]]];
            
        }
    } else {
        CFArrayRef ranges;
        CFIndex index;
        NSString *string = [[manpageView textStorage] string];

        ranges = CFStringCreateArrayWithFindResults(kCFAllocatorDefault,
													(CFStringRef)string,
													(CFStringRef)[findDrawerSearchField stringValue],
													CFRangeMake(0, [string length]),
													caseSensitive ? 0 : kCFCompareCaseInsensitive);

        if (ranges != NULL) {
            for (index = 0; index < CFArrayGetCount(ranges); index++) {
                const CFRange *rangePtr;
                NSRange range;

                rangePtr = CFArrayGetValueAtIndex(ranges, index);
                range = NSMakeRange(rangePtr->location, rangePtr->length);
				[results addObject:[iManFindResult findResultWithRange:range inAttributedString:[manpageView textStorage]]];
            }
        }
    }
    
	[self setFindResults:results];
	[results release];
}

- (IBAction)takeUseRegexpsFrom:(id)sender;
{
	[self setUseRegexps:![sender state]];
	[[findDrawerSearchFieldMenu itemWithTag:kiManUseRegularExpressionsMenuItemTag] setState:[self useRegexps]];
	[[findDrawerSearchField cell] setSearchMenuTemplate:findDrawerSearchFieldMenu];
	
	// Re-run the search.
	[self performSearch:findDrawerSearchField];
}

- (IBAction)takeCaseSensitiveFrom:(id)sender
{
	[self setCaseSensitive:![sender state]];
	[[findDrawerSearchFieldMenu itemWithTag:kiManMatchCaseMenuItemTag] setState:[self caseSensitive]];
	[[findDrawerSearchField cell] setSearchMenuTemplate:findDrawerSearchFieldMenu];

	// Re-run the search.
	[self performSearch:findDrawerSearchField];
}

- (IBAction)back:(id)sender
{
	if ([self documentState] != iManDocumentStateDisplayingPage) {
		// We failed to load a page, sending us to the No Page tab, or we are loading a page. The history queue still has the last good page on the top, so we cannot go "back" -- we'll end up two pages ago. Just reset ourselves to the top of the queue.
		[self setPage:[[[self history] history] objectAtIndex:[[self history] historyIndex]]];
	} else {
		[self setPage:[[self history] back]];
	}
	[self setDocumentState:iManDocumentStateDisplayingPage];
	[self synchronizeUIWithDocumentState];
}

- (IBAction)forward:(id)sender
{
	[self setPage:[[self history] forward]];
	[self setDocumentState:iManDocumentStateDisplayingPage];
	[self synchronizeUIWithDocumentState];
}

- (IBAction)clearHistory:(id)sender
{
	[[self history] clearHistory];
	[[[[self windowControllers] lastObject] toolbar] validateVisibleItems];
}

- (IBAction)goToPageField:(id)sender
{
	[addressField becomeFirstResponder];
}
	 
- (IBAction)performAproposSearch:(id)sender
{
	if (![[sender stringValue] length] == 0) {		
		[self performSearchForTerm:[sender stringValue] type:_savedSearchType];
	}
}	

- (IBAction)setAproposFieldSearchType:(id)sender
{
	[_savedSearchType release];
	_savedSearchType = [[sender representedObject] retain];
	
	// Clear checks by other search-type menu items.
	for (NSMenuItem *menuItem in [aproposFieldMenu itemArray]) {
		if ([menuItem action] == @selector(setAproposFieldSearchType:))
			[menuItem setState:NSOffState];
		if ([[menuItem representedObject] isEqualToString:_savedSearchType])
			[menuItem setState:NSOnState];
	}
	
	[[aproposField cell] setSearchMenuTemplate:aproposFieldMenu];
	
	// If there is a search open, and the text in the search field has not changed since that search was run, go ahead and re-run the search with the new options.
	if (([self search] != nil) && [[[self search] term] isEqualToString:[aproposField stringValue]])
		[self performAproposSearch:aproposField];
}

- (IBAction)loadRequestedPage:(id)sender
{
	[self loadPageWithStringInput:[sender stringValue]];
}

- (IBAction)browserGoToPage:(id)sender
{
	NSDictionary *entry;
	
	entry = [[[pageBrowser selectedCell] representedObject] representedObject];
	if ((entry != nil) && ([entry isKindOfClass:[NSString class]]))
		[self loadPage:[iManPage pageWithPath:entry]];
}

- (IBAction)reload:(id)sender
{
	[self setDocumentState:iManDocumentStateLoadingPage];
	[self synchronizeUIWithDocumentState];
	[[self page] reload];
}

- (IBAction)openSearchResultPage:(id)sender
{
	NSString *result;
	
	if ([aproposResultsView clickedRow] != -1) { // Send on double-click
		result = [[[[self search] results] objectAtIndex:[aproposResultsView clickedRow]] firstPageName];
	} else { // sent on enter.
		result = [[[[self search] results] objectAtIndex:[[aproposResultsView selectedRowIndexes] firstIndex]] firstPageName];
	}

	if ([[NSUserDefaults standardUserDefaults] integerForKey:iManHandleSearchResults] == kiManHandleLinkInNewWindow) 
		[[NSApp delegate] loadURLInNewDocument:[NSURL URLWithString:[NSString stringWithFormat:@"man:%@", result]]];
	else
		[self loadPageWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"man:%@", result]]];
}

- (IBAction)pageSelectionSheetOK:(id)sender
{
	[NSApp endSheet:pageSelectionSheet returnCode:NSOKButton];
}

- (IBAction)pageSelectionSheetCancel:(id)sender
{
	[NSApp endSheet:pageSelectionSheet returnCode:NSCancelButton];
}

#pragma mark -

- (IBAction)changeExportFormat:(id)sender
{
    [((NSSavePanel *)[formatMenu window]) setRequiredFileType:[[NSArray arrayWithObjects:@"rtf", @"txt", nil] objectAtIndex:[sender indexOfSelectedItem]]];
}

#pragma mark -
#pragma mark Panel -didEnds 

- (void)exportPanelDidEnd:(NSSavePanel *)savePanel returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    [savePanel orderOut:self];
    if (returnCode == NSOKButton) {
        id fileData = nil;
        enum {
            iManFormatRTF,
            iManFormatPlainText
        } format = [formatMenu indexOfSelectedItem];
		
        switch (format) {
            case iManFormatRTF:
                fileData = [[manpageView textStorage] RTFFromRange:NSMakeRange(0, [[manpageView textStorage] length]) documentAttributes:nil];
                break;
            case iManFormatPlainText:
                fileData = [[[manpageView textStorage] string] dataUsingEncoding:NSASCIIStringEncoding];
				break;
        }
		
        if (fileData != nil) {
            [fileData writeToFile:[savePanel filename] atomically:YES];
        } else {
            NSBeginInformationalAlertSheet(NSLocalizedString(@"Export failed.", nil),
                                           NSLocalizedString(@"OK", nil),
                                           nil, nil,
                                           [[[self windowControllers] lastObject] window],
                                           nil, NULL, NULL, NULL,
                                           NSLocalizedString(@"iMan was unable to export the page to the requested format.", nil));
        }
    }
}

- (void)shouldUpdateIndexPanelDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];
	
	if (returnCode == NSOKButton) {
		iManIndexingWindowController *indexingWindowController = [[iManIndexingWindowController alloc] initWithSelectedIndexes:[NSArray arrayWithObject:[(iManIndex *)contextInfo autorelease]]];
		int returnCode;
		
		returnCode = [indexingWindowController doRunModalUpdateWindow];
		
		if (returnCode == NSOKButton)
			[self performSelector:@selector(performAproposSearch:) withObject:aproposField afterDelay:0.01];
		
		// Ignore cancel, ignore failure (indexing window will notify user of failure).
		
		[indexingWindowController release];
	}
}

- (void)pageSelectionSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];
	
	if (returnCode == NSOKButton) {
		[self loadPage:[iManPage pageWithPath:[_pageChoices objectAtIndex:[pageSelectionList selectedRow]]]];
		[_pageChoices release];
		_pageChoices = nil;
	}
}
		 

#pragma mark -
#pragma mark UI Methods

static NSString *const iManPageNameWithParenthesesRegex = @"^(\\S+)\\s*\\(([0-9n][a-zA-Z]*)\\)$";
static NSString *const iManPageNameAndSectionRegex = @"^(\\S+)\\s+([0-9n][a-zA-Z]*)$";
static NSString *const iManSectionAndNameRegex = @"^([0-9n][a-zA-Z]*)\\s+(\\S+)$";

- (void)loadPageWithStringInput:(NSString *)string
{
	// Determine what the user has requested.
	// 1) if the input looks like a URL (i.e., begins with man:), treat it as appropriate.
	// 2) if the input looks like a page name and section, or a bare page name, attempt to locate that page.
	NSString *input = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
	if ([input length] > 0) {
		if ([input hasPrefix:@"man:"]) {
			// Treat input as man: URL.
			[self loadPageWithURL:[NSURL URLWithString:input]];
		} else if ([input isMatchedByRegex:iManPageNameWithParenthesesRegex]) {
			// Treat input as "groff(1) (ignoring spaces).
			[self loadPageWithName:[input stringByMatching:iManPageNameWithParenthesesRegex capture:1]
						   section:[input stringByMatching:iManPageNameWithParenthesesRegex capture:2]];
		} else if ([input isMatchedByRegex:iManPageNameAndSectionRegex]) {
			// Treat input as "groff 1"
			[self loadPageWithName:[input stringByMatching:iManPageNameAndSectionRegex capture:1]
						   section:[input stringByMatching:iManPageNameAndSectionRegex capture:2]];
		} else if ([input isMatchedByRegex:iManSectionAndNameRegex]) {
			// Treat input as "1 groff"
			[self loadPageWithName:[input stringByMatching:iManSectionAndNameRegex capture:2]
						   section:[input stringByMatching:iManSectionAndNameRegex capture:1]];
		} else {
			// Treat the whole input as the page name.
			[self loadPageWithName:input section:nil];
		}
	}
}

- (void)loadPageWithURL:(NSURL *)url
{
	[self loadPageWithName:[url pageName] section:[url pageSection]];
}

- (void)loadPageWithName:(NSString *)pageName section:(NSString *)pageSection
{
	NSArray *paths;
	iManPageDatabase *database = [[NSApp delegate] sharedPageDatabase];
	
	if (pageSection == nil) {
		paths = [database pagesWithName:pageName];
	} else {
		paths = [database pagesWithName:pageName inSection:pageSection];
	}
	
	// Try forcing lowercase if the page isn't found.
	if ([paths count] == 0) {
		if (pageSection == nil) {
			paths = [database pagesWithName:[pageName lowercaseString]];
		} else {
			paths = [database pagesWithName:[pageName lowercaseString] inSection:[pageSection lowercaseString]];
		}
	}		
	
	if ([paths count] == 0) {
		NSBeginAlertSheet(NSLocalizedString(@"The requested man page could not be found.", nil), NSLocalizedString(@"OK", nil), nil, nil, [self windowForSheet], self, NULL, NULL, NULL, NSLocalizedString(@"iMan was unable to find a page matching the requested title and section. Try searching to find this page.", nil));
	} else if ([paths count] == 1) {
		[self loadPage:[iManPage pageWithPath:[paths objectAtIndex:0]]];
	} else {
		// Multiple pages found. If the user has set "don't show selection panel for duplicates" in the preferences, check if this is a "duplicate" (one or more pages in different directories with identical basenames and sections).
		if (![[NSUserDefaults standardUserDefaults] boolForKey:iManShowPageSelectionPanelForDuplicates]) {
			BOOL areDuplicates = YES;
			NSString *section = [[paths objectAtIndex:0] pageSection], *pageName = [[paths objectAtIndex:0] pageName];
						
			for (NSString *aPath in [paths subarrayWithRange:NSMakeRange(1, [paths count] - 1)]) {
				if (![[aPath pageName] isEqualToString:pageName] || ![[aPath pageSection] isEqualToString:section]) {
					areDuplicates = NO;
					break;
				}
			}
			
			if (areDuplicates) {
				[self loadPage:[iManPage pageWithPath:[paths objectAtIndex:0]]];
				return;
			}
		}
		_pageChoices = [paths retain];
		[pageSelectionList reloadData];
		[pageSelectionList selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
		[NSApp beginSheet:pageSelectionSheet modalForWindow:[self windowForSheet] modalDelegate:self didEndSelector:@selector(pageSelectionSheetDidEnd:returnCode:contextInfo:) contextInfo:NULL];
	}
}

- (void)loadPage:(iManPage *)page
{
	if (page != nil) {
		if (page != [self page]) {
			[self setPage:page];
			if (![page isLoaded]) {
				[self setDocumentState:iManDocumentStateLoadingPage];
				[page load];
				[self synchronizeUIWithDocumentState];
			} else {
				[[self history] push:page];
				[self setDocumentState:iManDocumentStateDisplayingPage];
				[self synchronizeUIWithDocumentState];
			}
		}
	} else {
		NSBeginAlertSheet(NSLocalizedString(@"The requested page could not be loaded.", nil),
						  NSLocalizedString(@"OK", nil),
						  nil, nil, 
						  [[[self windowControllers] lastObject] window], 
						  nil, NULL, NULL, NULL, 
						  NSLocalizedString(@"iMan cannot load the requested page because an unknown error occurred. Please make sure you requested a valid page name.", nil));
	}
}

- (void)performSearchForTerm:(NSString *)term type:(NSString *)type
{
	iManIndex *index = [iManSearch indexForSearchType:type];
	
	if ([index isValid]) {
		iManSearch *search = [iManSearch searchWithTerm:term searchType:type];

		[self setSearch:search];
		[aproposTabView selectTabViewItemAtIndex:iManAproposTabSearching];
		[aproposDrawer open:self];
		[search search];
	} else {
		NSBeginAlertSheet(NSLocalizedString(@"Index out of date.", nil), 
						  NSLocalizedString(@"Update", nil),
						  NSLocalizedString(@"Cancel", nil),
						  nil,
						  [[[self windowControllers] lastObject] window],
						  self,
						  @selector(shouldUpdateIndexPanelDidEnd:returnCode:contextInfo:),
						  NULL,
						  [index retain],
						  NSLocalizedString(@"The index for the search type \"%@\" needs to be updated before it can be searched. Do you want to update the index now?", nil),
						  [iManSearch localizedNameForSearchType:type]);
	}
}

- (void)synchronizeUIWithDocumentState
{
	NSWindowController *windowController = [[self windowControllers] lastObject];
	
	switch ([self documentState]) {
		case iManDocumentStateNone:
			[tabView selectTabViewItemAtIndex:kiManNoPageTabIndex];
			[addressField setStringValue:@""];
			break;
		case iManDocumentStateDisplayingPage:
			[tabView selectTabViewItemAtIndex:kiManPageTabIndex];
			[addressField setStringValue:[NSString stringWithFormat:@"%@(%@)", [[self page] pageName], [[self page] pageSection]]];
			[[windowController window] makeFirstResponder:manpageView];
			[[manpageView textStorage] setAttributedString:[[self page] pageWithStyle:[self displayStringOptions]]];
			[manpageView moveToBeginningOfDocument:self];
			[[[windowController window] toolbar] validateVisibleItems];			
			break;
		case iManDocumentStateLoadingPage:
			[loadingMessageLabel setStringValue:NSLocalizedString(@"Loading...", nil)];
			[tabView selectTabViewItemAtIndex:kiManLoadingTabIndex];
			[progressIndicator startAnimation:self];
			break;
	}
	// Our -displayName changes each time a new page is loaded.
	[windowController synchronizeWindowTitleWithDocumentName];
}

- (NSDictionary *)displayStringOptions
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSFontManager *fm = [NSFontManager sharedFontManager];
	NSMutableDictionary *defaultStyle, *boldStyle, *italicStyle, *boldItalicStyle;
	NSFont *font = [defaults archivedObjectForKey:iManDefaultStyle];
	
	defaultStyle = [NSDictionary dictionaryWithObject:font forKey:NSFontAttributeName];
	boldStyle = [[defaultStyle mutableCopy] autorelease];
	italicStyle = [[defaultStyle mutableCopy] autorelease];
	
	if ([defaults boolForKey:iManBoldStyleMakeBold])
		[boldStyle setObject:[fm convertFont:[boldStyle objectForKey:NSFontAttributeName] toHaveTrait:NSBoldFontMask] forKey:NSFontAttributeName];
	if ([defaults boolForKey:iManBoldStyleMakeItalic])
		[boldStyle setObject:[fm convertFont:[boldStyle objectForKey:NSFontAttributeName] toHaveTrait:NSItalicFontMask] forKey:NSFontAttributeName];
	if ([defaults boolForKey:iManBoldStyleMakeUnderline]) 
		[boldStyle setObject:[NSNumber numberWithInt:1] forKey:NSUnderlineStyleAttributeName];
	[boldStyle setObject:[defaults archivedObjectForKey:iManBoldStyleColor] forKey:NSForegroundColorAttributeName];
	
	boldItalicStyle = [[boldStyle mutableCopy] autorelease];
	
	if ([defaults boolForKey:iManUnderlineStyleMakeBold]) {
		[italicStyle setObject:[fm convertFont:[italicStyle objectForKey:NSFontAttributeName] toHaveTrait:NSBoldFontMask] forKey:NSFontAttributeName];
		[boldItalicStyle setObject:[fm convertFont:[boldItalicStyle objectForKey:NSFontAttributeName] toHaveTrait:NSBoldFontMask] forKey:NSFontAttributeName];
	}
	if ([defaults boolForKey:iManUnderlineStyleMakeItalic]) {
		[italicStyle setObject:[fm convertFont:[italicStyle objectForKey:NSFontAttributeName] toHaveTrait:NSItalicFontMask] forKey:NSFontAttributeName];
		[boldItalicStyle setObject:[fm convertFont:[boldItalicStyle objectForKey:NSFontAttributeName] toHaveTrait:NSItalicFontMask] forKey:NSFontAttributeName];
	}
	if ([defaults boolForKey:iManUnderlineStyleMakeUnderline]) {
		[italicStyle setObject:[NSNumber numberWithInt:1] forKey:NSUnderlineStyleAttributeName];
		[boldItalicStyle setObject:[NSNumber numberWithInt:1] forKey:NSUnderlineStyleAttributeName];
	}
	[italicStyle setObject:[defaults archivedObjectForKey:iManUnderlineStyleColor] forKey:NSForegroundColorAttributeName];
	
	return [NSDictionary dictionaryWithObjectsAndKeys:
			defaultStyle, iManPageDefaultStyle,
			boldStyle, iManPageBoldStyle,
			italicStyle, iManPageUnderlineStyle,
			boldItalicStyle, iManPageBoldUnderlineStyle,
			[[NSUserDefaults standardUserDefaults] objectForKey:iManShowPageLinks], iManPageUnderlineLinks,
			nil];
}

#pragma mark -
#pragma mark Notifications

- (void)pageLoadDidComplete:(NSNotification *)notification
{
	// If this is not the current page (i.e., if we're not reloading), add this page to our history.
	if (([[self history] historyIndex] == -1) || ([[[self history] history] objectAtIndex:[[self history] historyIndex]] != [self page]))
		[[self history] push:[self page]];
	
	// Update our user interface.
	[self setDocumentState:iManDocumentStateDisplayingPage];
	[self synchronizeUIWithDocumentState];
}

- (void)pageLoadDidFail:(NSNotification *)notification
{
	NSError *error = [[notification userInfo] objectForKey:iManErrorKey];
	NSString *message;
	
	if ([[error domain] isEqualToString:iManEngineErrorDomain]) {
		switch ([error code]) {
			case iManToolNotConfiguredError:
				message = NSLocalizedString(@"Paths are not configured correctly for one or more command-line tools. Please correct these settings in iMan Preferences.", nil);
				break;
			case iManResolveFailedError:
				message = NSLocalizedString(@"The requested man page could not be found.", nil);
				break;
			case iManRenderFailedError:
				message = [NSString stringWithFormat:NSLocalizedString(@"The requested man page could not be rendered. The error returned was \"%@\"", nil), [[[error userInfo] objectForKey:NSUnderlyingErrorKey] localizedDescription]];
				break;
			case iManInternalInconsistencyError:
			default:
				message = NSLocalizedString(@"An unknown internal error has occurred.", nil);
				break;
		}
	} else {
		message = [NSString stringWithFormat:NSLocalizedString(@"The requested man page could not be rendered. The error returned was \"%@\"", nil), [[[error userInfo] objectForKey:NSUnderlyingErrorKey] localizedDescription]];
	}
	
	NSBeginInformationalAlertSheet(NSLocalizedString(@"Access failed.", nil),
								   NSLocalizedString(@"OK", nil),
								   nil, nil,
								   [self windowForSheet],
								   nil, NULL, NULL, NULL,
								   message);
	[self setPage:nil];
	[self setDocumentState:iManDocumentStateNone];
	[self synchronizeUIWithDocumentState];
}

- (void)searchDidComplete:(NSNotification *)notification
{
	// Bindings take care of updating the table view. Update the rest of the UI. (It's possible for searches to be triggered programmatically).
	[aproposField setStringValue:[[self search] term]];
	// Set the search type in the menu.
	for (NSMenuItem *menuItem in [aproposFieldMenu itemArray]) {
		if ([menuItem action] == @selector(setAproposFieldSearchType:))
			[menuItem setState:NSOffState];
		if ([[menuItem representedObject] isEqualToString:[[self search] searchType]])
			[menuItem setState:NSOnState];
	}
	
	[[aproposField cell] setSearchMenuTemplate:aproposFieldMenu];
	
	[aproposTabView selectTabViewItemAtIndex:iManAproposTabDisplaying];
	[aproposDrawer open:self]; // Re-open when the search completes, just in case it's been closed.
}

- (void)searchDidFail:(NSNotification *)notification
{
	NSError *error = [[notification userInfo] objectForKey:iManErrorKey];
	NSString *message;
	
	if ([[error domain] isEqualToString:iManEngineErrorDomain]) {
		switch ([error code]) {
			case iManToolNotConfiguredError:
				message = NSLocalizedString(@"Paths are not configured correctly for one or more command-line tools. Please correct these settings in iMan Preferences.", nil);
				break;
			case iManIndexLockedError:
				message = NSLocalizedString(@"The search index for the selected search type is locked. Please wait for other searches or indexing to finish, then search again.", nil);
				break;
			case iManInternalInconsistencyError:
			default:
				message = NSLocalizedString(@"An unknown internal error has occurred.", nil);
				break;
		}
	} else {
		message = [NSString stringWithFormat:NSLocalizedString(@"The requested man page could not be rendered. The error returned was \"%@\"", nil), [[[error userInfo] objectForKey:NSUnderlyingErrorKey] localizedDescription]];
	}
	NSBeginInformationalAlertSheet(NSLocalizedString(@"Search Failed", nil),
								   NSLocalizedString(@"OK", nil),
								   nil,
								   nil,
								   [self windowForSheet],
								   nil,
								   NULL,
								   NULL,
								   NULL,
								   message);
	[aproposTabView selectTabViewItemAtIndex:iManAproposTabDisplaying];
}

- (void)displayFontDidChange:(NSNotification *)notification
{
    if ([self page] != nil) {
        [[manpageView textStorage] setAttributedString:[[self page] pageWithStyle:[self displayStringOptions]]];
		[findResultsView reloadData];
	}
}

- (void)drawerDidOpen:(NSNotification *)notification
{
	if ([notification object] == findDrawer)
		[findDrawerSearchField becomeFirstResponder];
}

#pragma mark -
#pragma mark Accessors

- (iManPage *)page
{
	return page_;
}

- (void)setPage:(iManPage *)page
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:iManPageLoadDidCompleteNotification object:page_];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:iManPageLoadDidFailNotification object:page_];

	[page retain];
	[page_ release];
	page_ = page;
	
	if (page_ != nil) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pageLoadDidComplete:) name:iManPageLoadDidCompleteNotification object:page_];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pageLoadDidFail:) name:iManPageLoadDidFailNotification object:page_];
		
		if (_findResults != nil) {
			[self setFindResults:nil];
		}
    }
}

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

- (NSArray *)findResults
{
	return _findResults;
}

- (void)setFindResults:(NSArray *)findResults
{
	if (findResults != _findResults) {
		[_findResults release];
		_findResults = [findResults copy];
	}
}

- (iManDocumentState)documentState
{
	return _documentState;
}

- (void)setDocumentState:(iManDocumentState)documentState
{
	_documentState = documentState;
}

- (iManHistoryQueue *)history
{
	return _history;
}

#pragma mark -
#pragma mark NSTextView Delegate

- (BOOL)textView:(NSTextView *)textView clickedOnLink:(id)link atIndex:(NSUInteger)charIndex
{
    if ([[NSUserDefaults standardUserDefaults] integerForKey:iManHandlePageLinks] == kiManHandleLinkInCurrentWindow) {
		[self loadPageWithURL:link];
		return YES;
    }

	// URLs will be passed off to the application-wide handler if appropriate, which will open in a new window.
	return NO;
}

- (NSMenu *)textView:(NSTextView *)view menu:(NSMenu *)menu forEvent:(NSEvent *)event atIndex:(NSUInteger)charIndex
{
	NSMenu *newMenu = [[NSMenu alloc] init];
	NSMenuItem *item;

	if ([[[view textStorage] attributesAtIndex:charIndex effectiveRange:NULL] objectForKey:NSLinkAttributeName] != nil) {
		item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Open Link", @"Item title for context menu") action:@selector(openLink:) keyEquivalent:@""];
		[item setTarget:self];
		[item setRepresentedObject:[[[view textStorage] attributesAtIndex:charIndex effectiveRange:NULL] objectForKey:NSLinkAttributeName]];
		[newMenu addItem:item];
		[item release];
		
		item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Open Link in New Window", @"Item title for context menu") action:@selector(openLinkInNewWindow:) keyEquivalent:@""];
		[item setTarget:self];
		[item setRepresentedObject:[[[view textStorage] attributesAtIndex:charIndex effectiveRange:NULL] objectForKey:NSLinkAttributeName]];
		[newMenu addItem:item];
		[item release];
	}

	// Check to see if there is a non-space selection
	NSArray *selection = [manpageView selectedRanges];
	
	if ((selection != nil) && ([selection count] > 0)) {
		NSRange range = [[selection objectAtIndex:0] rangeValue];
		NSString *selectedText;
		
		selectedText = [[[[[self page] page] string] substringWithRange:range] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

		if ([selectedText length] > 0) {
			item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Open Page with this Title", @"Item title for context menu") action:@selector(openPageFromSelection:) keyEquivalent:@""];
			[item setTarget:self];	
			[newMenu addItem:item];
			[item release];
			
			item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Apropos Search for Selection", @"Item title for context menu") action:@selector(aproposSearchForSelection:) keyEquivalent:@""];
			[item setTarget:self];	
			[newMenu addItem:item];
			[item release];
			
			[newMenu addItem:[NSMenuItem separatorItem]];
		}
		[selectedText release];
	}
	
	item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Copy", @"Item title for context menu") action:@selector(copy:) keyEquivalent:@""];
	[item setTarget:nil];	
	[newMenu addItem:item];
	[item release];	
	
	return [newMenu autorelease];
}

- (IBAction)openLink:(id)sender
{
	[self loadPageWithURL:[sender representedObject]];
}

- (IBAction)openLinkInNewWindow:(id)sender
{
	[[NSApp delegate] loadURLInNewDocument:[sender representedObject]];
}

- (IBAction)openPageFromSelection:(id)sender
{
	NSArray *selection = [manpageView selectedRanges];
	
	if ((selection != nil) && ([selection count] > 0)) {
		NSRange range = [[selection objectAtIndex:0] rangeValue];
		
		[self loadPageWithStringInput:[[[[self page] page] string] substringWithRange:range]];
	}	
}

- (IBAction)aproposSearchForSelection:(id)sender
{
	NSArray *selection = [manpageView selectedRanges];
	
	if ((selection != nil) && ([selection count] > 0)) {
		NSRange range = [[selection objectAtIndex:0] rangeValue];
		
		[self performSearchForTerm:[[[[self page] page] string] substringWithRange:range] type:iManSearchTypeApropos];
	}
}

#pragma mark -
#pragma mark Page Selection Sheet Data Source

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	if (_pageChoices)
		return [_pageChoices count];
	
	return 0;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	if (_pageChoices) {
		NSString *path = [_pageChoices objectAtIndex:row];
		
		return [NSString stringWithFormat:@"%@(%@) — %@", [path pageName], [path pageSection], path];
	}
	
	return nil;
}

- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	return NO;
}

#pragma mark -
#pragma mark Find Results Table Delegate

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	if ([notification object] == findResultsView) {
		if ([findResultsView selectedRow] != -1) {
			NSRange range = [[[self findResults] objectAtIndex:[findResultsView selectedRow]] range];
			[manpageView setSelectedRange:range];
			[manpageView scrollRangeToVisible:range];
			[manpageView showFindIndicatorForRange:range];
		}
	}
}

#pragma mark -
#pragma mark Cleanup

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[NSApp removeObserver:self forKeyPath:@"delegate.sharedPageDatabase.sections"];
	// Release top-level nib objects. Note that those in iManDocument.nib are automatically released by the window controller.
    [accessoryView release]; // loaded from iManSavePanelAccessory.nib
	// Release instance variables.
    [_history release];
	[_savedSearchType release];
    [_findResults release];
	[_browserTree release];
	[page_ release];
	[search_ release];
    [super dealloc];
}

@end