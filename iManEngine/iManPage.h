//
//  iManPage.h
//  iManEngine
//  Copyright (c) 2004-2010 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import <Cocoa/Cocoa.h>

@class iManRenderOperation;

@interface iManPage : NSObject {
	NSAttributedString *page_;
	NSString *path_;
	iManRenderOperation *_renderOperation;
}

+ (void)clearCache;

+ pageWithPath:(NSString *)path;
- initWithPath:(NSString *)path;

- (NSString *)path;
- (NSString *)pageName;
- (NSString *)pageSection;

- (NSAttributedString *)page;
- (NSAttributedString *)pageWithStyle:(NSDictionary *)style;

- (BOOL)isLoaded;
- (BOOL)isLoading;

- (void)load;
- (void)reload;

@end

extern NSString *const iManPageLoadDidCompleteNotification;
extern NSString *const iManPageLoadDidFailNotification;
extern NSString *const iManPageError;

extern NSString *const iManPageStyleAttributeName;
extern NSString *const iManPageLinkAttributeName;

extern NSString *const iManPageUnderlineStyle;
extern NSString *const iManPageBoldStyle;
extern NSString *const iManPageBoldUnderlineStyle;
extern NSString *const iManPageDefaultStyle;

extern NSString *const iManPageUnderlineLinks;