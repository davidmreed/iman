//
//  iManSearchOperation.h
//  iManEngine
//  Copyright (c) 2009 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import <Cocoa/Cocoa.h>


@interface iManSearchOperation : NSOperation {
	NSString *_term;
	NSString *_searchType;
	NSMutableDictionary *_results;
	NSError *_error;
}

- initWithTerm:(NSString *)term searchType:(NSString *)searchType;

- (NSDictionary *)results;
- (NSError *)error;

@end
