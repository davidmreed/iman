//
//  iManDocument.h
//  iMan
//  Copyright (c) 2004-2010 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import <Cocoa/Cocoa.h>

@class iManPage, iManSearch, iManHistoryQueue, RBSplitView;

typedef enum { 
	iManDocumentStateNone, 
	iManDocumentStateDisplayingPage, 
	iManDocumentStateLoadingPage
} iManDocumentState;

@interface iManDocument : NSDocument
{
	// Parts of the main document view.
    IBOutlet NSTabView *tabView;
    IBOutlet NSTextView *manpageView;
	IBOutlet NSTextField *loadingMessageLabel;
	IBOutlet NSTextField *addressField;

	// Parts of the export-page save panel accessory.
    IBOutlet NSView *accessoryView;
    IBOutlet NSPopUpButton *formatMenu;
    IBOutlet NSProgressIndicator *progressIndicator;

	// In-page search drawer.
    IBOutlet NSDrawer *findDrawer;
	IBOutlet NSSearchField *findDrawerSearchField;
	IBOutlet NSMenu *findDrawerSearchFieldMenu;
    IBOutlet NSTableView *findResultsView;
	
	// Apropos search drawer.
	IBOutlet NSDrawer *aproposDrawer;
	IBOutlet NSSearchField *aproposField;
	IBOutlet NSTabView *aproposTabView;
	IBOutlet NSTableView *aproposResultsView;
	IBOutlet NSMenu *aproposFieldMenu;
	
	// Multiple-page selection sheet
	IBOutlet NSPanel *pageSelectionSheet;
	IBOutlet NSTableView *pageSelectionList;

	// Page and navigation machinery.
    iManHistoryQueue *_history;
	iManPage *page_;
	NSArray *_pageChoices; 

	// apropos/whatis search machinery.
	iManSearch *search_;
	NSString *_savedSearchType;
	
	// In-page search machinery.
    NSMutableArray *_findResults;
	BOOL caseSensitive, useRegexps;
	
	// Current document state.
	iManDocumentState _documentState;
	
	// Browser data.
	IBOutlet NSTreeController *browserController;
	IBOutlet NSBrowser *pageBrowser;
	IBOutlet RBSplitView *splitView;
	NSArray *_browserTree;
}

- (iManPage *)page;
- (void)setPage:(iManPage *)page;
- (iManSearch *)search;
- (void)setSearch:(iManSearch *)search;

- (NSArray *)findResults;
- (void)setFindResults:(NSArray *)findResults;

- (iManDocumentState)documentState;
- (void)setDocumentState:(iManDocumentState)documentState;

- (void)performSearchForTerm:(NSString *)term type:(NSString *)type;
- (void)loadPageWithStringInput:(NSString *)string;
- (void)loadPageWithName:(NSString *)pageName section:(NSString *)pageSection;
- (void)loadPageWithURL:(NSURL *)url;
- (void)loadPage:(iManPage *)page;
- (void)synchronizeUIWithDocumentState;

- (iManHistoryQueue *)history;

- (IBAction)export:(id)sender;
- (IBAction)changeExportFormat:(id)sender;
- (void)exportPanelDidEnd:(NSSavePanel *)savePanel returnCode:(int)returnCode contextInfo:(void *)contextInfo;

- (IBAction)toggleBrowser:(id)sender;
- (IBAction)toggleFindDrawer:(id)sender;
- (IBAction)toggleAproposDrawer:(id)sender;
- (IBAction)back:(id)sender;
- (IBAction)forward:(id)sender;
- (IBAction)reload:(id)sender;
- (IBAction)loadRequestedPage:(id)sender;
- (IBAction)performAproposSearch:(id)sender;
- (IBAction)setAproposFieldSearchType:(id)sender;
- (IBAction)openSearchResultPage:(id)sender;
- (IBAction)clearHistory:(id)sender;
- (IBAction)goToPageField:(id)sender;

- (IBAction)performSearch:(id)sender;
- (IBAction)takeUseRegexpsFrom:(id)sender;
- (IBAction)takeCaseSensitiveFrom:(id)sender;

- (IBAction)pageSelectionSheetOK:(id)sender;
- (IBAction)pageSelectionSheetCancel:(id)sender;

- (IBAction)openLink:(id)sender;
- (IBAction)openLinkInNewWindow:(id)sender;
- (IBAction)openPageFromSelection:(id)sender;
- (IBAction)aproposSearchForSelection:(id)sender;

@property BOOL useRegexps;
@property BOOL caseSensitive;
@property (readwrite, copy) NSArray *browserTree;

- (void)displayFontDidChange:(NSNotification *)notification;
- (NSDictionary *)displayStringOptions;

@end
