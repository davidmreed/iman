//
//  iManMakewhatisOperation.m
//  iManEngine
//  Copyright (c) 2004-2010 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import "iManMakewhatisOperation.h"
#import "iManEnginePreferences.h"
#import "NSTask+iManExtensions.h"

@implementation iManMakewhatisOperation

- initWithPath:(NSString *)path
{
	self = [super init];
	
	if (self != nil)
		_path = [path retain];
	
	return self;
}

- (NSError *)error
{
	return _error;
}

- (NSString *)path
{
	return _path;
}

- (void)main
{
	// Call makewhatis -o ~/Application Support/iMan/Indexes/makewhatis.index
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSError *taskError;
	
	if (![[NSFileManager defaultManager] createDirectoryAtPath:[[self path] stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:&taskError]) {
		_error = [taskError retain];
		[pool release];
		return;
	}

	[NSTask invokeTool:@"makewhatis" arguments:[NSArray arrayWithObjects:@"-o", [self path], nil] environment:[NSDictionary dictionaryWithObject:[[iManEnginePreferences sharedInstance] manpathString] forKey:@"MANPATH"] error:&taskError];
	// FIXME: is this locale-aware? That is, how will locale subdirectories be handled? (Also, does man or groff handle rendering manpages in non-UTF-8 encodings *into* UTF-8, for after we fix the parser to handle that encoding?)
	
	[pool release];
}

@end
