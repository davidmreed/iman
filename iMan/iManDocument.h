//
// iManDocument.h
// iMan
// Copyright (c) 2006 by David Reed, distributed under the BSD License.
// see iman-macosx.sourceforge.net for details.
//

#import <Cocoa/Cocoa.h>

@class iManPage;

@interface iManDocument : NSDocument
{
    IBOutlet NSTextView *manpageView;
    IBOutlet NSTabView *tabView;

    IBOutlet NSView *accessoryView;
    IBOutlet NSPopUpButton *formatMenu;
    IBOutlet NSProgressIndicator *progressIndicator;

    IBOutlet NSDrawer *findDrawer;
    IBOutlet NSTextField *searchField;
    IBOutlet NSButton *useRegexps;
    IBOutlet NSButton *caseSensitive;
    IBOutlet NSTableView *findResults;

    NSUndoManager *_historyUndoManager;
    
	iManPage *page_;
    NSToolbarItem *sectionItem, *pageItem;

    NSMutableArray *_lastFindResults;
    NSMutableArray *_findResultRanges;
}

+ (void)loadURL:(NSURL *)url inNewDocument:(BOOL)inNewDocument;

- (iManPage *)page;
- (void)setPage:(iManPage *)page;

- (IBAction)export:(id)sender;
- (IBAction)changeExportFormat:(id)sender;
- (void)exportPanelDidEnd:(NSSavePanel *)savePanel returnCode:(int)returnCode contextInfo:(void *)contextInfo;

- (IBAction)toggleFindDrawer:(id)sender;
- (IBAction)back:(id)sender;
- (IBAction)forward:(id)sender;
- (IBAction)refresh:(id)sender;
- (IBAction)doSearch:(id)sender;

- (NSAttributedString *)findResultFromRange:(NSRange)range;

- (void)displayFontDidChange:(NSNotification *)notification;
- (NSDictionary *)displayStringOptions;

@end
