//
//  iManSearchResult.h
//  iManEngine
//
//  Created by David Reed on 5/20/10.
//  Copyright 2010 David Reed. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface iManSearchResult : NSObject {
	NSArray *_names;
	NSString *_description;
}

+ searchResultWithPageNames:(NSArray *)names description:(NSString *)description;
- initWithPageNames:(NSArray *)names description:(NSString *)description;

- (NSString *)firstPageName;
- (NSArray *)pageNames;
- (NSString *)description;

@end
