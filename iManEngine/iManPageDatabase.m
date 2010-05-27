//
//  iManPageDatabase.m
//  iManEngine
//
//  Created by David Reed on 5/18/10.
//  Copyright 2010 David Reed. All rights reserved.
//

#import "iManPageDatabase.h"
#import <iManEngine/iManEnginePreferences.h>
#import <iManEngine/iManRWLock.h>

@implementation iManPageDatabase

- initWithManpaths:(NSArray *)paths
{
	self = [super init];
	if (self != nil) {
		_manpaths = [paths copy];
		_sectionDatabase = [[NSMutableDictionary alloc] init];
		_basenameDatabase = [[NSMutableDictionary alloc] init];
		_directoryListings = [[NSMutableDictionary alloc] init];
		_lock = [[iManRWLock alloc] init];
	}
	
	return self;
}

- initWithCoder:(NSCoder *)coder
{
	self = [super init];
	if (self) {
		if ([coder allowsKeyedCoding]) {
			_sectionDatabase = [[coder decodeObjectForKey:@"CategoryDatabase"] retain];
			_basenameDatabase = [[coder decodeObjectForKey:@"BasenameDatabase"] retain];
			_directoryListings = [[coder decodeObjectForKey:@"DirectoryListings"] retain];
			_manpaths = [[coder decodeObjectForKey:@"Manpaths"] retain];
		} else {
			_sectionDatabase = [[coder decodeObject] retain];
			_basenameDatabase = [[coder decodeObject] retain];
			_directoryListings = [[coder decodeObject] retain];
			_manpaths = [[coder decodeObject] retain];			
		}
	}
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[_lock readLock];
	if ([coder allowsKeyedCoding]) {
		[coder encodeObject:_sectionDatabase forKey:@"CategoryDatabase"];
		[coder encodeObject:_basenameDatabase forKey:@"BasenameDatabase"];
		[coder encodeObject:_directoryListings forKey:@"DirectoryListings"];
		[coder encodeObject:_manpaths forKey:@"Manpaths"];
	} else {
		[coder encodeObject:_sectionDatabase];
		[coder encodeObject:_basenameDatabase];
		[coder encodeObject:_directoryListings];
		[coder encodeObject:_manpaths];
	}
	[_lock unlock];
}

- (NSArray *)manpaths
{
	// immutable ivar; no lock needed.
	return _manpaths;
}

- (NSArray *)sections
{
	NSArray *ret;
	
	[_lock readLock];
	if (_sections != nil) {
		ret = [_sections allObjects];
	} else {
		NSFileManager *fm = [NSFileManager defaultManager];

		[_lock unlock];
		[_lock writeLock];
		
		_sections = [[NSMutableSet alloc] init];
		
		for (NSString *path in [self manpaths]) {
			NSDirectoryEnumerator *dir = [fm enumeratorAtPath:path];
			
			for (NSString *file in dir) {
				BOOL isDir;
				if ([fm fileExistsAtPath:[path stringByAppendingPathComponent:file] isDirectory:&isDir] && isDir) {
					[dir skipDescendents];
					if ([[file lastPathComponent] hasPrefix:@"man"]) {
						[_sections addObject:[[file lastPathComponent] substringFromIndex:3]];
					}
				}
			}
		}

		ret = [_sections allObjects];
	}
	
	[_lock unlock];
	
	return ret;
}

- (NSArray *)pagesInSection:(NSString *)category underManpath:(NSString *)manpath
{
	NSString *path = [manpath stringByAppendingPathComponent:[NSString stringWithFormat:@"man%@", category]];
	NSArray *ret;
	
	[_lock readLock];
	ret = [NSArray arrayWithArray:[_directoryListings objectForKey:path]];
	[_lock unlock];
	
	if (ret == nil) {
		[self scanPagesInSection:category underManpath:manpath];
		return [self pagesInSection:category underManpath:manpath];
	}
	
	return ret;
}

