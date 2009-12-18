//
// iManDocument.m
// iMan
// Copyright (c) 2004 by David Reed, distributed under the BSD License.
// see iman-macosx.sourceforge.net for details.
//

#import "iManDocument.h"
#import "iManConstants.h"
#import "NSUserDefaults+DMRArchiving.h"
#import <iManEngine/iManEngine.h>
#import <unistd.h>
#import "RegexKitLite/RegexKitLite.h"
#import "RegexKitLiteSupport/RKLMatchEnumerator.h"

// Indices of tab view panes.
enum {
    kiManPageTabIndex,
    kiManNoPageTabIndex,
    kiManLoadingTabIndex
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

@interface iManDocument (Private)

- (void)beginAsyncLoad;
- (void)endAsyncLoad;
- (void)updateInterface;

@end

@implementation iManDocument

#pragma mark -
#pragma mark Class convenience method

+ (void)loadURL:(NSURL *)url inNewDocument:(BOOL)inNewDocument
{
	iManDocument *docToLoad = nil;
	iManPage *page = [iManPage pageWithURL:url];

	
	if (page == nil) {
		NSRunAlertPanel(NSLocalizedString(@"Invalid link.", nil),
						NSLocalizedString(@"The link \"%@\" is invalid and cannot be opened.", nil),
						NSLocalizedString(@"OK", nil),
						nil, nil,
						url);
		return;
	}
	
    if (!inNewDocument) { // open in current doc if possible.
        NSEnumerator *enumerator = [[NSApp orderedDocuments] objectEnumerator];
        id obj;
		
        while ((obj = [enumerator nextObject]) != nil) {
            if ([obj isKindOfClass:[iManDocument class]]) {
				docToLoad = obj;
				break;
			}
		}
	}
	
    // Otherwise (and fall through if no doc is found), load up a new window.
    if (docToLoad == nil) {
		docToLoad = [[iManDocument alloc] init];
		[[NSDocumentController sharedDocumentController] addDocument:docToLoad];
		[docToLoad makeWindowControllers];
		[docToLoad showWindows];
		[docToLoad release];
	}
	
	[[[[docToLoad windowControllers] lastObject] window] makeKeyAndOrderFront:nil];
	[docToLoad setPage:page];
}	

#pragma mark -
#pragma mark Actions & Notifications


- (IBAction)toggleFindDrawer:(id)sender
{
	[findDrawer toggle:sender];
}

- (void)drawerDidOpen:(NSNotification *)notification
{
	[searchField becomeFirstResponder];
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

- (IBAction)changeExportFormat:(id)sender
{
    [((NSSavePanel *)[formatMenu window]) setRequiredFileType:[[NSArray arrayWithObjects:@"rtf", @"txt", nil] objectAtIndex:[sender indexOfSelectedItem]]];
}

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

- (IBAction)performSearch:(id)sender
{
	if (([self page] == nil) || (![[self page] isLoaded]))
		return;
	
    [_lastFindResults release];
    _lastFindResults = [[NSMutableArray alloc] init];
    [_findResultRanges release];
    _findResultRanges = [[NSMutableArray alloc] init];
    
    if (shouldUseRegexps) {
        NSEnumerator *enumerator;
        NSString *string = [[manpageView textStorage] string];
		NSValue *match;

        enumerator = [string matchEnumeratorWithRegex:[searchField stringValue] options: (shouldMatchCase ? RKLNoOptions : RKLNoOptions | RKLCaseless)];

        while ((match = [enumerator nextObject]) != nil) {            
            [_findResultRanges addObject:match];
			[_lastFindResults addObject:[self findResultFromRange:[match rangeValue]]];
            
        }
    } else {
        CFArrayRef results;
        CFIndex index;
        NSString *string = [[manpageView textStorage] string];

        results = CFStringCreateArrayWithFindResults(kCFAllocatorDefault,
                                                     (CFStringRef)string,
                                                     (CFStringRef)[searchField stringValue],
                                                     CFRangeMake(0, [string length]),
													 shouldMatchCase ? 0 : kCFCompareCaseInsensitive);

        if (results != NULL) {
            for (index = 0; index < CFArrayGetCount(results); index++) {
                const CFRange *rangePtr;
                NSRange range;

                rangePtr = CFArrayGetValueAtIndex(results, index);
                range = NSMakeRange(rangePtr->location, rangePtr->length);
                [_findResultRanges addObject:[NSValue valueWithRange:range]];
                [_lastFindResults addObject:[self findResultFromRange:range]];
            }
        }
    }
    
    [findResults reloadData];
}

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

- (IBAction)refresh:(id)sender
{
	[self setPage:[iManPage pageWithName:[(NSTextField *)[pageItem view] stringValue]
							   inSection:[(NSTextField *)[sectionItem view] stringValue]]];
}

- (IBAction)reload:(id)sender
{
	// This and the above method are somewhat confusingly named.
	// Refresh actually goes to the entered page, while reload clears cache and rerenders the current page.
	[self beginAsyncLoad];
	[[self page] reload];
}

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
#pragma mark UI Methods

- (void)pageLoadDidComplete:(NSNotification *)notification
{
	[self endAsyncLoad];
	[self updateInterface];
}

- (void)pageLoadDidFail:(NSNotification *)notification
{
	NSBeginInformationalAlertSheet(NSLocalizedString(@"Access failed.", nil),
								   NSLocalizedString(@"OK", nil),
								   nil, nil,
								   [self windowForSheet],
								   nil, NULL, NULL, NULL,
								   NSLocalizedString(@"The requested man page could not be loaded. The error returned was \"%@\".", nil),
								  [[[notification userInfo] objectForKey:iManErrorKey] localizedDescription]);
	[self endAsyncLoad];
	[_historyUndoManager disableUndoRegistration];
	[self setPage:nil];
	[self back:nil];
	[_historyUndoManager enableUndoRegistration];
}

- (void)beginAsyncLoad
{
	[tabView selectTabViewItemAtIndex:kiManLoadingTabIndex];
	[progressIndicator startAnimation:self];
	[[[[[self windowControllers] lastObject] window] standardWindowButton:NSWindowCloseButton] setEnabled:NO];	
}

- (void)endAsyncLoad
{
	[[[[[self windowControllers] lastObject] window] standardWindowButton:NSWindowCloseButton] setEnabled:YES];
	[tabView selectTabViewItemAtIndex:kiManPageTabIndex];
	
	[progressIndicator stopAnimation:self]; 
}

- (void)updateInterface
{
	[tabView selectTabViewItemAtIndex:kiManPageTabIndex];
	[[manpageView textStorage] setAttributedString:[[self page] pageWithStyle:[self displayStringOptions]]];
	
	[(NSTextField *)[pageItem view] setStringValue:[[self page] pageName]];
	[(NSTextField *)[sectionItem view] setStringValue:[[self page] pageSection]];
	
	[manpageView moveToBeginningOfDocument:self];
	[[[[self windowControllers] lastObject] window] makeFirstResponder:manpageView];
	
	// Our -displayName changes each time a new page is loaded.
	[[[self windowControllers] lastObject] synchronizeWindowTitleWithDocumentName];
	[[[[[self windowControllers] lastObject] window] toolbar] validateVisibleItems];
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

		if (![page_ isLoaded]) {
			[self beginAsyncLoad];
			[page_ load];
		} else {
			[self updateInterface];
		}
		
		[(NSTextField *)[pageItem view] setStringValue:[page_ pageName]];
        if ([page_ pageSection])
			[(NSTextField *)[sectionItem view] setStringValue:[page_ pageSection]];
		
		if (_lastFindResults != nil) {
			[_lastFindResults release];
			_lastFindResults = nil;
			[_findResultRanges release];
			_findResultRanges = nil;
			[findResults reloadData];
		}
    } else {
		[tabView selectTabViewItemAtIndex:kiManNoPageTabIndex];
	}
	
    [[[self windowControllers] lastObject] synchronizeWindowTitleWithDocumentName];
}

- (NSUndoManager *)historyUndoManager
{
	return _historyUndoManager;
}

#pragma mark -
#pragma mark Font and Style Methods

- (void)displayFontDidChange:(NSNotification *)notification
{
    if ([self page] != nil)
        [[manpageView textStorage] setAttributedString:[[self page] pageWithStyle:[self displayStringOptions]]];
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
#pragma mark NSDocument Overrides

- (void)windowControllerDidLoadNib:(NSWindowController *)windowController;
{
    NSWindow *window = [windowController window];
    NSScrollView *scrollView = (NSScrollView *)[[manpageView superview] superview];
    NSTextContainer *textContainer = [manpageView textContainer];
    NSToolbar *toolbar;

    [super windowControllerDidLoadNib:windowController];

    // Initialize our toolbar.
    toolbar = [[NSToolbar alloc] initWithIdentifier:iManDocumentToolbarIdentifier];
    [toolbar setDelegate:self];
    [toolbar setDisplayMode:NSToolbarDisplayModeIconAndLabel];
    [window setToolbar:toolbar];
    [toolbar release];

    // Set the scroll view, text container, and text view up to behave properly.
    // This is largely derived from Apple's TextSizingExample code.
    // Note: 1.0e7 is the "LargeNumberForText" used there, it should not be changed.
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
	
    // Initialize the undo manager we use for history (back/forward) handling.
    _historyUndoManager = [[NSUndoManager alloc] init];

	[tabView selectTabViewItemAtIndex:kiManNoPageTabIndex];
	
	// Setup the search menu.
	{
		NSMenu *searchFieldMenu = [[[searchField cell] searchMenuTemplate] copy];
		
		shouldMatchCase = shouldUseRegexps = YES;
		[[searchFieldMenu itemWithTag:kiManMatchCaseMenuItemTag] setState:shouldMatchCase];
		[[searchFieldMenu itemWithTag:kiManUseRegularExpressionsMenuItemTag] setState:shouldUseRegexps];
		[[searchField cell] setSearchMenuTemplate:searchFieldMenu];
		[searchFieldMenu release];
	}
	
	// Update the UI
    [self setPage:[self page]];
	
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(displayFontDidChange:)
                                                 name:iManFontChangedNotification
                                               object:nil];
	
    if (pageItem != nil)
        [window makeFirstResponder:[pageItem view]];
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
    if ((action == @selector(refresh:)) ||
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
#pragma mark NSTextView Delegate Link Handling

- (BOOL)textView:(NSTextView *)textView clickedOnLink:(id)link atIndex:(unsigned)charIndex
{
    if ([[NSUserDefaults standardUserDefaults] integerForKey:iManHandlePageLinks] == kiManHandleLinkInCurrentWindow) {
        iManPage *page = [iManPage pageWithURL:link];
		if (page != nil) {
			[self setPage:page];
			return YES;
		} else {
			NSBeginAlertSheet(NSLocalizedString(@"Invalid link.", nil),
							  NSLocalizedString(@"OK", nil),
							  nil, nil,
							  [self windowForSheet],
							  nil, NULL, NULL, NULL,
							  NSLocalizedString(@"The link \"%@\" is invalid and cannot be opened.", nil),
							  link);
			return NO;
		}
    } else {
		iManDocument *doc = [[iManDocument alloc] init];
		[[NSDocumentController sharedDocumentController] addDocument:doc];
		[doc makeWindowControllers];
		[doc showWindows];
		{       
			iManPage *page = [iManPage pageWithURL:link];
			if (page != nil) {
				[doc setPage:page];
				return YES;
			} else {
				NSBeginAlertSheet(NSLocalizedString(@"Invalid link.", nil),
								  NSLocalizedString(@"OK", nil),
								  nil, nil,
								  [doc windowForSheet],
								  nil, NULL, NULL, NULL,
								  NSLocalizedString(@"The link \"%@\" is invalid and cannot be opened.", nil),
								  link);
				return NO;
			}
		}
		[doc release];
		return YES;
	}

    return NO;
}

#pragma mark -
#pragma mark NSToolbar Delegate

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
    NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];

    if ([itemIdentifier isEqualToString:iManToolbarItemSection]) {
        NSRect rect = NSMakeRect(0, 0, 32, 22);
        
        [item setLabel:NSLocalizedString(@"Section", nil)];
        [item setTag:32];
        [item setView:[[[NSTextField alloc] initWithFrame:rect] autorelease]];
        [item setTarget:self];
        [item setAction:@selector(refresh:)];
        [item setMinSize:rect.size];
        [item setMaxSize:rect.size];        

        sectionItem = item;
    } else if ([itemIdentifier isEqualToString:iManToolbarItemManpage]) {
        NSRect rect = NSMakeRect(0, 0, 96, 22);
        
        [item setLabel:NSLocalizedString(@"Man Page", nil)];
        [item setTag:0];
        [item setView:[[[NSTextField alloc] initWithFrame:rect] autorelease]];
        [item setTarget:self];
        [item setAction:@selector(refresh:)];
        [item setMinSize:rect.size];
        [item setMaxSize:rect.size];
        
        pageItem = item;
    } else if ([itemIdentifier isEqualToString:iManToolbarItemBack]) {
        [item setImage:[NSImage imageNamed:iManToolbarItemBack]];
        [item setLabel:NSLocalizedString(@"Back", nil)];
        [item setTarget:self];
        [item setAction:@selector(back:)];
    } else if ([itemIdentifier isEqualToString:iManToolbarItemForward]) {
        [item setImage:[NSImage imageNamed:iManToolbarItemForward]];
        [item setLabel:NSLocalizedString(@"Forward", nil)];
        [item setTarget:self];
        [item setAction:@selector(forward:)];
    } else if ([itemIdentifier isEqualToString:iManToolbarItemToggleFind]) {
        [item setImage:[NSImage imageNamed:@"iManSearchIcon"]];
        [item setLabel:NSLocalizedString(@"Search", nil)];
        [item setTarget:self];
        [item setAction:@selector(toggleFindDrawer:)];
    } else if ([itemIdentifier isEqualToString:iManToolbarItemReload]) {
		[item setImage:[NSImage imageNamed:iManToolbarItemReload]];
		[item setLabel:NSLocalizedString(@"Reload", nil)];
		[item setTarget:self];
		[item setAction:@selector(reload:)];
	}

    return [item autorelease];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar
{
    return [NSArray arrayWithObjects:
        iManToolbarItemManpage,
        iManToolbarItemSection,
        NSToolbarSeparatorItemIdentifier,
		iManToolbarItemReload,
        iManToolbarItemBack,
        iManToolbarItemForward,
        NSToolbarFlexibleSpaceItemIdentifier,
        iManToolbarItemToggleFind,
        NSToolbarPrintItemIdentifier,
        nil];
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar
{
    // Our toolbar is not modifiable.
    return [self toolbarDefaultItemIdentifiers:toolbar];
}

#pragma mark -
#pragma mark Find Results Table Data Source/Delegate

- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
    return ((_lastFindResults == nil) ? 0 : [_lastFindResults count]);
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
    return [_lastFindResults objectAtIndex:row];
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    if ([findResults selectedRow] != -1) {
        NSRange range = [[_findResultRanges objectAtIndex:[findResults selectedRow]] rangeValue];
        [manpageView setSelectedRange:range];
        [manpageView scrollRangeToVisible:range];
    }
}

- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(int)row
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