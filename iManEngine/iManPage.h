//
// iManPage.h
// iMan
// Copyright (c) 2006 by David Reed, distributed under the BSD License.
// see iman-macosx.sourceforge.net for details.
//

#import <Cocoa/Cocoa.h>

@interface iManPage : NSObject {
	NSAttributedString *page_;
	NSString *path_;
	NSString *pageName_;
	NSString *pageSection_;
	BOOL resolving_, loading_;
	NSLock *pathLock_, *pageLock_;
}

+ (void)clearCache;

+ pageWithURL:(NSURL *)url;
+ pageWithPath:(NSString *)path;
+ pageWithName:(NSString *)name inSection:(NSString *)section;

- (NSString *)path;
- (NSString *)pageName;
- (NSString *)pageSection;

- (NSAttributedString *)page;
- (NSAttributedString *)pageWithStyle:(NSDictionary *)style;

- (BOOL)isLoaded;
- (BOOL)isLoading;
- (BOOL)isResolved;
- (BOOL)isResolving;

- (void)load;
- (void)reload;
- (void)resolve;

@end

extern NSString *const iManPageLoadDidCompleteNotification;
extern NSString *const iManPageLoadDidFailNotification;
extern NSString *const iManPageResolveDidCompleteNotification;
extern NSString *const iManPageResolveDidFailNotification;
extern NSString *const iManPageError;

extern NSString *const iManPageStyleAttributeName;
extern NSString *const iManPageLinkAttributeName;

extern NSString *const iManPageUnderlineStyle;
extern NSString *const iManPageBoldStyle;
extern NSString *const iManPageDefaultStyle;

extern NSString *const iManPageUnderlineLinks;