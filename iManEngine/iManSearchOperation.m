//
//  iManSearchOperation.m
//  iManEngine
//
//  Created by David Reed on 11/20/09.
//  Copyright 2009 David Reed. All rights reserved.
//

#import "iManSearchOperation.h"
#import "iManIndex.h"
#import "iManIndex+Private.h"
#import "iManSearch.h"
#import "iManEnginePreferences.h"
#import "NSTask+iManExtensions.h"

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
	NSMutableArray *manpaths = [[[iManEnginePreferences sharedInstance] manpaths] mutableCopy];
	unsigned index;
	char tempDir[] = "/tmp/imanXXXXXXXX";
	NSString *tempLink;
	
	@try {
	
		// We'll create a temporary directory with a symlink inside that points to our Application Support index folder. This obviates the need to workaround shell scripts breaking because of the space in "Application Support", or international characters which might or might not exist in the path to that folder.
		if (mkdtemp(&tempDir) == NULL) [NSException raise:NSGenericException format:NSLocalizedStringFromTableInBundle(@"Unable to create temporary index directory.", @"Localizable.strings", [NSBundle bundleForClass:[self class]], nil)];
		tempLink = [[NSString stringWithCString:tempDir] stringByAppendingPathComponent:@"man"];
		if (![[NSFileManager defaultManager] createSymbolicLinkAtPath:tempLink pathContent:[aproposIndex indexPath]])
			[NSException raise:NSGenericException format:NSLocalizedStringFromTableInBundle(@"Unable to create temporary index directory.", @"Localizable.strings", [NSBundle bundleForClass:[self class]], nil)];
		
		// Adjust all manpaths to refer to the index directories inside the symlinked App Support folder.
		for (index = 0; index < [manpaths count]; index++)
			[manpaths replaceObjectAtIndex:index withObject:[tempLink stringByAppendingPathComponent:[manpaths objectAtIndex:index]]];
		
		if ([_searchType isEqualToString:iManSearchTypeApropos])
			argument = @"-k";
		else 
			argument = @"-f";
		
		if (![[aproposIndex lock] tryLock])
			[NSException raise:NSGenericException format:NSLocalizedStringFromTableInBundle(@"The index is locked. Please make sure that the index is not being modified by any other applications before searching.", @"Localizable.strings", [NSBundle bundleForClass:[self class]], nil)];
		
		data = [NSTask invokeTool:@"man"
						arguments:[NSArray arrayWithObjects:argument, _term, nil]
					  environment:[NSDictionary dictionaryWithObject:[manpaths componentsJoinedByString:@":"] forKey:@"MANPATH"]];
		[[aproposIndex lock] unlock];
		// The following method does not traverse symbolic links.
		[[NSFileManager defaultManager] removeFileAtPath:tempLink handler:nil];
		
		if (data != nil) {
			NSEnumerator *lines;
			NSString *line;
						
			_results = [[NSMutableDictionary alloc] init];
			// Split the output into lines.
			lines = [[[NSString stringWithCString:[data bytes] length:[data length]] componentsSeparatedByString:@"\n"] objectEnumerator];
			while ((line = [lines nextObject]) != nil) {
				// The format of each line is always pageName(n)[, pageName2(n), ...] - description.
				// Let's parse it.
				NSArray *array = [line componentsSeparatedByString:@" - "];
				NSArray *pages;
				NSMutableString *whichPage, *desc;
				
				if ([array count] == 2) {
					whichPage = [[array objectAtIndex:0] mutableCopy];
					CFStringTrimWhitespace((CFMutableStringRef)whichPage);
					desc = [[array objectAtIndex:1] mutableCopy];
					CFStringTrimWhitespace((CFMutableStringRef)desc);
					
					// Check for multiple pages returned.
					pages = [whichPage componentsSeparatedByString:@", "];
					
					// If multiple pages, use an array as the key and description as value.
					// Otherwise, just use the page name as the key.
					// Must remember to release the strings from -mutableCopy.
					if ([pages count] > 1) 
						[_results setObject:desc forKey:pages];
					else
						[_results setObject:desc forKey:whichPage];
					
					[whichPage release];
					[desc release];
				}
			}
		} else {
			[NSException raise:NSGenericException format:NSLocalizedStringFromTableInBundle(@"The search tool returned an error. Try rebuilding the index and searching again, and ensure (if applicable) that your search is a valid regular expression.", @"Localizable.strings", [NSBundle bundleForClass:[self class]], @"Error message displayed when apropos or whatis exits nonzero.")];
		}
	} 
	@catch (id e) {
		NSLog(@"An error occurred while searching.");
	}
	@finally {
		[pool release];
	}
}

- (NSDictionary *)results
{
	return [[_results copy] autorelease];
}

- (void)dealloc
{
	[_term release];
	[_searchType release];
	[_results release];
	[super dealloc];
}

@end
