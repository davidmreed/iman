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
	NSMutableArray *_results;
	NSError *_error;
}

- initWithTerm:(NSString *)term searchType:(NSString *)searchType;

- (NSArray *)results;
- (NSError *)error;

@end
