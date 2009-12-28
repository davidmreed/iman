//
//  iManDocument.m
//  iMan
//  Copyright (c) 2004-2009 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import "iManDocument.h"
#import <iManEngine/iManEngine.h>
#import <unistd.h>
#import "iMan.h"
#import "iManConstants.h"
#import "iManIndexingWindowController.h"
#import "NSUserDefaults+DMRArchiving.h"
#import "RegexKitLite/RegexKitLite.h"
#import "RegexKitLiteSupport/RKLMatchEnumerator.h"

// FIXME: items in Recent Documents menu are problematic and if one selects a .gz manpage it throws up an error.

// Indices of tab view panes.
enum {
    kiManPageTabIndex,
    kiManNoPageTabIndex,
    kiManLoadingTabIndex,
	kiManSearchResultsTabIndex
};

// Tags of search field menu items.
enum {
	kiManMatchCaseMenuItemTag = 10,
	kiManUseRegularExpressionsMenuItemTag
};

// Local constants for this file only.
static NSString *const iManDocumentToolbarIdentifier = @"iManDocumentToolbarIdentifier";

static NSString *const iManToolbarItemSection = @"iManToolbarItemSection";
static NSString *const iManToolbarItemManpage = @"iManToolbarItemManpage";
static NSString *const iManToolbarItemReload = @"iManToolbarItemReload";
static NSString *const iManToolbarItemBack = @"iManToolbarItemBack";
static NSString *const iManToolbarItemForward = @"iManToolbarItemForward";
static NSString *const iManToolbarItemToggleFind = @"iManToolbarItemToggleFind";

static NSString *const iManFindResultRange = @"range";
static NSString *const iManFindResultDisplayString = @"string";

@implementation iManDocument

#pragma mark -
#pragma mark NSDocument Overrides

- init
{
	self = [super init];
	
	if (self != nil) {
		_documentState = iManDocumentStateNone;
		_historyUndoManager = [[NSUndoManager alloc] init];
	}
	
	return self;
}

- (NSURL *)fileURL
{
	// Override NSDocument method to return a correct file URL for the current page, regardless of whether it was loaded directly or searched.
	if ([[self page] path] != nil) 		
		return [NSURL fileURLWithPath:[[self page] path]];
	
	return nil;
}

- (void)windowControllerDidLoadNib:(NSWindowController *)windowController;
{
    NSScrollView *scrollView = (NSScrollView *)[[manpageView superview] superview];
    NSTextContainer *textContainer = [manpageView textContainer];
	
    [super windowControllerDidLoadNib:windowController];
	
    // Set the scroll view, text container, and text view up to behave properly.
    // This is largely derived from Apple's TextSizingExample code.
    // Note: 1.0e7 is the "LargeNumberForText" used there, it should not be changed.
	// FIXME: is this necessary these days?
    [scrollView setHasVerticalScroller:YES];
    [scrollView setHasHorizontalScroller:YES];
    [[scrollView contentView] setAutoresizesSubviews:YES];
	
    [textContainer setWidthTracksTextView:NO];
    [textContainer setHeightTracksTextView:NO];
    [textContainer setContainerSize:NSMakeSize(1.0e7, 1.0e7)];
	
    [manpageView setMinSize:[scrollView contentSize]];
    [manpageView setMaxSize:NSMakeSize(1.0e7, 1.0e7)];
    [manpageView setHorizontallyResizable:YES];
    [manpageView setVerticallyResizable:YES];
    [manpageView setAutoresizingMask:NSViewNotSizable];
	
	// Setup the search menu for in-page searches.
	{
		NSMenu *searchFieldMenu = [[[searchField cell] searchMenuTemplate] copy];
		
		shouldMatchCase = shouldUseRegexps = YES;
		[[searchFieldMenu itemWithTag:kiManMatchCaseMenuItemTag] setState:shouldMatchCase];
		[[searchFieldMenu itemWithTag:kiManUseRegularExpressionsMenuItemTag] setState:shouldUseRegexps];
		[[searchField cell] setSearchMenuTemplate:searchFieldMenu];
		[searchFieldMenu release];
	}
	
	// Setup the search field menu. 
	for (id anObject in [iManSearch searchTypes]) {
		NSMenuItem *menuItem;
		
		[addressFieldSearchMenu addItemWithTitle:[iManSearch localizedNameForSearchType:anObject]
										  action:@selector(setAddressFieldSearchType:)
								   keyEquivalent:@""];
		menuItem = [[addressFieldSearchMenu itemArray] lastObject]; 
		[menuItem setRepresentedObject:anObject];
		[menuItem setTarget:self];
	}
	
	// Setup the search results view.
	[aproposResultsView setDoubleAction:@selector(openPage:)];
	[aproposResultsView setAutoresizesOutlineColumn:NO];
		
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(displayFontDidChange:)
                                                 name:iManFontChangedNotification
                                               object:nil];
	
	[self synchronizeUIWithDocumentState];
}

