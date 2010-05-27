//
//  iManPageDatabase.h
//  iManEngine
//
//  Created by David Reed on 5/18/10.
//  Copyright 2010 David Reed. All rights reserved.
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
- (NSArray *)pagesInSection:(NSString *)category underManpath:(NSString *)manpath;
- (NSArray *)pagesInSection:(NSString *)category;

- (NSArray *)pagesWithName:(NSString *)basename;
- (NSArray *)pagesWithName:(NSString *)basename inSection:(NSString *)category;

- (void)scanPagesInSection:(NSString *)category underManpath:(NSString *)manpath;
- (void)scanPagesInSection:(NSString *)category;
- (void)scanAllPages;


@end
