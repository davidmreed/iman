//
//  iManSearchOperation.m
//  iManEngine
//  Copyright (c) 2004-2010 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import "iManSearchOperation.h"
#import "iManIndex.h"
#import "iManIndex+Private.h"
#import "iManSearch.h"
#import "iManSearchResult.h"
#import "iManErrors.h"
#import "iManEnginePreferences.h"
#import "NSTask+iManExtensions.h"
#import "iManRWLock.h"

@implementation iManSearchOperation

- initWithTerm:(NSString *)term searchType:(NSString *)searchType;
{
	self = [super init];
	
	if (self != nil) {
		_term = [term copy];
		_searchType = [searchType copy];
	}
	
	return self;
}

- (void)main
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	iManIndex *aproposIndex = [iManIndex aproposIndex];
    NSData *data;
	NSString *argument;
	unsigned index;
	char tempDir[] = "/tmp/imanXXXXXXXX";
	NSString *tempLink;
	NSError *taskError;
	
	if (![[aproposIndex lock] tryReadLock]) {
		_error = [[NSError alloc] initWithDomain:iManEngineErrorDomain code:iManIndexLockedError userInfo:nil];
		[pool release];
		return;
	}	
	
	// We'll create a temporary directory with a symlink inside that points to our Application Support index folder. This obviates the need to workaround shell scripts breaking because of the space in "Application Support", or international characters which might or might not exist in the path to that folder.
	if (mkdtemp(tempDir) == NULL) {
		_error = [[NSError alloc] initWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
		[pool release];
		return;
	}
	tempLink = [[[NSFileManager defaultManager] stringWithFileSystemRepresentation:tempDir length:strlen(tempDir)] stringByAppendingPathComponent:@"man"];
	if (![[NSFileManager defaultManager] createSymbolicLinkAtPath:tempLink 
											  withDestinationPath:[aproposIndex indexPath]
															error:&taskError]) {
		_error = [taskError retain];
		rmdir(tempDir);
		[pool release];
		return;
	}		
	
	if ([_searchType isEqualToString:iManSearchTypeApropos])
		argument = @"-k";
	else 
		argument = @"-f";
	
	
	data = [NSTask invokeTool:@"man"
					arguments:[NSArray arrayWithObjects:argument, _term, nil]
				  environment:[NSDictionary dictionaryWithObject:tempLink forKey:@"MANPATH"]
						error:&taskError];
	
	[[aproposIndex lock] unlock];
	// The following method does not traverse symbolic links.
	[[NSFileManager defaultManager] removeFileAtPath:tempLink handler:nil];
	rmdir(tempDir);
	
	if (data != nil) {
		NSEnumerator *lines;
		NSString *line;
					
		_results = [[NSMutableArray alloc] init];
		// Split the output into lines.
		lines = [[[[[NSString alloc] initWithBytes:[data bytes] length:[data length] encoding:[NSString defaultCStringEncoding]] autorelease] componentsSeparatedByString:@"\n"] objectEnumerator];
		while ((line = [lines nextObject]) != nil) {
			// The format of each line is always pageName(n)[, pageName2(n), ...] - description.
			// Let's parse it.
			NSArray *array = [line componentsSeparatedByString:@" - "];
			NSString *whichPage, *desc;
			
			if ([array count] == 2) {
				whichPage = [[array objectAtIndex:0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
				desc = [[array objectAtIndex:1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
				
				// -componentsSeparatedByString returns the whole string if there are no separators.
				[_results addObject:[iManSearchResult searchResultWithPageNames:[whichPage componentsSeparatedByString:@", "] description:desc]];
			}
		}
	} else {
		_error = [taskError retain];
	}

	[pool release];
}

- (NSArray *)results
{
	return [[_results copy] autorelease];
}

- (NSError *)error
{
	return _error;
}

- (void)dealloc
{
	[_error release];
	[_term release];
	[_searchType release];
	[_results release];
	[super dealloc];
}

@end