- (NSString *)windowNibName
{
    return @"iManDocument";
}

- (BOOL)readFromFile:(NSString *)fileName ofType:(NSString *)type
{
    [self setPage:[iManPage pageWithPath:fileName]];
	
    return (page_ != nil);
}

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem
{
	BOOL ret = YES;
	SEL action = [anItem action];
	int tabIndex = [tabView indexOfTabViewItem:[tabView selectedTabViewItem]];
	
    // Only allow printing/exporting/searching if a man page is being displayed.
    if ((action == @selector(printDocument:)) ||
		(action == @selector(reload:)) ||
        (action == @selector(export:)) ||
		(action == @selector(toggleFindDrawer:)) ||
		(action == @selector(performSearch:)))
        return (tabIndex == kiManPageTabIndex);
    // Check undo manager for these.
    if (action == @selector(back:))
        return ([_historyUndoManager canUndo] && (tabIndex != kiManLoadingTabIndex));
    if (action == @selector(forward:))
        return ([_historyUndoManager canRedo] && (tabIndex != kiManLoadingTabIndex));
    // Make sure, if we are loading, that another load request doesn't happen, nor should the window close.
    if ((action == @selector(loadRequestedPage:)) ||
		(action == @selector(reload:)) ||
		(action == @selector(back:)) ||
		(action == @selector(forward:)) ||
		(action == @selector(performClose:)))
        return (tabIndex != kiManLoadingTabIndex);
	
    return ret;
}

- (NSString *)displayName
{
    // Construct a string of the form "iMan: page(section)". 
	
	if ([self page] != nil) {
		if ([[self page] isLoading])
			return NSLocalizedString(@"iMan: Loading", nil);
		
        if (([[self page] pageSection] != nil) && ([[[self page] pageSection] length] > 0)) {
            return [NSString stringWithFormat:NSLocalizedString(@"iMan: %@(%@)", nil),
					[[self page] pageName],
					[[self page] pageSection]];
        } else {
            return [NSString stringWithFormat:NSLocalizedString(@"iMan: %@", nil), [[self page] pageName]];
        }
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
	[findDrawer toggle:sender];
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

    if (shouldUseRegexps) {
        NSEnumerator *enumerator;
        NSString *string = [[manpageView textStorage] string];
		NSValue *match;
		
        enumerator = [string matchEnumeratorWithRegex:[searchField stringValue] options: (shouldMatchCase ? RKLNoOptions : RKLNoOptions | RKLCaseless)];

        while ((match = [enumerator nextObject]) != nil) {  
			[results addObject:[NSDictionary dictionaryWithObjectsAndKeys:match, iManFindResultRange, [self findResultFromRange:[match rangeValue]], iManFindResultDisplayString, nil]];
            
        }
    } else {
        CFArrayRef ranges;
        CFIndex index;
        NSString *string = [[manpageView textStorage] string];

        ranges = CFStringCreateArrayWithFindResults(kCFAllocatorDefault,
													(CFStringRef)string,
													(CFStringRef)[searchField stringValue],
													CFRangeMake(0, [string length]),
													shouldMatchCase ? 0 : kCFCompareCaseInsensitive);

        if (ranges != NULL) {
            for (index = 0; index < CFArrayGetCount(ranges); index++) {
                const CFRange *rangePtr;
                NSRange range;

                rangePtr = CFArrayGetValueAtIndex(ranges, index);
                range = NSMakeRange(rangePtr->location, rangePtr->length);
				[results addObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSValue valueWithRange:range], iManFindResultRange, [self findResultFromRange:range], iManFindResultDisplayString, nil]];
            }
        }
    }
    
	[self setFindResults:results];
	[results release];
}

