//
//  iManResolveOperation.m
//  iManEngine
//  Copyright (c) 2009 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import "iManResolveOperation.h"
#import "iManErrors.h"
#import "iManEnginePreferences.h"
#import "NSTask+iManExtensions.h"

@implementation iManResolveOperation

- initWithName:(NSString *)name section:(NSString *)section
{
	self = [super init];
	
	if (self != nil) {
		_name = [name copy];
		_section = [section copy];
		_path = nil;
		_error = nil;
	}
	
	return self;
}

- (NSString *)path
{
	if ([self isFinished])
		return _path;
	
	return nil;
}

- (NSError *)error 
{
	return _error;
}

- (void)main
{
	// Calls man -w section page, via our NSTask category, to get the filename to load.
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSArray *args;
	NSString *manpath = [[iManEnginePreferences sharedInstance] manpathString];
    NSData *ret;
	NSError *taskError;

	if ((manpath == nil) || ([manpath length] == 0)) {
		_error = [[NSError alloc] initWithDomain:iManEngineErrorDomain code:iManToolNotConfiguredError userInfo:nil];
		[pool release];
		return;
	}
	
    // Set up the arguments based on whether or not the section is known.
    if (_section == nil) {
        args = [NSArray arrayWithObjects:
				@"-M",
				manpath,
				@"-w",
				_name,
				nil];
    } else {
        args = [NSArray arrayWithObjects:
				@"-M",
				manpath,
				@"-w",
				_section,
				_name,
				nil];
    }
    ret = [NSTask invokeTool:@"man" arguments:args environment:nil error:&taskError];
	
    // the data returned has a newline at the end, so if we got some data,
    // convert it to an NSString, omitting the newline, and make sure it's an OK path.
    if (ret != nil) {
		NSString *string = [[[NSString alloc] initWithBytes:[ret bytes] length:[ret length] - 1 encoding:[NSString defaultCStringEncoding]] autorelease];
		string = [string stringByStandardizingPath];
		_path = [string retain];
	} else {
		_error = [taskError retain];
	}
	
	[pool release];
}

- (void)dealloc
{
	[_path release];
	[_section release];
	[_name release];
	[_error release];
	[super dealloc];
}

@end
