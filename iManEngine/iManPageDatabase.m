//
//  iManPageDatabase.m
//  iManEngine
//  Copyright (c) 2004-2010 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import "iManPageDatabase.h"
#import <iManEngine/iManEnginePreferences.h>
#import <iManEngine/iManRWLock.h>

@interface iManPageDatabase (Private)

- (void)_scanManpath:(NSString *)manpath;
- (void)_registerPageAtPath:(NSString *)fullPath inSection:(NSString *)section;

@end


@implementation iManPageDatabase

- initWithManpaths:(NSArray *)paths
{
	self = [super init];
	if (self != nil) {
		_manpaths = [paths copy];
		_sectionDatabase = [[NSMutableDictionary alloc] init];
		_basenameDatabase = [[NSMutableDictionary alloc] init];
		_directoryListings = [[NSMutableDictionary alloc] init];
		_sections = [[NSMutableSet alloc] init];
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
		_sections = [[NSMutableSet alloc] init];
		[_sections addObjectsFromArray:[_sectionDatabase allKeys]];
		[self _updateTree];
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
		ret = [[_sections allObjects] copy];
	} else {
		ret = nil;
	}
	[_lock unlock];
	
	return [ret autorelease];
}

- (NSArray *)pagesInSection:(NSString *)category
{
	NSArray *ret;
	
	[_lock readLock];
	ret = [[[_sectionDatabase objectForKey:category] allObjects] copy];
	[_lock unlock];
	
	return [ret autorelease];
}

- (NSArray *)pagesWithName:(NSString *)basename
{
	NSArray *ret;
	
	[_lock readLock];
	ret = [[[_basenameDatabase objectForKey:basename] allObjects] copy];
	[_lock unlock];
	
	return [ret autorelease];
}
		  
- (NSArray *)pagesWithName:(NSString *)basename inSection:(NSString *)category
{
	NSArray *ret;
	
	[_lock readLock];
	ret = [[[_basenameDatabase objectForKey:[basename stringByAppendingPathExtension:category]] allObjects] copy];
	[_lock unlock];
	
	return [ret autorelease];
}

- (void)scanAllPages
{
	for (NSString *path in [self manpaths]) {
		[self _scanManpath:path];
	}
	[self willChangeValueForKey:@"databaseTree"];
	[self _updateTree];
	[self didChangeValueForKey:@"databaseTree"];
}

- (void)_updateTree
{
	NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:[[self sections] count]];
	
	for (NSString *sect in [self sections]) {
		NSArray *pagesInSection = [self pagesInSection:sect];
		NSMutableArray *pageArray = [[NSMutableArray alloc] initWithCapacity:[pagesInSection count]];
		
		for (NSString *pg in pagesInSection) {
			NSString *basename = [pg lastPathComponent];
			
			if ([[basename pathExtension] isEqualToString:@"gz"]) {
				basename = [[basename stringByDeletingPathExtension] stringByDeletingPathExtension];
			} else {
				basename = [basename stringByDeletingPathExtension];
			}

			[pageArray addObject:[NSDictionary dictionaryWithObjectsAndKeys:basename, @"title", pg, @"path", nil]];
		}
		
		[array addObject:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(sect, nil), @"title", [[pageArray copy] autorelease], @"contents", nil]];
		[pageArray release];
	}
	
	[_tree release];
	_tree = [array copy];
	[array release];
}	

- (void)_scanManpath:(NSString *)manpath
{
	NSDirectoryEnumerator *enumerator;
	NSString *fullPath;
	NSFileManager *fm = [NSFileManager defaultManager];
	
	fullPath = [[manpath stringByStandardizingPath] stringByResolvingSymlinksInPath];
	enumerator = [[NSFileManager defaultManager] enumeratorAtPath:fullPath];
		
	for (NSString *subPath in enumerator) {
		NSString *fullSubPath = [[fullPath stringByAppendingPathComponent:subPath] stringByResolvingSymlinksInPath];
		BOOL isDirectory;
		
		if ([fm fileExistsAtPath:fullSubPath isDirectory:&isDirectory] && isDirectory) {
			// We'll create a separate enumerator to descend into this directory.
			[enumerator skipDescendents];
			if ([subPath hasPrefix:@"man"]) {
				NSMutableArray *pages = [[NSMutableArray alloc] init];
				NSDirectoryEnumerator *dir = [fm enumeratorAtPath:fullSubPath];
				NSString *category = [[fullSubPath lastPathComponent] substringFromIndex:3]; // strip off initial "man".
							
				for (NSString *path in dir) {
					// Note use of -hasPrefix: rather than -isEqualToString:. Many pages in category 3, for example, have extensions like .3ssl, .3pm, .3x, etc. These are contained under man3 and we treat them as such.
					NSString *objectFullPath = [fullSubPath stringByAppendingPathComponent:path];
					if ([fm isReadableFileAtPath:objectFullPath] &&
						([[objectFullPath pathExtension] hasPrefix:category] || ([[objectFullPath pathExtension] isEqualToString:@"gz"] && [[[objectFullPath stringByDeletingPathExtension] pathExtension] hasPrefix:category]))) {
						// Add to the list of pages in this category.
						[pages addObject:objectFullPath];
						[self _registerPageAtPath:objectFullPath inSection:category];
					}
				}
				[_lock writeLock];
				[_directoryListings setObject:[NSArray arrayWithArray:pages] forKey:fullSubPath];
				[pages release];
				[_lock unlock];
			}
		}
	}
}

- (void)_registerPageAtPath:(NSString *)fullPath inSection:(NSString *)section 
{
	NSString *basename, *properFilename, *nameWithCategory;
		
	// Add the object to the basename database.
	
	// Delete .gz extension, if any.
	if ([[fullPath pathExtension] isEqualToString:@"gz"]) 
		properFilename = [[fullPath lastPathComponent] stringByDeletingPathExtension];
	else 
		properFilename = [fullPath lastPathComponent];
		
	// We'll file it under its base name, its parent category name, and its own category name (i.e., basename, basename.3, basename.3pm)
	basename = [properFilename stringByDeletingPathExtension];
	nameWithCategory = [basename stringByAppendingPathExtension:section]; 			
	
	[_lock writeLock];
	// Make sure the list of sections contains both the proper section (e.g., 3ssl) and the directory's section (e.g., 3). FIXME: this needs to be stored in the database on disk.
	//[_sections addObject:section];
	[_sections addObject:[properFilename pathExtension]];
	
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
	
	// Add to the section databases for its "proper" section (e.g., 3ssl)
	if ([_sectionDatabase objectForKey:section] == nil)
		[_sectionDatabase setObject:[NSMutableSet setWithObject:fullPath] forKey:section];
	else 
		[[_sectionDatabase objectForKey:section] addObject:fullPath];
	
	[_lock unlock];
}	

- (NSArray *)databaseTree
{	
	return _tree;
}

- (void)dealloc
{
	[_tree release];
	[_sections release];
	[_basenameDatabase release];
	[_sectionDatabase release];
	[_directoryListings release];
	[_manpaths release];
	[_lock release];
	[super dealloc];
}

@end