- (IBAction)back:(id)sender
{
    [[self historyUndoManager] undo];
}

- (IBAction)forward:(id)sender
{
    [[self historyUndoManager] redo];
}

- (IBAction)clearHistory:(id)sender
{
	[[self historyUndoManager] removeAllActions];
	[[[[self windowControllers] lastObject] toolbar] validateVisibleItems];
}

- (IBAction)loadRequestedPage:(id)sender
{
	// Determine what the user has requested.
	// 1) if the input looks like a URL (i.e., begins with man:, apropos:, or whatis:), treat it as appropriate.
	// 2) if a search option is selected, treat the entire input as the search term for apropos or whatis, which may be a regular expression.
	// 3) if the input looks like a page name and section, or a bare page name, attempt to locate that page.
	// FIXME: implement #2.
	NSMutableString *input = [[[sender stringValue] mutableCopy] autorelease];
	
	// Trim whitespace
	CFStringTrimWhitespace((CFMutableStringRef)input);
	if ([input hasPrefix:@"man:"]) {
		// Treat input as man: URL.
		[self loadPageWithURL:[NSURL URLWithString:input]];
	} else if ([input hasPrefix:@"apropos:"]) {
		// Treat rest of input as apropos search term.
		[input deleteCharactersInRange:NSMakeRange(0, [@"apropos" length])];
		[self performSearchForTerm:input type:iManSearchTypeApropos];
	} else if ([input hasPrefix:@"whatis:"]) {
		// Treat rest of input as whatis search term.		
		[input deleteCharactersInRange:NSMakeRange(0, [@"whatis" length])];
		[self performSearchForTerm:input type:iManSearchTypeWhatis];
	} else if ([input isMatchedByRegex:@"(\\S+)\\s*\\(([0-9n][a-zA-Z]*)\\)"]) {
		// Treat input as "groff(1) (ignoring spaces).
		[self loadPageWithName:[input stringByMatching:@"(\\S+)\\s*\\(([0-9n][a-zA-Z]*)\\)" capture:1]
					   section:[input stringByMatching:@"(\\S+)\\s*\\(([0-9n][a-zA-Z]*)\\)" capture:2]];
	} else if ([input isMatchedByRegex:@"(\\S+)\\s+([0-9n][a-zA-Z]*)"]) {
		// Treat input as "groff 1"
		[self loadPageWithName:[input stringByMatching:@"(\\S+)\\s+([0-9n][a-zA-Z]*)" capture:1]
					   section:[input stringByMatching:@"(\\S+)\\s+([0-9n][a-zA-Z]*)" capture:2]];
	} else if ([input isMatchedByRegex:@"([0-9n][a-zA-Z]*)\\s+(\\S+)"]) {
		// Treat input as "1 groff"
		[self loadPageWithName:[input stringByMatching:@"([0-9n][a-zA-Z]*)\\s+(\\S+)" capture:2]
					   section:[input stringByMatching:@"([0-9n][a-zA-Z]*)\\s+(\\S+)" capture:1]];
	} else {
		// Treat the whole input as the page name.
		[self loadPageWithName:input section:nil];
	}
}

- (IBAction)reload:(id)sender
{
	[self setDocumentState:iManDocumentStateLoadingPage];
	[self synchronizeUIWithDocumentState];
	[[self page] reload];
}

#pragma mark -

- (IBAction)openSearchResultPage:(id)sender
{
    id item = [aproposResultsView itemAtRow:[aproposResultsView clickedRow]];
	
	// items which are NSArrays represent pages documenting more than one command. The first item in the array will bring up the page as well as any other.
    if ([item isKindOfClass:[NSArray class]])
        item = [item objectAtIndex:0];
	
	if ([[NSUserDefaults standardUserDefaults] integerForKey:iManHandleSearchResults] == kiManHandleLinkInNewWindow) 
		[iMan loadURLInNewDocument:[NSURL URLWithString:[NSString stringWithFormat:@"man:%@", item]]];
	else
		[self loadPageWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"man:%@", item]]];
}

#pragma mark -

