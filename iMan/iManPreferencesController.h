//
// iManPreferencesController.h
// iMan
// Copyright (c) 2004 by David Reed, distributed under the BSD License.
// see iman-macosx.sourceforge.net for details.
//

#import <Cocoa/Cocoa.h>

@interface iManPreferencesController : NSWindowController
{
    IBOutlet NSButton *boldStyleBold;
    IBOutlet NSColorWell *boldStyleColor;
    IBOutlet NSButton *boldStyleItalic;
    IBOutlet NSButton *boldStyleUnderline;
    IBOutlet NSButton *emStyleBold;
    IBOutlet NSColorWell *emStyleColor;
    IBOutlet NSButton *emStyleItalic;
    IBOutlet NSButton *emStyleUnderline;
    IBOutlet NSTextField *pageFont;
    
	IBOutlet NSTableView *pathTable;
	
	IBOutlet NSTableView *manpathList;
	IBOutlet NSButton *removeManpathButton;
	
    IBOutlet NSButton *showPageLinks;
    IBOutlet NSMatrix *handlePageLinks;
    IBOutlet NSMatrix *handleExternalLinks;
    IBOutlet NSMatrix *handleSearchResults;
    
	IBOutlet NSButton *alwaysCheckForUpdates;
	
	IBOutlet NSPanel *pathEditPanel;
	IBOutlet NSTextField *pathEditField;
	IBOutlet NSTextField *pathEditError;
	IBOutlet NSTextField *pathEditTitle;
	IBOutlet NSButton *pathEditOKButton;
	
	enum { editingManpath, editingToolPath } editOperation;
}

- (IBAction)changeBoldStyleColor:(id)sender;
- (IBAction)changeBoldStyleTrait:(id)sender;
- (IBAction)changeBoldStyleUnderline:(id)sender;
- (IBAction)changeEmStyleColor:(id)sender;
- (IBAction)changeEmStyleTrait:(id)sender;
- (IBAction)changeEmStyleUnderline:(id)sender;
- (IBAction)selectFont:(id)sender;

- (IBAction)showPageLinks:(id)sender;
- (IBAction)handlePageLinks:(id)sender;
- (IBAction)handleExternalLinks:(id)sender;
- (IBAction)handleSearchResults:(id)sender;

- (IBAction)addManPath:(id)sender;
- (IBAction)removeManPath:(id)sender;
- (IBAction)editManpath:(id)sender;

- (void)addManpathDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)editManpathDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;

- (IBAction)alwaysCheckForUpdates:(id)sender;

- (IBAction)pathEditOK:(id)sender;
- (IBAction)pathEditCancel:(id)sender;

@end
