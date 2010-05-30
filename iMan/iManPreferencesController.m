//
//  iManPreferencesController.m
//  iMan
//  Copyright (c) 2004-2010 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import "iManPreferencesController.h"
#import "iManConstants.h"
#import "NSUserDefaults+DMRArchiving.h"
#import <iManEngine/iManEngine.h>

@interface iManPreferencesController (PreferencesControllerPrivate)

- (void)_notifyDocuments;

@end

@implementation iManPreferencesController

#pragma mark -
#pragma mark NSWindowController Overrides

- (void)awakeFromNib
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSUserDefaultsController *controller = [NSUserDefaultsController sharedUserDefaultsController];
    NSFont *font;

    // Set up the font field.
    font = [defaults archivedObjectForKey:iManDefaultStyle];
    [pageFont setFont:font];
    [pageFont setStringValue:[NSString stringWithFormat:@"%@ %.0f", [font displayName], [font pointSize]]];

    // Set up the Bold Style box.
    [boldStyleColor setColor:[defaults archivedObjectForKey:iManBoldStyleColor]];

    // Set up the underlined/emphasized style box.
    [emStyleColor setColor:[defaults archivedObjectForKey:iManUnderlineStyleColor]];

    // Set up the link handling pane.
    [showPageLinks setState:[defaults boolForKey:iManShowPageLinks]];

    [handlePageLinks selectCellAtRow:[defaults integerForKey:iManHandlePageLinks] column:0];
    [handleExternalLinks selectCellAtRow:[defaults integerForKey:iManHandleExternalLinks] column:0];
    [handleSearchResults selectCellAtRow:[defaults integerForKey:iManHandleSearchResults] column:0];
		
	// Set the double action for the manpath editor.
	[manpathList setDoubleAction:@selector(editManpath:)];
	[pathTable setDoubleAction:@selector(editPath:)];
	
	// Observe our own preference keys so we can post the notification that tells all the documents to update their formatting.
	[controller addObserver:self forKeyPath:@"values.iManBoldStyleMakeBold" options:0 context:NULL];
	[controller addObserver:self forKeyPath:@"values.iManBoldStyleMakeItalic" options:0 context:NULL];
	[controller addObserver:self forKeyPath:@"values.iManBoldStyleMakeUnderline" options:0 context:NULL];
	[controller addObserver:self forKeyPath:@"values.iManUnderlineStyleMakeBold" options:0 context:NULL];
	[controller addObserver:self forKeyPath:@"values.iManUnderlineStyleMakeItalic" options:0 context:NULL];
	[controller addObserver:self forKeyPath:@"values.iManUnderlineStyleMakeUnderline" options:0 context:NULL];

	// If YES on close, we need to rescan the database. Make sure we know when we do close.
	[[self window] setDelegate:self];
	didEditManpath = NO;
}

- (void)windowWillClose:(NSNotification *)notification
{
	// If we changed the manpath list, rescan the database.
	if (didEditManpath) {
		// after we are done and control returns to the run loop.
		[[NSApp delegate] performSelector:@selector(rescanDatabase:) withObject:self afterDelay:0.1];
	}
}

#pragma mark -
#pragma mark Font and Style Management

- (IBAction)changeBoldStyleColor:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setArchivedObject:[sender color] forKey:iManBoldStyleColor];
    
    [self _notifyDocuments];
}


- (IBAction)changeEmStyleColor:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setArchivedObject:[sender color] forKey:iManUnderlineStyleColor];
    
    [self _notifyDocuments];
}

- (IBAction)selectFont:(id)sender
{
    [[NSFontPanel sharedFontPanel] setPanelFont:[[NSUserDefaults standardUserDefaults] archivedObjectForKey:iManDefaultStyle] isMultiple:NO];
    [[NSFontManager sharedFontManager] orderFrontFontPanel:self];
}

