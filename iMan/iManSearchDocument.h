//
// iManSearchDocument.h
// iMan
// Copyright (c) 2006 by David Reed, distributed under the BSD License.
// see iman-macosx.sourceforge.net for details.
//

#import <Cocoa/Cocoa.h>

@class iManSearch, iManIndexingWindowController;

@interface iManSearchDocument : NSDocument
{
	IBOutlet NSPopUpButton *searchTypeMenu;
    IBOutlet NSProgressIndicator *progressMeter;
    IBOutlet NSTextField *searchField;
    IBOutlet NSOutlineView *tableView;
    IBOutlet NSTabView *tabView;
    IBOutlet NSButton *goButton;
	
	iManSearch *search_;
    NSArray *sortedResults;
}

- (iManSearch *)search;
- (void)setSearch:(iManSearch *)search;

- (IBAction)go:(id)sender;
- (IBAction)openPage:(id)sender;

@end
