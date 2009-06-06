//
// iManAproposIndex.m
// iMan
// Copyright (c) 2006 by David Reed, distributed under the BSD License.
// see iman-macosx.sourceforge.net for details.
//

#import "iManAproposIndex.h"
#import "iManIndex+Private.h"
#import "iManEnginePreferences.h"

@implementation iManAproposIndex

- (NSString *)name
{
	return NSLocalizedStringFromTableInBundle(@"Apropos Index (whatis.db)", @"IndexNames.strings", [NSBundle bundleForClass:[self class]], nil);
}

- (NSString *)identifier
{
	return @"org.ktema.iman.iman-macosx.index.apropos";
}

- (BOOL)isValid
{	
	return ([[NSFileManager defaultManager] fileExistsAtPath:[[self indexPath] stringByAppendingPathComponent:@"index.valid"] isDirectory:NULL]);
}	

- (void)update
{
	if ([[self lock] tryLock]) {
		[[NSDistributedNotificationCenter defaultCenter] addObserver:self
															selector:@selector(_updateIndexesCompleted:)
																name:@"org.ktema.iman.iman-macosx.imanengine.makewhatis"
															  object:nil
												  suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];	
		
		
		[NSThread detachNewThreadSelector:@selector(_update:) toTarget:self withObject:[self indexPath]];
	} else {
		[[NSNotificationCenter defaultCenter] postNotificationName:iManIndexDidFailUpdateNotification
															object:self];
	}
}

- (void)_update:(NSString *)indexPath
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSArray *manPaths = [[iManEnginePreferences sharedInstance] manpaths];
	NSEnumerator *pathEnumerator = [manPaths objectEnumerator];
	NSString *path;
		
	@try {
		if (indexPath == nil) 
			[NSException raise:NSGenericException format:@""];
		
		while ((path = [pathEnumerator nextObject]) != nil) {
			NSString *whatisDBPath = [[[indexPath stringByAppendingPathComponent:path] stringByAppendingPathComponent:@"whatis"] stringByStandardizingPath];
			NSTask *task = [[[NSTask alloc] init] autorelease];
			
			{ // Ensure the directory exists so makewhatis won't complain
				NSString *folder = @"";
				NSMutableArray *pathComponents = [[[whatisDBPath stringByDeletingLastPathComponent] pathComponents] mutableCopy];
				BOOL isDir;
				
				while ([pathComponents count] != 0) {
					folder = [folder stringByAppendingPathComponent:[pathComponents objectAtIndex:0]];
					[pathComponents removeObjectAtIndex:0];
					
					if (!([[NSFileManager defaultManager] fileExistsAtPath:folder isDirectory:&isDir] && isDir)) {
						if (![[NSFileManager defaultManager] createDirectoryAtPath:folder attributes:[NSDictionary dictionary]]) {
							NSLog(@"iManAproposIndex: couldn't create directory \"%@\"", folder);
							folder = nil;
							break;
						}
					}
				}
				
				[pathComponents release];
			}
			
			[task setLaunchPath:[[iManEnginePreferences sharedInstance] pathForTool:@"makewhatis"]];
			[task setArguments:[NSArray arrayWithObjects:@"-o", whatisDBPath, path, nil]]; // FIXME: is this locale-aware? That is, how will locale subdirectories be handled? (Also, does man or groff handle rendering manpages in non-UTF-8 encodings *into* UTF-8, for after we fix the parser to handle that encoding?)
			
			[task launch];
			[task waitUntilExit];
			if ([task terminationStatus] != 0)
				[NSException raise:NSGenericException format:@""];
		}
	} @catch (NSException *e) {
		[[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"org.ktema.iman.iman-macosx.imanengine.makewhatis" object:@"1"];
	}
	
	// This will make -valid return YES.
	[@"1" writeToFile:[[self indexPath] stringByAppendingPathComponent:@"index.valid"] atomically:YES];

	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"org.ktema.iman.iman-macosx.imanengine.makewhatis" object:@"0"];
	
	[pool release];
}

- (void)_updateIndexesCompleted:(NSNotification *)notification
{
	[[self lock] unlock];
	
	// The other thread returns success/fail in the notification's object.
	if ([[notification object] intValue] == 0)
		[[NSNotificationCenter defaultCenter] postNotificationName:iManIndexDidUpdateNotification
															object:self];
	else
		[[NSNotificationCenter defaultCenter] postNotificationName:iManIndexDidFailUpdateNotification
															object:self];
	
	[[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
}

@end