- (void)changeFont:(id)sender
{
    NSFont *font = [[NSUserDefaults standardUserDefaults] archivedObjectForKey:iManDefaultStyle];

    font = [sender convertFont:font];

    [[NSUserDefaults standardUserDefaults] setArchivedObject:font forKey:iManDefaultStyle];

    [pageFont setFont:font];
    [pageFont setStringValue:[NSString stringWithFormat:@"%@ %.0f", [font displayName], [font pointSize]]];
    
    [self _notifyDocuments];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	// All this object is observing is our own preference keys so we can send this notification.
	[self _notifyDocuments];
}

#pragma mark -
#pragma mark Link Settings

- (IBAction)showPageLinks:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setBool:[sender state] forKey:iManShowPageLinks];

    [self _notifyDocuments];
}

- (IBAction)handlePageLinks:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setInteger:[sender selectedRow] forKey:iManHandlePageLinks];
}

- (IBAction)handleExternalLinks:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setInteger:[sender selectedRow] forKey:iManHandleExternalLinks];
}

- (IBAction)handleSearchResults:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setInteger:[sender selectedRow] forKey:iManHandleSearchResults];
}

#pragma mark -
#pragma mark Manpath Editing

- (IBAction)addManPath:(id)sender
{
	if (pathEditPanel == nil)
		[NSBundle loadNibNamed:@"iManPathEditor" owner:self];
	
	[pathEditTitle setStringValue:NSLocalizedString(@"Add Manpath:", nil)];
	[pathEditOKButton setTitle:NSLocalizedString(@"Add", nil)];
	[pathEditField setStringValue:@""];
	[pathEditError setStringValue:@""];
	
	[NSApp beginSheet:pathEditPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(addManpathDidEnd:returnCode:contextInfo:)
		  contextInfo:NULL];
}

- (IBAction)removeManPath:(id)sender
{
	iManEnginePreferences *prefs = [iManEnginePreferences sharedInstance];
	NSMutableArray *paths = [[[iManEnginePreferences sharedInstance] manpaths] mutableCopy];
	NSEnumerator *selectedRows = [[[manpathList selectedRowEnumerator] allObjects] reverseObjectEnumerator];
	NSNumber *row;
	
	while ((row = [selectedRows nextObject]) != nil) 
		[paths removeObjectAtIndex:[row intValue]];
	
	[prefs setManpaths:paths];
	[paths release];
	[manpathList reloadData];
	didEditManpath = YES;
}

- (IBAction)editManpath:(id)sender
{
	if (pathEditPanel == nil)
		[NSBundle loadNibNamed:@"iManPathEditor" owner:self];
	
	editOperation = editingManpath;
	
	[pathEditTitle setStringValue:NSLocalizedString(@"Edit Manpath:", nil)];
	[pathEditOKButton setTitle:NSLocalizedString(@"OK", nil)];
	[pathEditField setStringValue:[[[iManEnginePreferences sharedInstance] manpaths] objectAtIndex:[sender clickedRow]]];
	[pathEditError setStringValue:@""];
	
	[NSApp beginSheet:pathEditPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(editManpathDidEnd:returnCode:contextInfo:)
		  contextInfo:(void *)[[NSNumber alloc] initWithInt:[sender clickedRow]]];
}	

- (void)addManpathDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];
	
	if (returnCode == NSOKButton) {
		[[iManEnginePreferences sharedInstance] setManpaths:[[[iManEnginePreferences sharedInstance] manpaths] arrayByAddingObject:[[[pathEditField stringValue] copy] autorelease]]];
		[manpathList reloadData];
		didEditManpath = YES;
	}
}

- (void)editManpathDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];
	
	if (returnCode == NSOKButton) {
		NSMutableArray *array = [[[iManEnginePreferences sharedInstance] manpaths] mutableCopy];
		[array replaceObjectAtIndex:[(NSNumber *)contextInfo intValue] withObject:[pathEditField stringValue]];
		[[iManEnginePreferences sharedInstance] setManpaths:array];
		[array release];
		[manpathList reloadData];
		didEditManpath = YES;
	}
	[(NSNumber *)contextInfo release];
}

#pragma mark -
#pragma mark Tool Path Editing

