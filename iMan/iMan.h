//
//  iMan.h
//  iMan
//  Copyright (c) 2004-2009 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import <Cocoa/Cocoa.h>

@class iManPreferencesController;

@interface iMan : NSObject
{	
    iManPreferencesController *_preferencesController;
}

+ (void)loadURLInNewDocument:(NSURL *)url;
+ (void)loadExternalURL:(NSURL *)url;

- (void)loadManpage:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error;

- (IBAction)updateIndex:(id)sender;
- (IBAction)emptyPageCache:(id)sender;
- (IBAction)showPreferences:(id)sender;
- (IBAction)showHelp:(id)sender;
- (IBAction)installCommandLineTool:(id)sender;

@end