- (IBAction)setUseRegularExpressions:(id)sender
{
	NSMenu *searchFieldMenu = [[[searchField cell] searchMenuTemplate] copy];

	shouldUseRegexps = ([sender state] == NSOnState) ? NO : YES;
	[[searchFieldMenu itemWithTag:kiManUseRegularExpressionsMenuItemTag] setState:shouldUseRegexps];
	[[searchField cell] setSearchMenuTemplate:searchFieldMenu];
	[searchFieldMenu release];
	[self performSearch:searchField];
}

- (IBAction)setCaseSensitive:(id)sender
{
	NSMenu *searchFieldMenu = [[[searchField cell] searchMenuTemplate] copy];
	
	shouldMatchCase = ([sender state] == NSOnState) ? NO : YES;
	[[searchFieldMenu itemWithTag:kiManMatchCaseMenuItemTag] setState:shouldMatchCase];
	[[searchField cell] setSearchMenuTemplate:searchFieldMenu];
	[searchFieldMenu release];
	[self performSearch:searchField];
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
		// FIXME: The GUI behaves oddly now for some reason -- the new view doesn't swap in before the window resizes, and I had to click the button twice. 
		iManIndexingWindowController *indexingWindowController =  [[iManIndexingWindowController alloc] initWithSelectedIndexes:[NSArray arrayWithObject:[(NSString *)contextInfo autorelease]]];
		int returnCode;
		
		returnCode = [indexingWindowController doRunModalUpdateWindow];
		
		if (returnCode == NSOKButton)
			[self performSelector:@selector(loadRequestedPage:) withObject:self afterDelay:0.01];
		
		// Ignore cancel, ignore failure (indexing window will notify user of failure).
		
		[indexingWindowController release];
	}
}

#pragma mark -
#pragma mark UI Methods

- (void)loadPageWithURL:(NSURL *)url
{
	iManPage *page = [iManPage pageWithURL:url];
	
	if (page != nil) {
		[self setPage:page];
		if (![page isLoaded]) {
			[self setDocumentState:iManDocumentStateLoadingPage];
			[self synchronizeUIWithDocumentState];
			[page load];
		} else {
			[self setDocumentState:iManDocumentStateDisplayingPage];
			[self synchronizeUIWithDocumentState];
		}
	} else {
		NSBeginAlertSheet(NSLocalizedString(@"The requested page could not be loaded.", nil),
						  NSLocalizedString(@"OK", nil),
						  nil, nil, 
						  [[[self windowControllers] lastObject] window], 
						  nil, NULL, NULL, NULL, 
						  NSLocalizedString(@"iMan cannot load the requested page. Please make sure the URL is valid.", nil));
	}
}

