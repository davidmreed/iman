//
//  iMan.m
//  iMan
//  Copyright (c) 2004-2010 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import "iMan.h"
#import "iManConstants.h"
#import "iManDocument.h"
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
#pragma mark Convenience URL loading method

+ (void)loadURLInNewDocument:(NSURL *)url
{
	iManDocument *docToLoad = [[iManDocument alloc] init];
	[[NSDocumentController sharedDocumentController] addDocument:docToLoad];
	[docToLoad makeWindowControllers];
	[docToLoad showWindows];
	[docToLoad release];
	
	[[[[docToLoad windowControllers] lastObject] window] makeKeyAndOrderFront:nil];
	[docToLoad loadPageWithURL:url];
}	

+ (void)loadExternalURL:(NSURL *)url
{
	NSDocumentController *documentController = [NSDocumentController sharedDocumentController];
	
	// open in current doc if possible.
    if ([[NSUserDefaults standardUserDefaults] integerForKey:iManHandleExternalLinks] == kiManHandleLinkInCurrentWindow) {
		[[[documentController currentDocument] windowControllers] makeObjectsPerformSelector:@selector(showWindow:)];
		[[documentController currentDocument] loadPageWithURL:url];
	} else {
		[self loadURLInNewDocument:url];
	}
}	

#pragma mark -
#pragma mark NSApplication Delegate methods

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
	[NSApp setServicesProvider:self];
	
	// Set up our page database and make sure that it is initialized.
	// Initialize from saved data if possible.
	
	NSString *path = [[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"iMan/iManPageDatabase"];
	
	if ([[NSFileManager defaultManager] isReadableFileAtPath:path]) {
		_pageDatabase = [NSUnarchiver unarchiveObjectWithFile:path];
		if (_pageDatabase != nil) {
			[_pageDatabase retain];
		} else {
			[[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
		}
	}
	
	if (_pageDatabase == nil) {
		// Create a new page database, present a dialogue box, and spin off a thread to build the database.
		_pageDatabase = [[iManPageDatabase alloc] initWithManpaths:[[iManEnginePreferences sharedInstance] manpaths]];
				
		[NSBundle loadNibNamed:@"iManInitializingDatabaseWindow" owner:self];
		[progressIndicator startAnimation:self];
		[initializingDatabaseWindow center];
		[NSApp beginSheet:initializingDatabaseWindow modalForWindow:nil modalDelegate:self didEndSelector:nil contextInfo:NULL];
		[NSThread detachNewThreadSelector:@selector(_initializePageDatabase:) toTarget:self withObject:nil];
	}
}

- (void)_initializePageDatabase:(id)ignored
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	// iManPageDatabase is thread-safe.
	[_pageDatabase scanAllPages];
	
	[self performSelectorOnMainThread:@selector(_initializePageDatabaseDidEnd:) withObject:nil waitUntilDone:NO];
	
	[pool release];
}

- (void)_initializePageDatabaseDidEnd:(id)ignored
{
	[NSApp endSheet:initializingDatabaseWindow];
	[initializingDatabaseWindow release];
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
    return YES;
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
	NSString *directory = [[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"iMan"];
	
	if (![[NSFileManager defaultManager] fileExistsAtPath:directory]) {
		[[NSFileManager defaultManager] createDirectoryAtPath:directory attributes:nil];
	}
	
	[NSArchiver archiveRootObject:_pageDatabase toFile:[directory stringByAppendingPathComponent:@"iManPageDatabase"]];
}

#pragma mark -
#pragma mark Services

- (void)loadManpage:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error
{
	NSString *manpage = [pboard stringForType:NSStringPboardType]; 
	
	if (manpage != nil) {
		[NSApp activateIgnoringOtherApps:YES];
		[iMan loadExternalURL:[NSURL URLWithString:[[NSString stringWithFormat:@"man:%@", manpage] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
	}
}

#pragma mark -

- (iManPageDatabase *)sharedPageDatabase
{
	return _pageDatabase;
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

- (IBAction)rescanDatabase:(id)sender
{
	[_pageDatabase release];
	_pageDatabase = [[iManPageDatabase alloc] initWithManpaths:[[iManEnginePreferences sharedInstance] manpaths]];
		
	[NSBundle loadNibNamed:@"iManInitializingDatabaseWindow" owner:self];
	[progressIndicator startAnimation:self];
	[initializingDatabaseWindow center];
	[NSApp beginSheet:initializingDatabaseWindow modalForWindow:nil modalDelegate:self didEndSelector:nil contextInfo:NULL];
	[NSThread detachNewThreadSelector:@selector(_initializePageDatabase:) toTarget:self withObject:nil];
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

- (void)dealloc
{
	[_pageDatabase release];
	[_preferencesController release];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}

@end