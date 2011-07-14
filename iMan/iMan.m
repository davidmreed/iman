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

@interface iMan (Private)

- (void)_processStoredURLs;
- (void)_initializePageDatabase:(id)ignored;
- (void)_initializePageDatabaseDidEnd:(id)ignored;

@end

@implementation iMan

#pragma mark -
#pragma mark Initialization

+ (void)initialize
{
	// Find a default font we like. We need a monospace font with bold and italic faces (so not Andale Mono and not Monaco, the -userFixedPitchFont). Try Menlo first, then Courier, then fall back on the system's choice.
	NSFont *defaultFont;
	
	defaultFont = [NSFont fontWithName:@"Menlo-Regular" size:11.0];
	if (defaultFont == nil)
		defaultFont = [NSFont fontWithName:@"Courier" size:11.0];
	if (defaultFont == nil)
		defaultFont = [NSFont userFixedPitchFontOfSize:11.0];
	
    [[NSUserDefaults standardUserDefaults] registerDefaults:
        [NSDictionary dictionaryWithObjectsAndKeys:
		 [NSArchiver archivedDataWithRootObject:defaultFont], iManDefaultStyle,
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
		 [NSNumber numberWithInt:kiManHandleLinkInCurrentWindow], iManHandleSearchResults,
		 [NSNumber numberWithBool:NO], iManShowPageSelectionPanelForDuplicates,
            nil]];
}

#pragma mark -
#pragma mark Convenience URL loading methods

- (void)loadURLInNewDocument:(NSURL *)url
{
	iManDocument *currentDocument = [[NSDocumentController sharedDocumentController] currentDocument];
	
	// If we have a document open which is not displaying a page, use it rather than opening a new document.
	if ((currentDocument != nil) && ([currentDocument documentState] == iManDocumentStateNone)) {
		[currentDocument loadPageWithURL:url];
	} else {
		iManDocument *docToLoad = [[NSDocumentController sharedDocumentController] openUntitledDocumentAndDisplay:YES error:nil];
		[docToLoad loadPageWithURL:url];
	}
}	

- (void)loadExternalURL:(NSURL *)url
{
	NSDocumentController *documentController = [NSDocumentController sharedDocumentController];
	
	if (_pageDatabase == nil) {
		// if this is the case, -applicationDidFinishLaunching: has not completed yet (file-open events can be received first).
		// If we pass the URL off to iManDocument at this time, it will not be able to find it (since _pageDatabase = nil).
		// However, we may need to run our building-database screen in order to initialize the database, which won't (?) work properly until the run loop has started *after* that method completes.
		// Hence, we save off this URL and -applicationDidFinishLaunching: will just resend -loadExternalURL: for all saved URLs.
		if (_deferredURLs == nil)
			_deferredURLs = [[NSMutableArray alloc] init];
		
		[_deferredURLs addObject:url];
	} else {
		// open in current doc if possible.
		if (([[NSUserDefaults standardUserDefaults] integerForKey:iManHandleExternalLinks] == kiManHandleLinkInCurrentWindow) &&
			([documentController currentDocument] != nil)) {
			[[[documentController currentDocument] windowControllers] makeObjectsPerformSelector:@selector(showWindow:)];
			[[documentController currentDocument] loadPageWithURL:url];
		} else {
			[self loadURLInNewDocument:url];
		}
	}
}

