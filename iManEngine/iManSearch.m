//
// iManSearch.m
// iMan
// Copyright (c) 2006 by David Reed, distributed under the BSD License.
// see iman-macosx.sourceforge.net for details.
//

#import "iManSearch.h"
#import "iManIndex.h"
#import "iManIndex+Private.h"
#import "iManEnginePreferences.h"
#import "DMRTask.h"
#import "DMRTaskQueue.h"
#import "NSTask+iManExtensions.h"

static NSString *const iManSearchTypeApropos = @"apropos";
static NSString *const iManSearchTypeWhatis = @"whatis";

NSString *const iManSearchDidCompleteNotification = @"iManSearchDidCompleteNotification";
NSString *const iManSearchDidFailNotification = @"iManSearchDidFailNotification";
NSString *const iManSearchError = @"iManSearchError";

@interface iManSearch (iManSearchPrivate)

- (void)_search:(id)ignored;

@end

@implementation iManSearch

static DMRTaskQueue *_iManSearchQueue;

+ (void)initialize
{
	_iManSearchQueue = [[DMRTaskQueue alloc] init];
}

+ (NSArray *)searchTypes
{
	return [NSArray arrayWithObjects:iManSearchTypeApropos, iManSearchTypeWhatis, nil];
}

+ (NSString *)localizedNameForSearchType:(NSString *)searchType
{
	return NSLocalizedStringFromTableInBundle(searchType, @"SearchTypes.strings", [NSBundle bundleForClass:self], nil);
}

+ (iManIndex *)indexForSearchType:(NSString *)searchType
{
	if ([searchType isEqualToString:iManSearchTypeApropos] ||
		[searchType isEqualToString:iManSearchTypeWhatis])
		return [iManIndex aproposIndex];

	return nil;
}

+ searchWithTerm:(NSString *)term searchType:(NSString *)searchType
{
	return [[[iManSearch alloc] initWithTerm:term searchType:searchType] autorelease];
}

- initWithTerm:(NSString *)term searchType:(NSString *)searchType
{
	self = [super init];
	
	term_ = [term retain];
	searchType_ = [searchType retain];
	searching_ = NO;
	resultsLock_ = [[NSLock alloc] init];
	results_ = [[NSMutableDictionary alloc] init];
	
	return self;
}

- (NSString *)searchType
{
	return searchType_;
}

- (NSString *)term
{
	return term_;
}

- (void)search
{
	if (!searching_) {
		DMRTask *task = [DMRTask taskWithTarget:self selector:@selector(_search:) object:nil contextInfo:nil];
		
		[task setDelegate:self];
		[_iManSearchQueue addTask:task];
		searching_ = YES;
	}
}

- (void)_search:(id)ignored
{
	iManIndex *aproposIndex = [iManIndex aproposIndex];
    NSData *data;
	NSString *argument;
	NSMutableArray *manpaths = [[[iManEnginePreferences sharedInstance] manpaths] mutableCopy];
	unsigned index;
	char tempDir[] = "/tmp/imanXXXXXXXX";
	NSString *tempLink;
	
	// We'll create a temporary directory with a symlink inside that points to our Application Support index folder. This obviates the need to workaround shell scripts breaking because of the space in "Application Support", or international characters which might or might not exist in the path to that folder.
	if (mkdtemp(&tempDir) == NULL) [NSException raise:NSGenericException format:NSLocalizedStringFromTableInBundle(@"Unable to create temporary index directory.", @"Localizable.strings", [NSBundle bundleForClass:[self class]], nil)];
	tempLink = [[NSString stringWithCString:tempDir] stringByAppendingPathComponent:@"man"];
	if (![[NSFileManager defaultManager] createSymbolicLinkAtPath:tempLink pathContent:[aproposIndex indexPath]])
		[NSException raise:NSGenericException format:NSLocalizedStringFromTableInBundle(@"Unable to create temporary index directory.", @"Localizable.strings", [NSBundle bundleForClass:[self class]], nil)];
	
	// Adjust all manpaths to refer to the index directories inside the symlinked App Support folder.
	for (index = 0; index < [manpaths count]; index++)
		[manpaths replaceObjectAtIndex:index withObject:[tempLink stringByAppendingPathComponent:[manpaths objectAtIndex:index]]];
		
	if ([searchType_ isEqualToString:iManSearchTypeApropos])
		argument = @"-k";
	else 
		argument = @"-f";
	
	if (![[aproposIndex lock] tryLock])
		[NSException raise:NSGenericException format:NSLocalizedStringFromTableInBundle(@"The index is locked. Please make sure that the index is not being modified by any other applications before searching.", @"Localizable.strings", [NSBundle bundleForClass:[self class]], nil)];
	
	data = [NSTask invokeTool:@"man"
					arguments:[NSArray arrayWithObjects:argument, [self term], nil]
				  environment:[NSDictionary dictionaryWithObject:[manpaths componentsJoinedByString:@":"] forKey:@"MANPATH"]];
	[[aproposIndex lock] unlock];
	// The following method does not traverse symbolic links.
	[[NSFileManager defaultManager] removeFileAtPath:tempLink handler:nil];
	
    if (data != nil) {
        NSEnumerator *lines;
        NSString *line;
		
        [resultsLock_ lock];
		[results_ removeAllObjects];
		
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
                    [results_ setObject:desc forKey:pages];
                else
                    [results_ setObject:desc forKey:whichPage];
				
				[whichPage release];
				[desc release];
            }
        }
		
		[resultsLock_ unlock];
    } else {
		[NSException raise:NSGenericException format:NSLocalizedStringFromTableInBundle(@"The search tool returned an error. Try rebuilding the index and searching again, and ensure (if applicable) that your search is a valid regular expression.", @"Localizable.strings", [NSBundle bundleForClass:[self class]], @"Error message displayed when apropos or whatis exits nonzero.")];
	}
}

- (NSDictionary *)results
{
	NSDictionary *results;
	
	[resultsLock_ lock];
	results = [[results_ copy] autorelease];
	[resultsLock_ unlock];
	
	return results;
}

- (void)taskDidComplete:(DMRTask *)task
{
	[[NSNotificationCenter defaultCenter] postNotificationName:iManSearchDidCompleteNotification
														object:self
													  userInfo:nil];
	searching_ = NO;
}

- (void)task:(DMRTask *)task failedWithError:(NSString *)error
{
	[[NSNotificationCenter defaultCenter] postNotificationName:iManSearchDidFailNotification
														object:self
													  userInfo:[NSDictionary dictionaryWithObject:error forKey:iManSearchError]];
	searching_ = NO;
}

- (void)dealloc
{
	[term_ release];
	[searchType_ release];
	[results_ release];
	[resultsLock_ release];
	
	[super dealloc];
}

@end
