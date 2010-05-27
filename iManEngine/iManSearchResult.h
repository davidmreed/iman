//
//  iManSearchResult.h
//  iManEngine
//  Copyright (c) 2004-2010 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
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
