//
//  iManPreferencesController.m
//  iMan
//  Copyright (c) 2004-2009 by David Reed, distributed under the BSD License.
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
#pragma mark Initialization

- (void)awakeFromNib
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSFont *font;
    NSDictionary *style;

    // Set up the font field.
    font = [defaults archivedObjectForKey:iManPageFont];
    [pageFont setFont:font];
    [pageFont setStringValue:[NSString stringWithFormat:@"%@ %.0f", [font displayName], [font pointSize]]];

    // Set up the Bold Style box.
    style = [defaults archivedObjectForKey:iManBoldStyle];

    [boldStyleBold setState:(([[NSFontManager sharedFontManager] traitsOfFont:[style objectForKey:NSFontAttributeName]] & NSBoldFontMask) ? NSOnState : NSOffState)];
    [boldStyleItalic setState:([[NSFontManager sharedFontManager] traitsOfFont:[style objectForKey:NSFontAttributeName]] & NSItalicFontMask)];

    [boldStyleUnderline setState:([[style objectForKey:NSUnderlineStyleAttributeName] intValue] & NSSingleUnderlineStyle)];
    [boldStyleColor setColor:[style objectForKey:NSForegroundColorAttributeName]];

    // Set up the underlined/emphasized style box.
    style = [defaults archivedObjectForKey:iManEmphasizedStyle];

    [emStyleBold setState:([[NSFontManager sharedFontManager] traitsOfFont:[style objectForKey:NSFontAttributeName]] & NSBoldFontMask)];
    [emStyleItalic setState:([[NSFontManager sharedFontManager] traitsOfFont:[style objectForKey:NSFontAttributeName]] & NSItalicFontMask)];
    [emStyleUnderline setState:([[style objectForKey:NSUnderlineStyleAttributeName] intValue] & NSSingleUnderlineStyle)];
    [emStyleColor setColor:[style objectForKey:NSForegroundColorAttributeName]];

    // Set up the link handling pane.
    [showPageLinks setState:[defaults boolForKey:iManShowPageLinks]];

    [handlePageLinks selectCellAtRow:[defaults integerForKey:iManHandlePageLinks] column:0];
    [handleExternalLinks selectCellAtRow:[defaults integerForKey:iManHandleExternalLinks] column:0];
    [handleSearchResults selectCellAtRow:[defaults integerForKey:iManHandleSearchResults] column:0];
		
	// Set the double action for the manpath editor.
	[manpathList setDoubleAction:@selector(editManpath:)];
	[pathTable setDoubleAction:@selector(editPath:)];
}

#pragma mark -
#pragma mark Font and Style Management

- (IBAction)changeBoldStyleColor:(id)sender
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] archivedObjectForKey:iManBoldStyle]];

    [dictionary setObject:[sender color] forKey:NSForegroundColorAttributeName];

    [[NSUserDefaults standardUserDefaults] setArchivedObject:dictionary forKey:iManBoldStyle];
    
    [self _notifyDocuments];
}

- (IBAction)changeBoldStyleTrait:(id)sender
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] archivedObjectForKey:iManBoldStyle]];
    NSFont *font;

    font = [dictionary objectForKey:NSFontAttributeName];

    if ([sender state] == NSOnState)
        [dictionary setObject:[[NSFontManager sharedFontManager] convertFont:font toHaveTrait:[sender tag]] forKey:NSFontAttributeName];
    else
        [dictionary setObject:[[NSFontManager sharedFontManager] convertFont:font toNotHaveTrait:[sender tag]] forKey:NSFontAttributeName];

    [[NSUserDefaults standardUserDefaults] setArchivedObject:dictionary forKey:iManBoldStyle];
    
    [self _notifyDocuments];
}

- (IBAction)changeBoldStyleUnderline:(id)sender
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] archivedObjectForKey:iManBoldStyle]];

    if ([sender state] == NSOnState)
        [dictionary setObject:[NSNumber numberWithInt:NSSingleUnderlineStyle] forKey:NSUnderlineStyleAttributeName];
    else
        [dictionary removeObjectForKey:NSUnderlineStyleAttributeName];

    [[NSUserDefaults standardUserDefaults] setArchivedObject:dictionary forKey:iManBoldStyle];
    [self _notifyDocuments];
}

- (IBAction)changeEmStyleColor:(id)sender
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] archivedObjectForKey:iManEmphasizedStyle]];

    [dictionary setObject:[sender color] forKey:NSForegroundColorAttributeName];

    [[NSUserDefaults standardUserDefaults] setArchivedObject:dictionary forKey:iManEmphasizedStyle];
    
    [self _notifyDocuments];
}

- (IBAction)changeEmStyleTrait:(id)sender
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] archivedObjectForKey:iManEmphasizedStyle]];
    NSFont *font;

    font = [dictionary objectForKey:NSFontAttributeName];

    if ([sender state] == NSOnState)
        [dictionary setObject:[[NSFontManager sharedFontManager] convertFont:font toHaveTrait:[sender tag]] forKey:NSFontAttributeName];
    else
        [dictionary setObject:[[NSFontManager sharedFontManager] convertFont:font toNotHaveTrait:[sender tag]] forKey:NSFontAttributeName];

    [[NSUserDefaults standardUserDefaults] setArchivedObject:dictionary forKey:iManEmphasizedStyle];
    
    [self _notifyDocuments];
}

