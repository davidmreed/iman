//
//  iMan.h
//  iMan
//  Copyright (c) 2004-2010 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import <Cocoa/Cocoa.h>

@class iManPreferencesController, iManPageDatabase;

@interface iMan : NSObject
{	
    iManPreferencesController *_preferencesController;
	iManPageDatabase *_pageDatabase;
	NSMutableArray *_deferredURLs;
	
	IBOutlet NSWindow *initializingDatabaseWindow;
	IBOutlet NSProgressIndicator *progressIndicator;
}

- (void)loadURLInNewDocument:(NSURL *)url;
- (void)loadExternalURL:(NSURL *)url;

- (iManPageDatabase *)sharedPageDatabase;

- (void)loadManpage:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error;

- (IBAction)updateIndex:(id)sender;
- (IBAction)emptyPageCache:(id)sender;
- (IBAction)installCommandLineTool:(id)sender;
- (IBAction)rescanDatabase:(id)sender;
- (IBAction)showPreferences:(id)sender;
- (IBAction)showHelp:(id)sender;

@end