//
//  iManIndexingWindowController.h
//  iMan
//  Copyright (c) 2004-2010 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import <Cocoa/Cocoa.h>

@class iManIndex;

@interface iManIndexingWindowController : NSWindowController
{
    IBOutlet NSTableView *indexList;
    IBOutlet NSView *listView;
    IBOutlet NSProgressIndicator *progressBar;
    IBOutlet NSView *progressView;
    IBOutlet NSTextField *textField;
	
	BOOL indexing_;
	iManIndex *currentIndex_;
	NSMutableArray *selectedIndexes_;
}

- (iManIndexingWindowController *)initWithSelectedIndexes:(NSArray *)indexes;

- (NSArray *)selectedIndexes;
- (void)setSelectedIndexes:(NSArray *)indexes;

- (IBAction)runModalUpdateWindow:(id)sender;
- (int)doRunModalUpdateWindow;

- (IBAction)cancel:(id)sender;
- (IBAction)update:(id)sender;

@end

extern NSString *const iManIndexingCanceledNotification;
extern NSString *const iManIndexingFailedNotification;
extern NSString *const iManIndexingCompletedNotification;