- (void)loadPageWithName:(NSString *)pageName section:(NSString *)pageSection
{
	iManPage *page = [iManPage pageWithName:pageName inSection:pageSection];
	
	if (page != nil) {
		[self setPage:page];
		if (![page isLoaded]) {
			[self setDocumentState:iManDocumentStateLoadingPage];
			[self synchronizeUIWithDocumentState];
			[page load];
		} else {
			[self setDocumentState:iManDocumentStateDisplayingPage];
			[self synchronizeUIWithDocumentState];
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
		if (_searchResults != nil) {
			[_searchResults release];
			_searchResults = nil;
		}
		[self setSearch:search];
		[self setDocumentState:iManDocumentStateSearching];
		[self synchronizeUIWithDocumentState];
		
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
						  [type retain],
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
			[addressSearchFieldCell setStringValue:@""];
			break;
		case iManDocumentStateDisplayingPage:
			[tabView selectTabViewItemAtIndex:kiManPageTabIndex];
			[[manpageView textStorage] setAttributedString:[[self page] pageWithStyle:[self displayStringOptions]]];
			[manpageView moveToBeginningOfDocument:self];
			[addressSearchFieldCell setStringValue:[NSString stringWithFormat:@"%@(%@)", [[self page] pageName], [[self page] pageSection]]];
			[[windowController window] makeFirstResponder:manpageView];
			// Our -displayName changes each time a new page is loaded.
			[windowController synchronizeWindowTitleWithDocumentName];
			[[[windowController window] toolbar] validateVisibleItems];			
			break;
		case iManDocumentStateLoadingPage:
			[loadingMessageLabel setStringValue:NSLocalizedString(@"Loading...", nil)];
			[tabView selectTabViewItemAtIndex:kiManLoadingTabIndex];
			[progressIndicator startAnimation:self];
			break;
		case iManDocumentStateSearching:
			[loadingMessageLabel setStringValue:NSLocalizedString(@"Searching...", nil)];
			[tabView selectTabViewItemAtIndex:kiManLoadingTabIndex];
			[progressIndicator startAnimation:self];
			break;
		case iManDocumentStateDisplayingSearch:
			[tabView selectTabViewItemAtIndex:kiManSearchResultsTabIndex];
			[aproposResultsView reloadData];
			break;
	}
}

#pragma mark -
#pragma mark Notifications

- (void)pageLoadDidComplete:(NSNotification *)notification
{
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
	[_historyUndoManager disableUndoRegistration];
	[self setPage:nil];
	[self back:nil];
	[_historyUndoManager enableUndoRegistration];
	[self setDocumentState:iManDocumentStateNone];
	[self synchronizeUIWithDocumentState];
}

- (void)searchDidComplete:(NSNotification *)notification
{
	[_searchResults release];
	_searchResults = [[[[[self search] results] allKeys] sortedArrayUsingSelector:@selector(iManResultSort:)] retain];
	[self setDocumentState:iManDocumentStateDisplayingSearch];
	[self synchronizeUIWithDocumentState];
}

- (void)searchDidFail:(NSNotification *)notification
{
	NSBeginInformationalAlertSheet(NSLocalizedString(@"Search Failed", nil),
								   NSLocalizedString(@"OK", nil),
								   nil,
								   nil,
								   [self windowForSheet],
								   nil,
								   NULL,
								   NULL,
								   NULL,
								   @"%@", // Yes, this is intentional. 
								   [[notification userInfo] objectForKey:iManSearchError]);
	[self setDocumentState:iManDocumentStateNone];
	[self synchronizeUIWithDocumentState];
}	


// FIXME: make sure if -close is called all our tasks get cancelled.

- (void)displayFontDidChange:(NSNotification *)notification
{
    if ([self page] != nil)
        [[manpageView textStorage] setAttributedString:[[self page] pageWithStyle:[self displayStringOptions]]];
}

- (void)drawerDidOpen:(NSNotification *)notification
{
	[searchField becomeFirstResponder];
}

#pragma mark -
#pragma mark Accessors

- (iManPage *)page
{
	return page_;
}

- (void)setPage:(iManPage *)page
{
    if (page_ != nil) {
        [[_historyUndoManager prepareWithInvocationTarget:self] setPage:page_];
    }

	[[NSNotificationCenter defaultCenter] removeObserver:self name:iManPageLoadDidCompleteNotification object:page_];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:iManPageLoadDidFailNotification object:page_];

	[page retain];
	[page_ release];
	page_ = page;
	
	if (page_ != nil) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pageLoadDidComplete:) name:iManPageLoadDidCompleteNotification object:page_];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pageLoadDidFail:) name:iManPageLoadDidFailNotification object:page_];
		
		if (_lastFindResults != nil) {
			[_lastFindResults release];
			_lastFindResults = nil;
			[_findResultRanges release];
			_findResultRanges = nil;
			[findResultsView reloadData];
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
	return _findResultRanges;
}
- (void)setFindResults:(NSArray *)findResults
{
	if (findResults != _findResultRanges) {
		[_findResultRanges release];
		_findResultRanges = [findResults copy];
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

- (NSUndoManager *)historyUndoManager
{
	return _historyUndoManager;
}

#pragma mark -
#pragma mark Display Handlers

- (NSAttributedString *)findResultFromRange:(NSRange)range
{
	// FIXME: ideally, we should supply a chunk of (alphanumerical) context on each side of the matched text; this way yields a lot of spaces.
    NSMutableAttributedString *ret;
    static NSAttributedString *greyEllipses;
    unsigned leftMargin, rightMargin, length, resLength;
	unichar theChar;
    const int marginSize = 10;
    
    if (greyEllipses == nil)
        greyEllipses = [[NSAttributedString alloc] initWithString:NSLocalizedString(@"...", nil)
													   attributes:[NSDictionary dictionaryWithObject:[NSColor disabledControlTextColor] forKey:NSForegroundColorAttributeName]];
    
    resLength = range.length;
    length = [[[manpageView textStorage] string] length];
	
    if (range.location < marginSize) {
        leftMargin = range.location;
        range.length += range.location;
        range.location = 0;
    } else {
        leftMargin = marginSize;
        range.length += marginSize;
        range.location -= marginSize;
    }
	
    rightMargin = MIN(marginSize, length - NSMaxRange(range));
    range.length += rightMargin;
	
    ret = [[[manpageView textStorage] attributedSubstringFromRange:range] mutableCopy];
	
	// Highlight the find result in red.
	[ret addAttribute:NSForegroundColorAttributeName
				value:[NSColor redColor]
				range:NSMakeRange(leftMargin, resLength)];
	
	// Add ellipses if not at beginning/end of line.
	if (range.location > 0) {
		theChar = [[[manpageView textStorage] string] characterAtIndex:range.location - 1];
		if ((theChar != 0x000D) && (theChar != 0x000A))
			[ret insertAttributedString:greyEllipses atIndex:0];
	}
	
	if (NSMaxRange(range) < [[manpageView textStorage] length]) {
		theChar = [[[manpageView textStorage] string] characterAtIndex:NSMaxRange(range) + 1];
		if ((theChar != 0x000D) && (theChar != 0x000A))
			[ret appendAttributedString:greyEllipses];
	}
	
	// Use CF functions to remove CR/LF & co.
	{
		CFCharacterSetRef characters = CFCharacterSetGetPredefined(kCFCharacterSetWhitespaceAndNewline);
		CFRange range = CFRangeMake(0, [ret length]), result;
		CFStringRef stringRef = (CFStringRef)[ret string];
		NSRange junk;
		
		while (CFStringFindCharacterFromSet(stringRef,
											characters,
											range,
											0,
											&result)) {
			NSAttributedString *repl = [[NSAttributedString alloc] initWithString:@" " attributes:[ret attributesAtIndex:result.location effectiveRange:&junk]];
			[ret replaceCharactersInRange:NSMakeRange(result.location, result.length)
					 withAttributedString:repl];
			[repl release];
			range = CFRangeMake(result.location + 1, [ret length] - (result.location + 1));
		}
	}
	
	
    return [ret autorelease];
}

- (NSDictionary *)displayStringOptions
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
			[NSDictionary dictionaryWithObject:[[NSUserDefaults standardUserDefaults] archivedObjectForKey:iManPageFont] forKey:NSFontAttributeName], iManPageDefaultStyle,
			[[NSUserDefaults standardUserDefaults] archivedObjectForKey:iManBoldStyle], iManPageBoldStyle,
			[[NSUserDefaults standardUserDefaults] archivedObjectForKey:iManEmphasizedStyle], iManPageUnderlineStyle,
			[[NSUserDefaults standardUserDefaults] objectForKey:iManShowPageLinks], iManPageUnderlineLinks,
			nil];
}

