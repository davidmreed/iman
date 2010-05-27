//
//  iManRWLock.m
//  iManEngine
//  Copyright (c) 2004-2010 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import "iManRWLock.h"
#import <pthread.h>

@interface iManRWLock (Private)

- (pthread_rwlock_t *)_rwlock;

@end

@implementation iManRWLock

- init
{
	self = [super init];
	if (self) {
		_lock = malloc(sizeof(pthread_rwlock_t));
		if (!((_lock != NULL) && (pthread_rwlock_init([self _rwlock], NULL) == 0))) {
			[self dealloc];
			return nil;
		}
	}
	
	return self;
}

- (pthread_rwlock_t *)_rwlock
{
	return (pthread_rwlock_t *)_lock;
}

- (void)lock
{
	[self readLock];
}

- (void)readLock
{
	pthread_rwlock_rdlock([self _rwlock]);
}

- (BOOL)tryReadLock
{
	return (pthread_rwlock_tryrdlock([self _rwlock]) == 0);
}

- (void)writeLock
{
	pthread_rwlock_wrlock([self _rwlock]);
}

- (BOOL)tryWriteLock
{
	return (pthread_rwlock_trywrlock([self _rwlock]) == 0);
}

- (void)unlock
{
	pthread_rwlock_unlock([self _rwlock]);
}

- (void)dealloc
{
	pthread_rwlock_destroy([self _rwlock]);
	free(_lock);
	_lock = NULL;
	[super dealloc];
}

@end
