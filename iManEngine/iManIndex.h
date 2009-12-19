//
//  iManIndex.h
//  iManEngine
//  Copyright (c) 2006-2009 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import <Cocoa/Cocoa.h>

@interface iManIndex : NSObject  
{
	NSDistributedLock *indexLock_;
}

+ (NSArray *)availableIndexes;

- (NSString *)name;
- (NSString *)identifier;

- (BOOL)isValid;
- (void)update;

@end

@interface iManIndex (iManIndexSingletons)

+ (iManIndex *)aproposIndex;

@end

extern NSString *const iManIndexDidUpdateNotification;
extern NSString *const iManIndexDidFailUpdateNotification;