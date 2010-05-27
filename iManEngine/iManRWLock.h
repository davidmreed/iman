//
//  iManRWLock.h
//  iManEngine
//  Copyright (c) 2004-2010 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import <Cocoa/Cocoa.h>


@interface iManRWLock : NSObject <NSLocking> {
	void *_lock; // pthread_rwlock_t *
}

- (void)lock;
- (void)readLock;
- (BOOL)tryReadLock;
- (void)writeLock;
- (BOOL)tryWriteLock;

- (void)unlock;

@end
