//
//  iManIndex.h
//  iManEngine
//  Copyright (c) 2004-2010 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import <Cocoa/Cocoa.h>

@class iManRWLock;

@interface iManIndex : NSObject  
{
	iManRWLock *indexLock_;
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