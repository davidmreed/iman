//
//  iManResolveOperation.m
//  iManEngine
//
//  Created by David Reed on 11/20/09.
//  Copyright 2009 David Reed. All rights reserved.
//

#import "iManResolveOperation.h"
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
	}
	
	return self;
}

- (NSString *)path
{
	if ([self isFinished])
		return _path;
	
	return nil;
}

- (void)main
{
	// Calls man -w section page, via our NSTask category, to get the filename to load.
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSArray *args;
	NSString *manpath = [[iManEnginePreferences sharedInstance] manpathString];
    NSData *ret;

	// FIXME: find a better way to report errors.
	if ((manpath == nil) || ([manpath length] == 0))
		[NSException raise:NSGenericException format:@"No manpaths configured."];
	
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
    ret = [NSTask invokeTool:@"man" arguments:args environment:nil];
	
    // the data returned has a newline at the end, so if we got some data,
    // convert it to an NSString, omitting the newline, and make sure it's an OK path.
    if (ret != nil) {
		_path = [[[NSString stringWithCString:[ret bytes] length:([ret length] - 1)] stringByStandardizingPath] retain];
	} 
	
	[pool release];
}

- (void)dealloc
{
	[_path release];
	[_section release];
	[_name release];
	[super dealloc];
}

@end
