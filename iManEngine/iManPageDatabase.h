//
//  iManBrowser.h
//  iManEngine
//
//  Created by David Reed on 5/18/10.
//  Copyright 2010 David Reed. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface iManPageDatabase : NSObject <NSCoding> {
	NSArray *_manpaths;
	NSMutableDictionary *_categoryDatabase;
	NSMutableDictionary *_basenameDatabase;
	NSMutableDictionary *_directoryListings;
}

- initWithManpaths:(NSArray *)paths;

- (NSArray *)manpaths;
- (NSArray *)categories;
- (NSArray *)pagesInCategory:(NSString *)category underManpath:(NSString *)manpath;
- (NSArray *)pagesInCategory:(NSString *)category;

- (NSArray *)pagesWithBasename:(NSString *)basename;
- (NSArray *)pagesWithBasename:(NSString *)basename inCategory:(NSString *)category;

@end