- (IBAction)changeEmStyleUnderline:(id)sender
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] archivedObjectForKey:iManEmphasizedStyle]];

    if ([sender state] == NSOnState)
        [dictionary setObject:[NSNumber numberWithInt:NSSingleUnderlineStyle] forKey:NSUnderlineStyleAttributeName];
    else
        [dictionary removeObjectForKey:NSUnderlineStyleAttributeName];

    [[NSUserDefaults standardUserDefaults] setArchivedObject:dictionary forKey:iManEmphasizedStyle];
    
    [self _notifyDocuments];
}

- (IBAction)selectFont:(id)sender
{
    [[NSFontPanel sharedFontPanel] setPanelFont:[[NSUserDefaults standardUserDefaults] archivedObjectForKey:iManPageFont] isMultiple:NO];
    [[NSFontManager sharedFontManager] orderFrontFontPanel:self];
}

- (void)changeFont:(id)sender
{
    NSFont *font = [[NSUserDefaults standardUserDefaults] archivedObjectForKey:iManPageFont];

    font = [sender convertFont:font];

    [[NSUserDefaults standardUserDefaults] setArchivedObject:font
                                                      forKey:iManPageFont];

    { // Fix the bold style dictionary (applied directly to bold text).
        NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] archivedObjectForKey:iManBoldStyle]];
        NSFont *newFont = font;

        newFont = [[NSFontManager sharedFontManager] convertFont:newFont toHaveTrait:(([boldStyleBold state] == NSOnState) ? NSBoldFontMask : NSUnboldFontMask)];
        newFont = [[NSFontManager sharedFontManager] convertFont:newFont toHaveTrait:(([boldStyleItalic state] == NSOnState) ? NSItalicFontMask : NSUnitalicFontMask)];

        [dictionary setObject:newFont forKey:NSFontAttributeName];

        [[NSUserDefaults standardUserDefaults] setArchivedObject:dictionary forKey:iManBoldStyle];
    }

    { // do the same for emphasis dictionary.
        NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] archivedObjectForKey:iManEmphasizedStyle]];
        NSFont *newFont = font;

        newFont = [[NSFontManager sharedFontManager] convertFont:newFont toHaveTrait:(([emStyleBold state] == NSOnState) ? NSBoldFontMask : NSUnboldFontMask)];
        newFont = [[NSFontManager sharedFontManager] convertFont:newFont toHaveTrait:(([emStyleItalic state] == NSOnState) ? NSItalicFontMask : NSUnitalicFontMask)];

        [dictionary setObject:newFont forKey:NSFontAttributeName];

        [[NSUserDefaults standardUserDefaults] setArchivedObject:dictionary forKey:iManEmphasizedStyle];
    }

    [pageFont setFont:font];
    [pageFont setStringValue:[NSString stringWithFormat:@"%@ %.0f", [font displayName], [font pointSize]]];
    
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
		  contextInfo:(void *)[sender clickedRow]];
}	

- (void)addManpathDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];
	
	if (returnCode == NSOKButton) {
		[[iManEnginePreferences sharedInstance] setManpaths:[[[iManEnginePreferences sharedInstance] manpaths] arrayByAddingObject:[[[pathEditField stringValue] copy] autorelease]]];
		[manpathList reloadData];
	}
}

- (void)editManpathDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];
	
	if (returnCode == NSOKButton) {
		NSMutableArray *array = [[[iManEnginePreferences sharedInstance] manpaths] mutableCopy];
		[array replaceObjectAtIndex:(int)contextInfo withObject:[pathEditField stringValue]];
		[[iManEnginePreferences sharedInstance] setManpaths:array];
		[array release];
		[manpathList reloadData];
	}
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

// FIXME: there is quite a lag on first selecting the Manpath tab.

- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
	if (tableView == pathTable)
		return [[[iManEnginePreferences sharedInstance] tools] count];

	return [[[iManEnginePreferences sharedInstance] manpaths] count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
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

/*- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	iManEnginePreferences *prefs = [iManEnginePreferences sharedInstance];

	if (tableView == pathTable) {
		if ([[NSFileManager defaultManager] isExecutableFileAtPath:object] &&
			[[[[NSFileManager defaultManager] fileAttributesAtPath:object traverseLink:YES] fileType] isEqualToString:NSFileTypeRegular]) {
			[prefs setPath:object forTool:[[prefs tools] objectAtIndex:row]];
		} else {
			NSBeginAlertSheet(NSLocalizedString(@"Invalid path.", nil), 
							  NSLocalizedString(@"OK", nil), 
							  nil, nil, 
							  [self window], 
							  nil, NULL, NULL, NULL, 
							  NSLocalizedString(@"%@ is not an executable file. Please enter the path to an executable file to use for the tool \"%@\".", nil), 
							  object,
							  [[prefs tools] objectAtIndex:row]);
			[tableView reloadData];
		}
	}
}*/

- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
//	if (tableView == pathTable)
//		return [[tableColumn identifier] isEqualToString:@"Path"];
	
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
    [[NSNotificationCenter defaultCenter] postNotificationName:iManFontChangedNotification
                                                        object:nil];
}

@end
