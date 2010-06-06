//
//  iManFindResult.h
//  iMan
//  Copyright (c) 2004-2010 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import <Cocoa/Cocoa.h>

@class iManPage;

@interface iManFindResult : NSObject {
	NSRange _range;
	NSAttributedString *_source;
	NSAttributedString *_matchWithContext;
	NSString *_match;
}

+ findResultWithRange:(NSRange)range inAttributedString:(NSAttributedString *)string;
- initWithRange:(NSRange)range inAttributedString:(NSAttributedString *)string;

- (NSRange)range;
- (NSString *)match;
- (NSAttributedString *)matchWithContext;

@end
