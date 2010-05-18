//
//  iMan.m
//  iMan
//  Copyright (c) 2004-2009 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import "iMan.h"
#import "iManConstants.h"
#import "iManDocument.h"
#import "iManSearchDocument.h"
#import "iManPreferencesController.h"
#import "iManIndexingWindowController.h"
#import <iManEngine/iManEngine.h>

@implementation iMan

#pragma mark -
#pragma mark Initialization

+ (void)initialize
{
    [[NSUserDefaults standardUserDefaults] registerDefaults:
        [NSDictionary dictionaryWithObjectsAndKeys:
		 [NSArchiver archivedDataWithRootObject:[NSFont userFixedPitchFontOfSize:11.0]], iManDefaultStyle,
		 [NSNumber numberWithBool:YES], iManBoldStyleMakeBold,
		 [NSNumber numberWithBool:NO], iManBoldStyleMakeItalic,
		 [NSNumber numberWithBool:NO], iManBoldStyleMakeUnderline,
		 [NSArchiver archivedDataWithRootObject:[NSColor blackColor]], iManBoldStyleColor,
		 [NSNumber numberWithBool:NO], iManUnderlineStyleMakeBold,
		 [NSNumber numberWithBool:NO], iManUnderlineStyleMakeItalic,
		 [NSNumber numberWithBool:YES], iManUnderlineStyleMakeUnderline,
		 [NSArchiver archivedDataWithRootObject:[NSColor blackColor]], iManUnderlineStyleColor,
		 [NSNumber numberWithBool:YES], iManShowPageLinks,
            [NSNumber numberWithInt:kiManHandleLinkInCurrentWindow], iManHandlePageLinks,
            [NSNumber numberWithInt:kiManHandleLinkInNewWindow], iManHandleExternalLinks,
            [NSNumber numberWithInt:kiManHandleLinkInNewWindow], iManHandleSearchResults,
            nil]];
}

#pragma mark -
#pragma mark NSApplication Delegate methods

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
	[NSApp setServicesProvider:self];
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
    return YES;
}

#pragma mark -
#pragma mark Services

- (void)loadManpage:(NSPasteboard *)pboard
		   userData:(NSString *)userData
			  error:(NSString **)error
{
	NSString *manpage = [pboard stringForType:NSStringPboardType]; 
	
	if (manpage != nil) {
		[NSApp activateIgnoringOtherApps:YES];
		[iManDocument loadURL:[NSURL URLWithString:[[NSString stringWithFormat:@"man:%@", manpage] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]] inNewDocument:[[NSUserDefaults standardUserDefaults] boolForKey:iManHandleExternalLinks]];
	}
}

#pragma mark -
#pragma mark IBActions

- (IBAction)updateIndex:(id)sender
{
	iManIndexingWindowController *indexingWindowController = [[iManIndexingWindowController alloc] initWithSelectedIndexes:nil];
	
	[indexingWindowController doRunModalUpdateWindow];
	
	[indexingWindowController release];
}

- (IBAction)emptyPageCache:(id)sender
{
	if (NSRunAlertPanel(NSLocalizedString(@"Empty Cache?", nil),
						NSLocalizedString(@"Do you want to empty the page cache? iMan will reload manpages from the disk. This action will clear your page history in all open windows.", nil),
						NSLocalizedString(@"OK", nil),
						NSLocalizedString(@"Cancel", nil),
						nil) == NSOKButton) {
		[iManPage clearCache];
		[[[NSDocumentController sharedDocumentController] documents] makeObjectsPerformSelector:@selector(clearHistory:) withObject:self];
	}
}

- (IBAction)installCommandLineTool:(id)sender
{
	// NOTE: this code derived from Smultron's SMLAuthenticationController.m
	// Copyright 2004-2009 Peter Borg; http://smultron.sourceforge.net
	NSString *toolPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"iman"];
	NSData *toolContents = [[NSData alloc] initWithContentsOfFile:toolPath];	
	NSTask *task = [[NSTask alloc] init];
    NSPipe *pipe = [[NSPipe alloc] init];
    NSFileHandle *writeHandle = [pipe fileHandleForWriting];
	NSInteger status;

    [task setLaunchPath:@"/usr/libexec/authopen"];
    [task setArguments:[NSArray arrayWithObjects:@"-c", @"-m", @"0755", @"-w", @"/usr/bin/iman", nil]];
    [task setStandardInput:pipe];
	
	[task launch];
	
	[writeHandle writeData:toolContents];
	[writeHandle closeFile];	
	[task waitUntilExit];
	status = [task terminationStatus];
		
	if (status != EXIT_SUCCESS)
		NSRunAlertPanel(NSLocalizedString(@"Unable to install command-line tool.", nil), NSLocalizedString(@"iMan was unable to install its command-line tool for unknown reasons.", nil), NSLocalizedString(@"OK", nil), nil, nil);
	
	[pipe release];
	[task release];
	[toolContents release];
}

- (IBAction)showPreferences:(id)sender
{
    if (_preferencesController == nil)
        _preferencesController = [[iManPreferencesController alloc] initWithWindowNibName:@"iManPreferences"];

    [_preferencesController showWindow:self];
}

- (IBAction)showHelp:(id)sender
{
    [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"iMan" ofType:@"1"] display:YES];
}

- (IBAction)newSearchWindow:(id)sender
{
    iManSearchDocument *doc;
    
    doc = [[iManSearchDocument alloc] init];
    [[NSDocumentController sharedDocumentController] addDocument:doc];
    [doc makeWindowControllers];
    [doc showWindows];
    
    [doc release];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}

@end