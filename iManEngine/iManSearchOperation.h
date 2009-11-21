//
//  iManSearchOperation.h
//  iManEngine
//
//  Created by David Reed on 11/20/09.
//  Copyright 2009 David Reed. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface iManSearchOperation : NSOperation {
	NSString *_term;
	NSString *_searchType;
	NSMutableDictionary *_results;
}

- initWithTerm:(NSString *)term searchType:(NSString *)searchType;

- (NSDictionary *)results;

@end
