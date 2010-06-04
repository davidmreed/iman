//
//  iManPageCache.h
//  iManEngine
//  Copyright (c) 2004-2010 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import <Cocoa/Cocoa.h>

@class iManPage;

@interface iManPageCache : NSObject {
	NSMutableDictionary *_cache;
}

+ (iManPageCache *)sharedCache;

- (BOOL)isPageCachedWithPath:(NSString *)path;
- (iManPage *)cachedPageWithPath:(NSString *)path;

- (void)cachePage:(iManPage *)page;
- (void)clearCache;
- (void)clearMemoryCache;
- (void)clearDiskCache;

@end
