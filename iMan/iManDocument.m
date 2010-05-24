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
#import "iManHistoryQueue.h"
#import "NSUserDefaults+DMRArchiving.h"
#import "RegexKitLite/RegexKitLite.h"
#import "RegexKitLiteSupport/RKLMatchEnumerator.h"

// FIXME: items in Recent Documents menu are problematic and if one selects a .gz manpage it throws up an error.

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

// Local constants for this file only.
static NSString *const iManFindResultRange = @"range";
static NSString *const iManFindResultDisplayString = @"string";

@implementation iManDocument

@synthesize useRegexps, caseSensitive;

#pragma mark -
#pragma mark NSDocument Overrides

- init
{
	self = [super init];
	
	if (self != nil) {
		_documentState = iManDocumentStateNone;
		_history = [[iManHistoryQueue alloc] init];
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
	
	// Setup the search results view.
	[aproposResultsView setDoubleAction:@selector(openSearchResultPage:)];
		
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
        return ([[self history] canGoBack] && ([self documentState] != iManDocumentStateLoadingPage));
    if (action == @selector(forward:))
        return ([[self history] canGoForward] && ([self documentState] != iManDocumentStateLoadingPage));
	
    // Make sure, if we are loading, that another load request doesn't happen, nor should the window close.
    if ((action == @selector(loadRequestedPage:)) ||
		(action == @selector(reload:)) ||
		(action == @selector(performClose:))) {
		return ([self documentState] != iManDocumentStateLoadingPage);
	}
	
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

    if (useRegexps) {
        NSEnumerator *enumerator;
        NSString *string = [[manpageView textStorage] string];
		NSValue *match;
		
        enumerator = [string matchEnumeratorWithRegex:[findDrawerSearchField stringValue] options: (caseSensitive ? RKLNoOptions : RKLNoOptions | RKLCaseless)];

        while ((match = [enumerator nextObject]) != nil) {  
			[results addObject:[NSDictionary dictionaryWithObjectsAndKeys:match, iManFindResultRange, [self findResultFromRange:[match rangeValue]], iManFindResultDisplayString, nil]];
            
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
				[results addObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSValue valueWithRange:range], iManFindResultRange, [self findResultFromRange:range], iManFindResultDisplayString, nil]];
            }
        }
    }
    
	[self setFindResults:results];
	[results release];
}

- (IBAction)back:(id)sender
{
	if ([self page] == nil) {
		// We failed to load a page, sending us to the No Page tab. The history queue still has the last good page on the top, so we cannot go "back" -- we'll end up two pages ago. Just reset ourselves to the top of the queue.
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

- (IBAction)performAproposSearch:(id)sender
{
	if (![[sender stringValue] length] == 0) {
		// FIXME: this way of handling matters is awkward.
		// FIXME: the checked item gets cleared after a search is performed.
		NSString *searchType = iManSearchTypeApropos;
		
		for (NSMenuItem *menuItem in [aproposFieldMenu itemArray]) {
			if (([menuItem action] == @selector(setAproposFieldSearchType:)) && ([menuItem state] == NSOnState)) {
				searchType = [menuItem representedObject];
				break;
			}
		}
		
		[self performSearchForTerm:[sender stringValue] type:searchType];
	}
}	

- (IBAction)setAproposFieldSearchType:(id)sender
{
	// Clear checks by other search-type menu items.
	for (NSMenuItem *menuItem in [aproposFieldMenu itemArray])
		if ([menuItem action] == @selector(setAproposFieldSearchType:))
			[menuItem setState:NSOffState];
	
	// Select this item.
	[sender setState:NSOnState];
}

- (IBAction)loadRequestedPage:(id)sender
{
	// Determine what the user has requested.
	// 1) if the input looks like a URL (i.e., begins with man:), treat it as appropriate.
	// 2) if the input looks like a page name and section, or a bare page name, attempt to locate that page.
	NSMutableString *input = [[[sender stringValue] mutableCopy] autorelease];

	// Trim whitespace
	CFStringTrimWhitespace((CFMutableStringRef)input);
	if ([input hasPrefix:@"man:"]) {
		// Treat input as man: URL.
		[self loadPageWithURL:[NSURL URLWithString:input]];
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

- (IBAction)openSearchResultPage:(id)sender
{
    NSString *result = [[[[self search] results] objectAtIndex:[aproposResultsView clickedRow]] firstPageName];
		
	if ([[NSUserDefaults standardUserDefaults] integerForKey:iManHandleSearchResults] == kiManHandleLinkInNewWindow) 
		[iMan loadURLInNewDocument:[NSURL URLWithString:[NSString stringWithFormat:@"man:%@", result]]];
	else
		[self loadPageWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"man:%@", result]]];
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
	[self loadPage:[iManPage pageWithURL:url]];
}

- (void)loadPageWithName:(NSString *)pageName section:(NSString *)pageSection
{
	[self loadPage:[iManPage pageWithName:pageName inSection:pageSection]];
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
		if (_searchResults != nil) {
			[_searchResults release];
			_searchResults = nil;
		}
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
			[addressField setStringValue:@""];
			break;
		case iManDocumentStateDisplayingPage:
			[tabView selectTabViewItemAtIndex:kiManPageTabIndex];
			// It's important for this to come before we change the value of addressField (below), otherwise we'll get a second -loadRequestedPage: when the addressField loses first responder and, because of the way pages are cached, it won't be caught as the same page if the first was just a page name without section. FIXME: This should be repaired permanently by offering the user all available pages with a given title rather than having iManPage just pass the name alone to man -w.
			[[windowController window] makeFirstResponder:manpageView];
			[[manpageView textStorage] setAttributedString:[[self page] pageWithStyle:[self displayStringOptions]]];
			[manpageView moveToBeginningOfDocument:self];
			[addressField setStringValue:[NSString stringWithFormat:@"%@(%@)", [[self page] pageName], [[self page] pageSection]]];
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
	[_searchResults release];
	_searchResults = [[[[self search] results] sortedArrayUsingSelector:@selector(compare:)] retain];
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

// FIXME: make sure if -close is called all our tasks get cancelled.

- (void)displayFontDidChange:(NSNotification *)notification
{
    if ([self page] != nil)
        [[manpageView textStorage] setAttributedString:[[self page] pageWithStyle:[self displayStringOptions]]];
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
	// FIXME: we really only need to be registered for these when an asynchronous load operation is going on.
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
#pragma mark Cleanup

- (void)dealloc
{
    [accessoryView release]; // loaded from iManSavePanelAccessory.nib
    [_history release];
    [_findResults release];
	[page_ release];
    [super dealloc];
}

@end