#pragma mark -
#pragma mark NSTextView Delegate Link Handling

- (BOOL)textView:(NSTextView *)textView clickedOnLink:(id)link atIndex:(unsigned)charIndex
{
    if ([[NSUserDefaults standardUserDefaults] integerForKey:iManHandlePageLinks] == kiManHandleLinkInCurrentWindow) {
		[self loadPageWithURL:link];
		return YES;
    }

	// URLs will be passed off to the application-wide handler if appropriate, which will open in a new window.
	return NO;
}

#pragma mark -
#pragma mark Find Results Table Delegate

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    if ([findResultsView selectedRow] != -1) {
        NSRange range = [[[[self findResults] objectAtIndex:[findResultsView selectedRow]] objectForKey:iManFindResultRange] rangeValue];
        [manpageView setSelectedRange:range];
        [manpageView scrollRangeToVisible:range];
    }
}

#pragma mark -
#pragma mark Results Outline View Data Source

- (id)outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item
{
    if (item == nil) 
        return [_searchResults objectAtIndex:index];
	
    return [item objectAtIndex:index];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    return [item isKindOfClass:[NSArray class]];
}

- (int)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
    if (item == nil) {
		if (_searchResults != nil)
			return [_searchResults count];
		else
			return 0;
	}
	
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
    [accessoryView release]; // loaded from iManSavePanelAccessory.nib
    [_historyUndoManager release];
    [_lastFindResults release];
    [_findResultRanges release];
	[page_ release];
    [super dealloc];
}

@end