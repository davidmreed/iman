//
//  iManBrowser.m
//  iManEngine
//
//  Created by David Reed on 5/18/10.
//  Copyright 2010 David Reed. All rights reserved.
//

#import "iManPageDatabase.h"
#import <iManEngine/iManEnginePreferences.h>

@implementation iManPageDatabase

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
		_categoryDatabase = [[NSMutableDictionary alloc] init];
		_basenameDatabase = [[NSMutableDictionary alloc] init];
		_directoryListings = [[NSMutableDictionary alloc] init];
	}
	
	return self;
}

- initWithCoder:(NSCoder *)coder
{
	self = [super init];
	if (self) {
		if ([coder allowsKeyedCoding]) {
			_categoryDatabase = [[coder decodeObjectForKey:@"CategoryDatabase"] retain];
			_basenameDatabase = [[coder decodeObjectForKey:@"BasenameDatabase"] retain];
			_directoryListings = [[coder decodeObjectForKey:@"DirectoryListings"] retain];
			_manpaths = [[coder decodeObjectForKey:@"Manpaths"] retain];
		} else {
			_categoryDatabase = [[coder decodeObject] retain];
			_basenameDatabase = [[coder decodeObject] retain];
			_directoryListings = [[coder decodeObject] retain];
			_manpaths = [[coder decodeObject] retain];			
		}
	}
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	if ([coder allowsKeyedCoding]) {
		[coder encodeObject:_categoryDatabase forKey:@"CategoryDatabase"];
		[coder encodeObject:_basenameDatabase forKey:@"BasenameDatabase"];
		[coder encodeObject:_directoryListings forKey:@"DirectoryListings"];
		[coder encodeObject:_manpaths forKey:@"Manpaths"];
	} else {
		[coder encodeObject:_categoryDatabase];
		[coder encodeObject:_basenameDatabase];
		[coder encodeObject:_directoryListings];
		[coder encodeObject:_manpaths];
	}
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
			if ([fm fileExistsAtPath:file isDirectory:&isDir] && isDir) {
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
	NSString *path = [manpath stringByAppendingPathComponent:category];
	
	if ([_directoryListings objectForKey:path] == nil) {	
		NSFileManager *fm = [NSFileManager defaultManager];
		NSMutableArray *pages = [[NSMutableArray alloc] init];
		NSString *categoryPath = [manpath stringByAppendingPathComponent:[NSString stringWithFormat:@"man%@", category]];
		NSDirectoryEnumerator *dir = [fm enumeratorAtPath:categoryPath];
		
		for (NSString *path in dir) {
			// Note use of -hasPrefix: rather than -isEqualToString:. Many pages in category 3, for example, have extensions like .3ssl, .3pm, .3x, etc. These are contained under man3 and we treat them as such.
			if ([fm isReadableFileAtPath:path] &&
				([[path pathExtension] hasPrefix:category] || ([[path pathExtension] isEqualToString:@"gz"] && [[[path stringByDeletingPathExtension] pathExtension] hasPrefix:category]))) {
				NSString *basename, *properFilename, *nameWithCategory;
				
				// Add to the list of pages in this category.
				[pages addObject:path];
				
				// Add the object to the basename database.
				if ([[path pathExtension] isEqualToString:@"gz"]) 
					properFilename = [[path lastPathComponent] stringByDeletingPathExtension];
				else 
					properFilename = [path lastPathComponent];
				
				basename = [properFilename stringByDeletingPathExtension];
				nameWithCategory = [basename stringByAppendingPathExtension:category]; // We'll file it under its base name, its parent category name, and its own category name (i.e., basename, basename.3, basename.3pm). 
				// Add to the global basename database
				if ([_basenameDatabase objectForKey:basename] == nil)
					[_basenameDatabase setObject:[NSMutableSet setWithObject:path] forKey:basename];
				else
					[[_basenameDatabase objectForKey:basename] addObject:path];
				// Add to the basename database with its own category
				if ([_basenameDatabase objectForKey:properFilename] == nil)
					[_basenameDatabase setObject:[NSMutableSet setWithObject:path] forKey:properFilename];
				else
					[[_basenameDatabase objectForKey:properFilename] addObject:path];
				// Add to the basename database with parent category
				if ([_basenameDatabase objectForKey:nameWithCategory] == nil)
					[_basenameDatabase setObject:[NSMutableSet setWithObject:path] forKey:nameWithCategory];
				else
					[[_basenameDatabase objectForKey:nameWithCategory] addObject:path];
				
			}
		}
		
		[_directoryListings setObject:[NSArray arrayWithArray:pages] forKey:path];
		[pages release];
	}
	
	return [_directoryListings objectForKey:path];
}

- (NSArray *)pagesInCategory:(NSString *)category
{
	if ([_categoryDatabase objectForKey:category] == nil) {
		NSMutableArray *pages = [[NSMutableArray alloc] init];
		
		for (NSString *path in [self manpaths]) {
			[pages addObjectsFromArray:[self pagesInCategory:category underManpath:path]];
		}
		
		[_categoryDatabase setObject:[NSArray arrayWithArray:pages] forKey:category];
		[pages release];
	}
	
	return [_categoryDatabase objectForKey:category];
}

- (NSArray *)pagesWithBasename:(NSString *)basename
{
	return [[_basenameDatabase objectForKey:basename] allObjects];
}
		  
- (NSArray *)pagesWithBasename:(NSString *)basename inCategory:(NSString *)category
{
	return [[_basenameDatabase objectForKey:[basename stringByAppendingPathExtension:category]] allObjects];
}

- (void)dealloc
{
	[_basenameDatabase release];
	[_categoryDatabase release];
	[_directoryListings release];
	[_manpaths release];
	[super dealloc];
}

@end
