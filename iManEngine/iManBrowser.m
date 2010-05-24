//
//  iManBrowser.m
//  iManEngine
//
//  Created by David Reed on 5/18/10.
//  Copyright 2010 David Reed. All rights reserved.
//

#import "iManBrowser.h"

@implementation iManBrowser

- init
{
	self = [self initWithManpaths:[[iManEnginePreferences sharedInstance] manpaths]];
	
	return self;
}

- initWithManpaths:(NSArray *)paths
{
	self = [super init];
	if (self != nil) {
		_manpaths = [paths copy];
	}
	
	return self;
}

- (NSArray *)manpaths
{
	return _manpaths;
}

- (NSArray *)categories
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSMutableSet *cats = [NSMutableSet set];
	
	for (NSString *path in [self manpaths]) {
		NSDirectoryEnumerator *dir = [fm enumeratorAtPath:path];
		
		for (NSString *file in dir) {
			BOOL isDir;
			if ([fm fileExistsAtPath:dir isDirectory:&isDir] && isDir) {
				[dir skipDescendents];
				if ([[file lastPathComponent] hasPrefix:@"man"]) {
					[cats addObject:[[file lastPathComponent] substringFromIndex:3]];
				}
			}
		}
	}
	
	return [cats allObjects];
}

- (NSArray *)pagesInCategory:(NSString *)category underManpath:(NSString *)manpath
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSMutableArray *pages = [[NSMutableArray alloc] init];
	NSString *categoryPath = [manpath stringByAppendingPathComponent:[NSString stringWithFormat:@"man%@", category]];
	NSDirectoryEnumerator *dir = [fm enumeratorAtPath:categoryPath];
	
	for (NSString *path in dir) {
		if ([fm isReadableFileAtPath:path] &&
			([[path pathExtension] isEqualToString:category] || [[path pathExtension] isEqualToString:[NSString stringWithFormat:@"%@.gz", category]])) {
			[pages addObject:path];
		}
	}
	
	return [pages autorelease];
}

- (NSArray *)pagesinCategory:(NSString *)category
{
	NSMutableArray *pages = [[NSMutableArray alloc] init];
	
	for (NSString *path in [self manpaths]) {
		[pages addObjectsFromArray:[self pagesinCategory:category underManpath:path]]
	}
	
	return [pages autorelease];
}

- (void)dealloc
{
	[_manpaths release];
	[super dealloc];
}

@end
