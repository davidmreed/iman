//
//  iManDocument.h
//  iMan
//  Copyright (c) 2006-2009 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import <Cocoa/Cocoa.h>

@class iManPage, iManSearch, iManHistoryQueue;

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
	IBOutlet NSMenu *aproposFieldMenu;

	// Parts of the export-page save panel accessory.
    IBOutlet NSView *accessoryView;
    IBOutlet NSPopUpButton *formatMenu;
    IBOutlet NSProgressIndicator *progressIndicator;

	// In-page search drawer.
    IBOutlet NSDrawer *findDrawer;
	IBOutlet NSSearchField *findDrawerSearchField;
    IBOutlet NSTableView *findResultsView;
	
	// Apropos search drawer.
	IBOutlet NSDrawer *aproposDrawer;
	IBOutlet NSTabView *aproposTabView;
	IBOutlet NSTableView *aproposResultsView;

	// Page and navigation machinery.
    iManHistoryQueue *_history;
	iManPage *page_;

	// apropos/whatis search machinery.
	iManSearch *search_;
    NSArray *_searchResults;
	
	// In-page search machinery.
    NSMutableArray *_findResults;
	BOOL caseSensitive, useRegexps;
	
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
- (void)loadPage:(iManPage *)page;
- (void)synchronizeUIWithDocumentState;

- (iManHistoryQueue *)history;

- (IBAction)export:(id)sender;
- (IBAction)changeExportFormat:(id)sender;
- (void)exportPanelDidEnd:(NSSavePanel *)savePanel returnCode:(int)returnCode contextInfo:(void *)contextInfo;

- (IBAction)toggleFindDrawer:(id)sender;
- (IBAction)back:(id)sender;
- (IBAction)forward:(id)sender;
- (IBAction)reload:(id)sender;
- (IBAction)loadRequestedPage:(id)sender;
- (IBAction)performAproposSearch:(id)sender;
- (IBAction)setAproposFieldSearchType:(id)sender;
- (IBAction)openSearchResultPage:(id)sender;
- (IBAction)clearHistory:(id)sender;

- (IBAction)performSearch:(id)sender;

@property BOOL useRegexps;
@property BOOL caseSensitive;

- (NSAttributedString *)findResultFromRange:(NSRange)range;

- (void)displayFontDidChange:(NSNotification *)notification;
- (NSDictionary *)displayStringOptions;

@end
