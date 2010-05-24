//
//  iManSearch.m
//  iManEngine
//  Copyright (c) 2006-2009 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import "iManSearch.h"
#import "iManIndex.h"
#import "iManIndex+Private.h"
#import "iManEnginePreferences.h"
#import "iManSearchOperation.h"
#import "NSTask+iManExtensions.h"
#import "iManErrors.h"

NSString *const iManSearchTypeApropos = @"apropos";
NSString *const iManSearchTypeWhatis = @"whatis";

NSString *const iManSearchDidCompleteNotification = @"iManSearchDidCompleteNotification";
NSString *const iManSearchDidFailNotification = @"iManSearchDidFailNotification";

NSOperationQueue *_iManSearchQueue;

@interface iManSearch (iManSearchPrivate)

- (void)_searchDidFinish:(iManSearchOperation *)operation;

@end

@implementation iManSearch

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
	return NSLocalizedStringFromTableInBundle(searchType, @"SearchTypes", [NSBundle bundleForClass:self], nil);
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
	operation_ = nil;
	resultsLock_ = [[NSLock alloc] init];
	results_ = [[NSArray alloc] init];
	
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
	if (![self isSearching]) {
		operation_ = [[iManSearchOperation alloc] initWithTerm:[self term] searchType:[self searchType]];		
		[operation_ addObserver:self forKeyPath:@"isFinished" options:0 context:NULL];
		[_iManSearchQueue addOperation:operation_];
	}
}

- (BOOL)isSearching
{
	return (operation_ != nil);
}

- (NSArray *)results
{	
	return results_;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	// This notification isn't necessarily coming in on the main thread (in fact, it shouldn't be), so bounce it there to get the results and notify our client objects.
	if ([keyPath isEqualToString:@"isFinished"] && (object == operation_)) {
		[self performSelectorOnMainThread:@selector(_searchDidFinish:) withObject:object waitUntilDone:NO];
	}
}

- (void)_searchDidFinish:(iManSearchOperation *)operation 
{
	[self willChangeValueForKey:@"results"];
	[results_ release];
	results_ = nil;
	
	if ([operation results] != nil) {
		results_ = [[operation results] retain];
		[[NSNotificationCenter defaultCenter] postNotificationName:iManSearchDidCompleteNotification
															object:self
														  userInfo:nil];
	} else {
		[[NSNotificationCenter defaultCenter] postNotificationName:iManSearchDidFailNotification
															object:self
														  userInfo:[NSDictionary dictionaryWithObject:[operation error] forKey:iManErrorKey]];
	}
	// Remove ourself as an observer and release our reference to the operation.
	[operation_ removeObserver:self forKeyPath:@"isFinished"];
	[operation_ release];
	operation_ = nil;
	[self didChangeValueForKey:@"results"];	
}	

- (void)dealloc
{
	// Occasionally when several search operations are initiated by the same document very quickly, we get deallocated before our search operation finishes. Make sure we are removed as an observer.  FIXME: make our operations killable.
	if (operation_ != nil) {
		[operation_ removeObserver:self forKeyPath:@"isFinished"];
		[operation_ release];
	}
	[term_ release];
	[searchType_ release];
	[results_ release];
	[resultsLock_ release];
	
	[super dealloc];
}

@end
