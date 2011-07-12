//
//  iManIndex.m
//  iManEngine
//  Copyright (c) 2004-2010 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import "iManIndex.h"
#import "iManIndex+Private.h"
#import "iManAproposIndex.h"
#import "iManEnginePreferences.h"
#import "iManRWLock.h"

@implementation iManIndex

+ (NSArray *)availableIndexes
{
	return [NSArray arrayWithObject:[self aproposIndex]];
}

+ (iManIndex *)aproposIndex
{
	static iManAproposIndex *index;
	
	if (index == nil)
		index = [[iManAproposIndex alloc] init];
	
	return (iManIndex *)index;
}

- init
{
	self = [super init];

	indexLock_ = [[iManRWLock alloc] init];
	
	return self;
}

- (NSString *)name
{
	return @"";
}

- (NSString *)identifier
{
	return @"";
}

- (NSString *)indexPath
{
	if ([[self class] isSubclassOfClass:[iManIndex class]]) {
		NSString *folder;
		NSArray *pathComponents;
		BOOL isDir;

		// Store index in ~/Library/Application Support/org.ktema.iman.imanengine/[application bundle ID]/[index ID].
		// We don't lock across apps and different apps (assuming any app other than iMan ever uses the engine) may have different manpaths, so indices need to be application-local.
		pathComponents = [NSArray arrayWithObjects:[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject], [[NSBundle bundleForClass:[iManIndex class]] bundleIdentifier], [[NSBundle mainBundle] bundleIdentifier], [self identifier], nil];
		
		folder = [NSString pathWithComponents:pathComponents];

		if ([[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil])
			return folder;
	}
	
	return nil;
}

- (BOOL)isValid
{
	return YES;
}

- (void)update
{
}

- (iManRWLock *)lock
{
	return indexLock_;
}

- (void)dealloc
{
	[indexLock_ release];
	[super dealloc];
}

@end

NSString *const iManIndexDidUpdateNotification = @"iManIndexDidUpdateNotification";
NSString *const iManIndexDidFailUpdateNotification = @"iManIndexDidFailUpdateNotification";
