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
#import "iManSearchOperation.h"
#import "NSTask+iManExtensions.h"

NSString *const iManSearchTypeApropos = @"apropos";
NSString *const iManSearchTypeWhatis = @"whatis";

NSString *const iManSearchDidCompleteNotification = @"iManSearchDidCompleteNotification";
NSString *const iManSearchDidFailNotification = @"iManSearchDidFailNotification";
NSString *const iManSearchError = @"iManSearchError";

@interface iManSearch (iManSearchPrivate)

- (void)_search:(id)ignored;

@end

@implementation iManSearch

static NSOperationQueue *_iManSearchQueue;

+ (void)initialize
{
	_iManSearchQueue = [[NSOperationQueue alloc] init];
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
		iManSearchOperation *operation = [[iManSearchOperation alloc] initWithTerm:[self term] searchType:[self searchType]];		
		[operation addObserver:self forKeyPath:@"finished" options:0 context:NULL];
		[_iManSearchQueue addOperation:operation];
		[operation release];
		searching_ = YES;
	}
}


- (NSDictionary *)results
{	
	return results_;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"finished"]) {
		[results_ release];
		results_ = nil;
		searching_ = NO;
		[object removeObserver:self forKeyPath:keyPath];
		if ([object results] != nil) {
			results_ = [[object results] retain];
			[[NSNotificationCenter defaultCenter] postNotificationName:iManSearchDidCompleteNotification
																object:self
															  userInfo:nil];
		} else {
			[[NSNotificationCenter defaultCenter] postNotificationName:iManSearchDidFailNotification
																object:self
															  userInfo:nil];
		}
	}
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
