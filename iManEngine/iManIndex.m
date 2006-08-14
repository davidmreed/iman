//
// iManIndex.m
// iMan
// Copyright (c) 2006 by David Reed, distributed under the BSD License.
// see iman-macosx.sourceforge.net for details.
//

#import "iManIndex.h"
#import "iManIndex+Private.h"
#import "iManAproposIndex.h"
#import "iManEnginePreferences.h"
#import <unistd.h>
#import <Carbon/Carbon.h>
#import "NSFileManager+DMRFindFolderExtensions.h"


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

	indexLock_ = [[NSDistributedLock alloc] initWithPath:[[self indexPath] stringByAppendingPathComponent:@"index.lock"]];
	
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
		NSString *folder = [[NSFileManager defaultManager] pathForFindFolderSelector:kApplicationSupportFolderType inDomain:kUserDomain createFlag:YES];
		NSMutableArray *pathComponents = [NSMutableArray arrayWithObjects:[[NSBundle bundleForClass:[iManIndex class]] bundleIdentifier], [self identifier], nil];
		BOOL isDir;
		
		while ([pathComponents count] != 0) {
			folder = [folder stringByAppendingPathComponent:[pathComponents objectAtIndex:0]];
			[pathComponents removeObjectAtIndex:0];
			
			if (!([[NSFileManager defaultManager] fileExistsAtPath:folder isDirectory:&isDir] && isDir)) {
				if (![[NSFileManager defaultManager] createDirectoryAtPath:folder attributes:[NSDictionary dictionary]]) {
					NSLog(@"iManIndex: couldn't create directory \"%@\"", folder);
					folder = nil;
					break;
				}
			}
		}
		
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

- (NSDistributedLock *)lock
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
