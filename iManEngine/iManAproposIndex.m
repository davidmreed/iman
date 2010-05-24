//
//  iManAproposIndex.m
//  iManEngine
//  Copyright (c) 2006-2009 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import "iManAproposIndex.h"
#import "iManIndex+Private.h"
#import "iManEnginePreferences.h"
#import "iManMakewhatisOperation.h"
#import "iManRWLock.h"
#import "iManErrors.h"

@implementation iManAproposIndex

- (NSString *)name
{
	return NSLocalizedStringFromTableInBundle(@"Apropos Index (whatis.db)", @"IndexNames", [NSBundle bundleForClass:[self class]], nil);
}

- (NSString *)identifier
{
	return @"org.ktema.iman.index.apropos";
}

- (BOOL)isValid
{	
	return ([[NSFileManager defaultManager] fileExistsAtPath:[[self indexPath] stringByAppendingPathComponent:@"index.valid"] isDirectory:NULL] && [[NSString stringWithContentsOfFile:[[self indexPath] stringByAppendingPathComponent:@"index.valid"] encoding:NSUTF8StringEncoding error:NULL] isEqualToString:[[iManEnginePreferences sharedInstance] manpathString]]);
}	

- (void)update
{
	if ([[self lock] tryWriteLock]) {
		_operation = [[iManMakewhatisOperation alloc] initWithPath:[[self indexPath] stringByAppendingPathComponent:@"whatis"]];
		
		[_operation addObserver:self forKeyPath:@"isFinished" options:0 context:NULL];
		[_iManSearchQueue addOperation:_operation];
	} else {
		[[NSNotificationCenter defaultCenter] postNotificationName:iManIndexDidFailUpdateNotification
															object:self
														  userInfo:[NSDictionary dictionaryWithObject:[NSError errorWithDomain:iManEngineErrorDomain code:iManIndexLockedError userInfo:nil] forKey:iManErrorKey]];
	}
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{	
	// We get this KVO notification on the thread on which the operation has been executing. Annoying. Reroute to main thread.
	if ([keyPath isEqualToString:@"isFinished"]) {
		[self performSelectorOnMainThread:@selector(_handleUpdateIndexFinished:) withObject:object waitUntilDone:NO];
	}
}

- (void)_handleUpdateIndexFinished:(iManMakewhatisOperation *)operation
{
	[[self lock] unlock];
	
	if ([_operation error] == nil) {
		// Create a file to mark the index's validity.
		[[[iManEnginePreferences sharedInstance] manpathString] writeToFile:[[self indexPath] stringByAppendingPathComponent:@"index.valid"] atomically:NO encoding:NSUTF8StringEncoding error:NULL];
		[[NSNotificationCenter defaultCenter] postNotificationName:iManIndexDidUpdateNotification
															object:self];
	} else {
		[[NSNotificationCenter defaultCenter] postNotificationName:iManIndexDidFailUpdateNotification
															object:self
														  userInfo:[NSDictionary dictionaryWithObject:[_operation error] forKey:iManErrorKey]];
	}
	
	[_operation removeObserver:self forKeyPath:@"isFinished"];
	[_operation release];
}

- (void)dealloc
{
	if (_operation != nil) {
		[_operation removeObserver:self forKeyPath:@"isFinished"];
		[_operation release];
	}
	[super dealloc];
}

@end