- (IBAction)editPath:(id)sender
{
	NSString *tool = [[[iManEnginePreferences sharedInstance] tools] objectAtIndex:[sender clickedRow]];
	
	if (pathEditPanel == nil)
		[NSBundle loadNibNamed:@"iManPathEditor" owner:self];
	
	editOperation = editingToolPath;
	
	[pathEditTitle setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Path for tool \"%@\":", nil), tool]];
	[pathEditOKButton setTitle:NSLocalizedString(@"OK", nil)];
	[pathEditField setStringValue:[[iManEnginePreferences sharedInstance] pathForTool:tool]];
	[pathEditError setStringValue:@""];
	
	[NSApp beginSheet:pathEditPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(editToolPathDidEnd:returnCode:contextInfo:)
		  contextInfo:(void *)tool];
}

- (void)editToolPathDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];
	
	if (returnCode == NSOKButton) {
		[[iManEnginePreferences sharedInstance] setPath:[pathEditField stringValue] forTool:(NSString *)contextInfo];
		[pathTable reloadData];
	}
}

#pragma mark -
#pragma mark Path editing utilities

- (IBAction)pathEditOK:(id)sender
{
	NSFileManager *manager = [NSFileManager defaultManager];
	NSString *path = [pathEditField stringValue];
	BOOL ok = YES;
	
	if (editOperation == editingManpath) {
		BOOL isDir;
		
		ok = ([manager fileExistsAtPath:path isDirectory:&isDir] && isDir);
	} else {		
		ok = ([manager fileExistsAtPath:path] 
			  && [manager isExecutableFileAtPath:path]
			  && [[[manager fileAttributesAtPath:path traverseLink:YES] fileType] isEqualToString:NSFileTypeRegular]);
	}
	
	if (ok) {
		[NSApp endSheet:pathEditPanel returnCode:NSOKButton];
	} else {
		NSBeep();
		[pathEditError setStringValue:NSLocalizedString(@"Invalid path.", nil)];
	}
}

- (IBAction)pathEditCancel:(id)sender
{
	[NSApp endSheet:pathEditPanel returnCode:NSCancelButton];
}


#pragma mark -
#pragma mark Table View (manpath and tool path) Delegate

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	if (tableView == pathTable)
		return [[[iManEnginePreferences sharedInstance] tools] count];

	return [[[iManEnginePreferences sharedInstance] manpaths] count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	iManEnginePreferences *prefs = [iManEnginePreferences sharedInstance];
	
	if (tableView == pathTable) {
		NSString *path;
	
		path = [prefs pathForTool:[[prefs tools] objectAtIndex:row]];
		if ([[tableColumn identifier] isEqualToString:@"Tool"]) {
			if (path == nil)
				return [[[NSAttributedString alloc] initWithString:[[prefs tools] objectAtIndex:row]
														attributes:[NSDictionary dictionaryWithObject:[NSColor redColor] forKey:NSForegroundColorAttributeName]] autorelease];
		
			return [[prefs tools] objectAtIndex:row];
		} else {
			return path;
		}
	} else {
		return [[prefs manpaths] objectAtIndex:row];
	}
}

- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{	
	return NO;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	if ([notification object] == manpathList)
		[removeManpathButton setEnabled:([manpathList numberOfSelectedRows] > 0)];
}

#pragma mark -
#pragma mark Private Methods

- (void)_notifyDocuments
{
    [[NSNotificationCenter defaultCenter] postNotificationName:iManStyleChangedNotification object:nil];
}

- (void)dealloc
{
	NSUserDefaultsController *controller = [NSUserDefaultsController sharedUserDefaultsController];
	[pathEditPanel release];
	[controller removeObserver:self forKeyPath:@"values.iManBoldStyleMakeBold"];
	[controller removeObserver:self forKeyPath:@"values.iManBoldStyleMakeItalic"];
	[controller removeObserver:self forKeyPath:@"values.iManBoldStyleMakeUnderline"];
	[controller removeObserver:self forKeyPath:@"values.iManUnderlineStyleMakeBold"];
	[controller removeObserver:self forKeyPath:@"values.iManUnderlineStyleMakeItalic"];
	[controller removeObserver:self forKeyPath:@"values.iManUnderlineStyleMakeUnderline"];
	[super dealloc];
}

@end
