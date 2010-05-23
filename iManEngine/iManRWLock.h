//
//  iManRWLock.h
//  iManEngine
//
//  Created by David Reed on 5/23/10.
//  Copyright 2010 David Reed. All rights reserved.
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
