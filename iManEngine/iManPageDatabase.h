//
//  iManPageDatabase.h
//  iManEngine
//  Copyright (c) 2004-2010 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import <Cocoa/Cocoa.h>

@class iManRWLock;

@interface iManPageDatabase : NSObject <NSCoding> {
	NSArray *_manpaths;
	NSMutableSet *_sections;
	NSMutableDictionary *_sectionDatabase;
	NSMutableDictionary *_basenameDatabase;
	NSMutableDictionary *_directoryListings;
	iManRWLock *_lock;
}

- initWithManpaths:(NSArray *)paths;

- (NSArray *)manpaths;
- (NSArray *)sections;

- (NSArray *)pagesWithName:(NSString *)basename;
- (NSArray *)pagesWithName:(NSString *)basename inSection:(NSString *)category;
- (NSArray *)pagesInSection:(NSString *)category;

- (void)scanAllPages;

@end
