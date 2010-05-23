//
//  iManSearch.h
//  iManEngine
//  Copyright (c) 2006-2009 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import <Cocoa/Cocoa.h>

@class iManIndex, iManSearchOperation;

/*!
 @class iManSearch
 @abstract Abstract man page search class.
 @discussion iManSearch presents an abstract interface to the man page search facilities, currently apropos(1) and whatis(1). All searching is done asynchronously; results are conveyed via notifications.
 
 iManSearch supplies a method, +searchTypes, which returns an array containing the identifiers of the types of search currently implemented by the class. Currently, only apropos and whatis searches are supported. SearchKit functionality may be added in a later release. The search type constants are used when initializing an iManSearch instance, and can also be used to get a localized name (+localizedNameForSearchType:) and an iManIndex instance (+indexForSearchType:).
 
 Results are returned in an NSDictionary (-results). The keys of this dictionary are either names or arrays of names (some manpages document more than one command) and the associated values are the pages' descriptions.
 */

@interface iManSearch : NSObject {
	NSString *term_;
	NSString *searchType_;
	NSArray *results_;
	BOOL searching_;
	iManSearchOperation *operation_;
	NSLock *resultsLock_;
}

/*!
 @method searchTypes
 @abstract Returns an array of string constants representing the known search types (at present, apropos and whatis).
 */
+ (NSArray *)searchTypes;
/*!
 @method localizedNameForSearchType:
 @abstract Returns the localized, user-presentable name of the supplied search type.
 */
+ (NSString *)localizedNameForSearchType:(NSString *)searchType;
/*!
 @method indexForSearchType:
 @abstract Returns the iManIndex object representing the supplied search's index.
 */
+ (iManIndex *)indexForSearchType:(NSString *)searchType;

/*!
 @method searchWithTerm:searchType:
 @abstract Initializes the search object to search for term via searchType; returns autoreleased object.
 */
+ searchWithTerm:(NSString *)term searchType:(NSString *)searchType;
/*!
 @method initWithTerm:searchType:
 @abstract Initializes the search object to search for term via searchType.
 */
- initWithTerm:(NSString *)term searchType:(NSString *)searchType;

/*!
 @method searchType
 @abstract Returns the receiver's search type (not localized).
 */
- (NSString *)searchType;
/*!
 @method term
 @abstract Returns the receiver's search term.
 */
- (NSString *)term;

/*!
 @method search
 @abstract Initiates the asynchronous search operation.
 @discussion This method will return immediately; you will be notified via notifications when the operation is complete. Once the iManSearchDidComplete notification is posted, results are available via -results.
 */
- (void)search;

/*!
 @method results
 @abstract Returns the results of the asynchronous search.
 @discussion Returns an array of iManSearchResult objects.
 */
- (NSArray *)results;

@end

extern NSString *const iManSearchDidCompleteNotification;
extern NSString *const iManSearchDidFailNotification;
extern NSString *const iManSearchError;

extern NSString *const iManSearchTypeApropos;
extern NSString *const iManSearchTypeWhatis;