- (void)scanPagesInSection:(NSString *)category underManpath:(NSString *)manpath
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSMutableArray *pages = [[NSMutableArray alloc] init];
	NSString *categoryPath = [manpath stringByAppendingPathComponent:[NSString stringWithFormat:@"man%@", category]];
	NSDirectoryEnumerator *dir = [fm enumeratorAtPath:categoryPath];
	
	for (NSString *path in dir) {
		// Note use of -hasPrefix: rather than -isEqualToString:. Many pages in category 3, for example, have extensions like .3ssl, .3pm, .3x, etc. These are contained under man3 and we treat them as such.
		NSString *fullPath = [categoryPath stringByAppendingPathComponent:path];
		if ([fm isReadableFileAtPath:fullPath] &&
			([[fullPath pathExtension] hasPrefix:category] || ([[fullPath pathExtension] isEqualToString:@"gz"] && [[[fullPath stringByDeletingPathExtension] pathExtension] hasPrefix:category]))) {
			NSString *basename, *properFilename, *nameWithCategory;
			
			// Add to the list of pages in this category.
			[pages addObject:fullPath];
			
			// Add the object to the basename database.
			if ([[fullPath pathExtension] isEqualToString:@"gz"]) 
				properFilename = [[fullPath lastPathComponent] stringByDeletingPathExtension];
			else 
				properFilename = [fullPath lastPathComponent];
			
			basename = [properFilename stringByDeletingPathExtension];
			nameWithCategory = [basename stringByAppendingPathExtension:category]; // We'll file it under its base name, its parent category name, and its own category name (i.e., basename, basename.3, basename.3pm). 
																				   // Add to the global basename database
			if ([_basenameDatabase objectForKey:basename] == nil)
				[_basenameDatabase setObject:[NSMutableSet setWithObject:fullPath] forKey:basename];
			else
				[[_basenameDatabase objectForKey:basename] addObject:fullPath];
			// Add to the basename database with its own category
			if ([_basenameDatabase objectForKey:properFilename] == nil)
				[_basenameDatabase setObject:[NSMutableSet setWithObject:fullPath] forKey:properFilename];
			else
				[[_basenameDatabase objectForKey:properFilename] addObject:fullPath];
			// Add to the basename database with parent category
			if ([_basenameDatabase objectForKey:nameWithCategory] == nil)
				[_basenameDatabase setObject:[NSMutableSet setWithObject:fullPath] forKey:nameWithCategory];
			else
				[[_basenameDatabase objectForKey:nameWithCategory] addObject:fullPath];
			
		}
	}
	
	[_lock writeLock];
	[_directoryListings setObject:[NSArray arrayWithArray:pages] forKey:categoryPath];
	[pages release];
	[_lock unlock];
}

- (NSArray *)pagesInSection:(NSString *)category
{
	NSArray *ret;
	
	[_lock readLock];
	ret = [NSArray arrayWithArray:[_sectionDatabase objectForKey:category]];
	[_lock unlock];
	
	return ret;
}

- (void)scanPagesInSection:(NSString *)category
{
	NSMutableArray *pages = [[NSMutableArray alloc] init];
		
	for (NSString *path in [self manpaths]) {
		[self scanPagesInSection:category underManpath:path];
		[pages addObjectsFromArray:[self pagesInSection:category underManpath:path]];
	}
	
	[_lock writeLock];
	[_sectionDatabase setObject:[NSArray arrayWithArray:pages] forKey:category];
	[_lock unlock];
		
	[pages release];
}

- (NSArray *)pagesWithName:(NSString *)basename
{
	NSArray *ret;
	
	[_lock readLock];
	ret = [[_basenameDatabase objectForKey:basename] allObjects];
	[_lock unlock];
	
	return ret;
}
		  
- (NSArray *)pagesWithName:(NSString *)basename inSection:(NSString *)category
{
	NSArray *ret;
	
	[_lock readLock];
	ret = [[_basenameDatabase objectForKey:[basename stringByAppendingPathExtension:category]] allObjects];
	[_lock unlock];
	
	return ret;
}

- (void)scanAllPages
{
	for (NSString *section in [self sections]) 
		[self scanPagesInSection:section];
}

- (void)dealloc
{
	[_sections release];
	[_basenameDatabase release];
	[_sectionDatabase release];
	[_directoryListings release];
	[_manpaths release];
	[_lock release];
	[super dealloc];
}

@end
