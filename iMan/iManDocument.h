//
//  iManDocument.h
//  iMan
//  Copyright (c) 2006-2009 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import <Cocoa/Cocoa.h>

@class iManPage, iManSearch;

typedef enum { 
	iManDocumentStateNone, 
	iManDocumentStateDisplayingPage, 
	iManDocumentStateDisplayingSearch, 
	iManDocumentStateLoadingPage, 
	iManDocumentStateSearching 
} iManDocumentState;

@interface iManDocument : NSDocument
{
	// Parts of the main document view.
    IBOutlet NSTabView *tabView;
    IBOutlet NSTextView *manpageView;
	IBOutlet NSOutlineView *aproposResultsView;
	IBOutlet NSTextField *loadingMessageLabel;
	IBOutlet NSSearchFieldCell *addressSearchFieldCell;
	IBOutlet NSMenu *addressFieldSearchMenu;

	// Parts of the export-page save panel accessory.
    IBOutlet NSView *accessoryView;
    IBOutlet NSPopUpButton *formatMenu;
    IBOutlet NSProgressIndicator *progressIndicator;

	// In-page search drawer.
    IBOutlet NSDrawer *findDrawer;
    IBOutlet NSSearchField *searchField;
    IBOutlet NSTableView *findResultsView;

	// Page and navigation machinery.
    NSUndoManager *_historyUndoManager;
	iManPage *page_;

	// apropos/whatis search machinery.
	iManSearch *search_;
    NSArray *_searchResults;
	
	// In-page search machinery.
    NSMutableArray *_lastFindResults;
    NSMutableArray *_findResultRanges;
	BOOL shouldMatchCase, shouldUseRegexps;
	
	// Current document state.
	iManDocumentState _documentState;
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
- (void)loadPageWithName:(NSString *)pageName section:(NSString *)pageSection;
- (void)loadPageWithURL:(NSURL *)url;
- (void)synchronizeUIWithDocumentState;

- (NSUndoManager *)historyUndoManager;

- (IBAction)export:(id)sender;
- (IBAction)changeExportFormat:(id)sender;
- (void)exportPanelDidEnd:(NSSavePanel *)savePanel returnCode:(int)returnCode contextInfo:(void *)contextInfo;

- (IBAction)toggleFindDrawer:(id)sender;
- (IBAction)back:(id)sender;
- (IBAction)forward:(id)sender;
- (IBAction)loadRequestedPage:(id)sender;
- (IBAction)openSearchResultPage:(id)sender;
- (IBAction)clearHistory:(id)sender;

- (IBAction)performSearch:(id)sender;
- (IBAction)setUseRegularExpressions:(id)sender;
- (IBAction)setCaseSensitive:(id)sender;

- (NSAttributedString *)findResultFromRange:(NSRange)range;

- (void)displayFontDidChange:(NSNotification *)notification;
- (NSDictionary *)displayStringOptions;

@end
