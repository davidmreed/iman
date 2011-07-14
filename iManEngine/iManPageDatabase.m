//
//  iManPageDatabase.m
//  iManEngine
//  Copyright (c) 2004-2010 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import "iManPageDatabase.h"
#import "iManSection.h"
#import <iManEngine/iManEnginePreferences.h>
#import <iManEngine/iManRWLock.h>

@interface iManPageDatabase (Private)

- (void)_scanManpath:(NSString *)manpath;
- (void)_registerPageAtPath:(NSString *)fullPath inSection:(NSString *)section;

@end

static NSInteger kCurrentDatabaseVersion = 4;

@implementation iManPageDatabase

- initWithManpaths:(NSArray *)paths
{
	self = [super init];
	if (self != nil) {
		_manpaths = [paths copy];
		_basenameDatabase = [[NSMutableDictionary alloc] init];
		_sectionDatabase = [[NSMutableDictionary alloc] init];
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
			if ([coder decodeIntegerForKey:@"Version"] != kCurrentDatabaseVersion) {
				_basenameDatabase = [[coder decodeObjectForKey:@"BasenameDatabase"] retain];
				_manpaths = [[coder decodeObjectForKey:@"Manpaths"] retain];
				_sectionDatabase = [[coder decodeObjectForKey:@"SectionDatabase"] retain];
				_sections = [[coder decodeObjectForKey:@"Sections"] retain];
			} else {
				[self dealloc];
				return nil;
			}
		} else {
			[self dealloc];
			return nil;
		}
	}
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[_lock readLock];
	if ([coder allowsKeyedCoding]) {
		[coder encodeInteger:kCurrentDatabaseVersion forKey:@"Version"];
		[coder encodeObject:_basenameDatabase forKey:@"BasenameDatabase"];
		[coder encodeObject:_manpaths forKey:@"Manpaths"];
		[coder encodeObject:_sectionDatabase forKey:@"SectionDatabase"];
		[coder encodeObject:_sections forKey:@"Sections"];
	} else {
		[NSException raise:NSInternalInconsistencyException format:@"iManPageDatabase does not support non-keyed archiving."];
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
	ret = [[_sections allObjects] copy];
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
}	

- (void)_scanManpath:(NSString *)manpath
{
	NSDirectoryEnumerator *enumerator;
	NSString *fullPath;
	NSFileManager *fm = [NSFileManager defaultManager];
	
	fullPath = [[manpath stringByStandardizingPath] stringByResolvingSymlinksInPath];
	enumerator = [fm enumeratorAtPath:fullPath];
	@try {
		for (NSString *subPath in enumerator) {
			NSString *fullSubPath = [[fullPath stringByAppendingPathComponent:subPath] stringByResolvingSymlinksInPath];
			BOOL isDirectory;
			
			if ([fm fileExistsAtPath:fullSubPath isDirectory:&isDirectory] && isDirectory) {
				// We'll create a separate enumerator to descend into this directory.
				[enumerator skipDescendents];
				if ([subPath hasPrefix:@"man"]) {
					// This is a section directory.
					NSMutableArray *pages = [[NSMutableArray alloc] init];
					NSDirectoryEnumerator *dir = [fm enumeratorAtPath:fullSubPath];
					NSString *category = [[fullSubPath lastPathComponent] substringFromIndex:3]; // strip off initial "man".
								
					for (NSString *path in dir) {
						NSString *objectFullPath = [fullSubPath stringByAppendingPathComponent:path];
						NSString *realExtension;
						iManSection *section;
						
						if ([[objectFullPath pathExtension] isEqualToString:@"gz"]) {
							realExtension = [[objectFullPath stringByDeletingPathExtension] pathExtension];
						} else {
							realExtension = [objectFullPath pathExtension];
						}

						// Check to see if this page belongs in this category or in a subcategory.
						[_lock writeLock];
						section = [_sectionDatabase objectForKey:realExtension];
						if (section != nil) {
							[[section mutableArrayValueForKey:@"pages"] addObject:objectFullPath];
							[self _registerPageAtPath:objectFullPath inSection:category];
						} else {
							iManSection *mainSection = [_sectionDatabase objectForKey:category];
							
							if (mainSection == nil) {
								mainSection = [[iManSection alloc] initWithName:category];
								[self willChangeValueForKey:@"sections"];
								[_sections addObject:mainSection];
								[_sectionDatabase setObject:mainSection forKey:category];
								[self didChangeValueForKey:@"sections"];
								[mainSection autorelease];
							}
							
							if ([realExtension isEqualToString:category]) {
								[[mainSection mutableArrayValueForKey:@"pages"] addObject:objectFullPath];
							} else {
								iManSection *subsection = [[iManSection alloc] initWithName:realExtension];
								[[mainSection mutableArrayValueForKey:@"subsections"] addObject:subsection];
								[[subsection mutableArrayValueForKey:@"pages"] addObject:objectFullPath];
								[_sectionDatabase setObject:subsection forKey:subsection.name];
							}
							[self _registerPageAtPath:objectFullPath inSection:category];
						}
						[_lock unlock];
					}
				}
			}
		}
	} @catch (id e) {
		NSLog(@"Exception occurred while scanning directory %@. Error was %@", manpath, e);
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
		
	[_lock unlock];
}	

- (void)dealloc
{
	[_basenameDatabase release];
	[_sectionDatabase release];
	[_manpaths release];
	[_sections release];
	[_lock release];
	[super dealloc];
}

@end