#pragma mark -
#pragma mark NSApplication Delegate methods

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
	[NSApp setServicesProvider:self];
	
	// If we don't have a custom MANPATH set, we'll need to develop one from the system.
	if ([[[iManEnginePreferences sharedInstance] manpaths] count] == 0) {
		NSMutableArray *defaultManpath = [[NSMutableArray alloc] init];
	
		// If we're running on Leopard, there will be a /etc/manpaths (1 path per line) and a directory /etc/manpaths.d whose contents each contain 1 path per line.
		// Just try to read the files and use a reasonable default if there's an exception or no paths are found.
		// see http://hea-www.harvard.edu/~fine/OSX/path_helper.html for assistance with this oddness.
		
		@try {
			NSData *data = [[NSData alloc] initWithContentsOfFile:@"/etc/manpaths"];
			
			if (data != nil) {
				NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
				
				for (NSString *path in [string componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
					if ([[path stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length] > 0) {
						[defaultManpath addObject:[path stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
					}
				}
				
				[string release];
				[data release];
			}
			
			NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:@"/etc/manpaths.d"];
			
			if (enumerator != nil) {
				for (NSString *file in enumerator) {
					if ([[enumerator fileAttributes] fileType] == NSFileTypeRegular) {
						NSData *data = [[NSData alloc] initWithContentsOfFile:[@"/etc/manpaths.d" stringByAppendingPathComponent:file]];
						
						if (data != nil) {
							NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
							
							for (NSString *path in [string componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
								if ([[path stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length] > 0) {
									[defaultManpath addObject:[path stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
								}
							}
							
							[string release];
							[data release];
						}
					}
				}
			}
		}
		@catch (NSException *e) {
			// Do nothing.
		}
		@finally {
			if ([defaultManpath count] == 0) {
				// Either we're not running on 10.5+ or something blew up. Use a reasonable default MANPATH.
				[defaultManpath addObjectsFromArray:[NSArray arrayWithObjects:@"/usr/share/man", @"/usr/local/share/man", @"/usr/local/man", @"/usr/X11/man", @"/usr/X11R6/man", @"/sw/share/man", @"/Developer/usr/share/man", nil]];
			}
		}
			
		[[iManEnginePreferences sharedInstance] setManpaths:defaultManpath];
		[defaultManpath release];
	}
	
	// Set up our page database and make sure that it is initialized.
	// Initialize from saved data if possible.
	
	NSString *path = [[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"iMan/iManPageDatabase"];
	
	if ([[NSFileManager defaultManager] isReadableFileAtPath:path]) {
		[self willChangeValueForKey:@"sharedPageDatabase"];
		@try {
			_pageDatabase = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
		} @catch (id e) {
			_pageDatabase = nil;
		}
		if (_pageDatabase != nil) {
			[_pageDatabase retain];
		} else {
			[[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
		}
		[self didChangeValueForKey:@"sharedPageDatabase"];
	}

	// Make sure that our current manpath is congruent with that for which the database was generated.
	// In testing this has gotten out of sync; it's not clear that this would ever happen in real-world usage.
	if ((_pageDatabase != nil) && ![[_pageDatabase manpaths] isEqualToArray:[[iManEnginePreferences sharedInstance] manpaths]]) {
		[_pageDatabase release];
		_pageDatabase = nil;
	}

	if (_pageDatabase == nil) {
		// Create a new page database, present a dialogue box, and spin off a thread to build the database.
		[self willChangeValueForKey:@"sharedPageDatabase"];
		_pageDatabase = [[iManPageDatabase alloc] initWithManpaths:[[iManEnginePreferences sharedInstance] manpaths]];
		[self didChangeValueForKey:@"sharedPageDatabase"];
		
		[NSBundle loadNibNamed:@"iManInitializingDatabaseWindow" owner:self];
		[progressIndicator startAnimation:self];
		[initializingDatabaseWindow center];
		[NSApp beginSheet:initializingDatabaseWindow modalForWindow:nil modalDelegate:self didEndSelector:nil contextInfo:NULL];
		[[NSOperationQueue iManEngineOperationQueue] addOperation:[[[NSInvocationOperation alloc] initWithTarget:self selector:@selector(_initializePageDatabase:) object:nil] autorelease]];
		//		[NSThread detachNewThreadSelector:@selector(_initializePageDatabase:) toTarget:self withObject:nil];
	} else {
		[self _processStoredURLs];
	}

}

- (void)_processStoredURLs
{
	// If we received requests to open URLs (which come in between -applicationWillFinishLaunching: and -applicationDidFinishLaunching: and are stored up in _deferredURLs), we can now process them.
	if (_deferredURLs != nil) {
		for (NSURL *url in _deferredURLs) {
			[self loadExternalURL:url];
		}
		
		[_deferredURLs release];
		_deferredURLs = nil;
	}
}	

- (void)_initializePageDatabase:(id)ignored
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	// iManPageDatabase is thread-safe.
	[_pageDatabase scanAllPages];
	
	[self performSelectorOnMainThread:@selector(_initializePageDatabaseDidEnd:) withObject:nil waitUntilDone:NO];
	
	// Write the database to disk.
	NSString *directory = [[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"iMan"];
	
	if (![[NSFileManager defaultManager] fileExistsAtPath:directory]) {
		[[NSFileManager defaultManager] createDirectoryAtPath:directory attributes:nil];
	}
	
	[NSKeyedArchiver archiveRootObject:_pageDatabase toFile:[directory stringByAppendingPathComponent:@"iManPageDatabase"]];	
	
	[pool release];
}

- (void)_initializePageDatabaseDidEnd:(id)ignored
{
	[NSApp endSheet:initializingDatabaseWindow];
	[initializingDatabaseWindow release];
	if (_deferredURLs != nil) 
		[self _processStoredURLs];
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
    return YES;
}

#pragma mark -
#pragma mark Services

- (void)loadManpage:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error
{
	NSString *manpage = [pboard stringForType:NSStringPboardType]; 
	
	if (manpage != nil) {
		[NSApp activateIgnoringOtherApps:YES];
		[self loadExternalURL:[NSURL URLWithString:[[NSString stringWithFormat:@"man:%@", manpage] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
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
		[[iManPageCache sharedCache] clearCache];
		[[[NSDocumentController sharedDocumentController] documents] makeObjectsPerformSelector:@selector(clearHistory:) withObject:self];
	}
}

- (IBAction)rescanDatabase:(id)sender
{
	[self willChangeValueForKey:@"sharedPageDatabase"];
	[_pageDatabase release];
	_pageDatabase = [[iManPageDatabase alloc] initWithManpaths:[[iManEnginePreferences sharedInstance] manpaths]];
	[self didChangeValueForKey:@"sharedPageDatabase"];
	
	[NSBundle loadNibNamed:@"iManInitializingDatabaseWindow" owner:self];
	[progressIndicator startAnimation:self];
	[initializingDatabaseWindow center];
	[NSApp beginSheet:initializingDatabaseWindow modalForWindow:nil modalDelegate:self didEndSelector:nil contextInfo:NULL];
	[[NSOperationQueue iManEngineOperationQueue] addOperation:[[[NSInvocationOperation alloc] initWithTarget:self selector:@selector(_initializePageDatabase:) object:nil] autorelease]];

	//	[NSThread detachNewThreadSelector:@selector(_initializePageDatabase:) toTarget:self withObject:nil];
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