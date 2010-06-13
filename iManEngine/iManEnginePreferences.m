//
//  iManEnginePreferences.m
//  iManEngine
//  Copyright (c) 2004-2010 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import "iManEnginePreferences.h"

@implementation iManEnginePreferences

static NSDictionary *_pathDictionary;

NSString *const iManEngineManpaths = @"org.ktema.iman.imanengine:MANPATH";
NSString *const iManEngineToolPathMan = @"org.ktema.iman.imanengine:Path:man";
NSString *const iManEngineToolPathGroff = @"org.ktema.iman.imanengine:Path:groff";
NSString *const iManEngineToolPathMakewhatis = @"org.ktema.iman.imanengine:Path:makewhatis";
NSString *const iManEngineUseDiskCache = @"org.ktema.iman.imanengine:UseDiskCache";
NSString *const iManEngineUseMemoryCache = @"org.ktema.iman.imanengine:UseMemCache";

+ (void)initialize
{
    _pathDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:
        @"/usr/bin/man", @"man",
        @"/usr/bin/groff", @"groff",
		@"/usr/libexec/makewhatis", @"makewhatis",
        nil];
	
	[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
			[NSArray arrayWithObjects:@"/usr/share/man", @"/usr/local/share/man", @"/usr/local/man", @"/usr/X11/man", @"/usr/X11R6/man", @"/sw/share/man", @"/Developer/usr/share/man", nil], iManEngineManpaths,
			@"/usr/bin/man", iManEngineToolPathMan,
			@"/usr/bin/groff", iManEngineToolPathGroff,
			@"/usr/libexec/makewhatis", iManEngineToolPathMakewhatis,
			[NSNumber numberWithBool:YES], iManEngineUseDiskCache,
			[NSNumber numberWithBool:YES], iManEngineUseMemoryCache,
															 nil]];
}

+ sharedInstance
{
	static iManEnginePreferences *_sharedInstance = nil;

	if (_sharedInstance == nil)
		_sharedInstance = [[iManEnginePreferences alloc] init];
	
	return _sharedInstance;
}

- (NSArray *)tools
{
	return [_pathDictionary allKeys];
}

- (NSString *)pathForTool:(NSString *)tool
{
    NSString *path = [[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"org.ktema.iman.imanengine:Path:%@", tool]];
	
    if (![[NSFileManager defaultManager] isExecutableFileAtPath:path])
        path = [_pathDictionary objectForKey:tool];
	
    if (![[NSFileManager defaultManager] isExecutableFileAtPath:path])
        return nil;
	
    return path;
}

- (void)setPath:(NSString *)path forTool:(NSString *)tool
{
	if ([_pathDictionary objectForKey:tool] != nil) {
		[[NSUserDefaults standardUserDefaults] setObject:path forKey:[NSString stringWithFormat:@"org.ktema.iman.imanengine:Path:%@", tool]];
	}
}

- (NSArray *)manpaths
{	
	return [[NSUserDefaults standardUserDefaults] objectForKey:iManEngineManpaths];
}	

- (void)setManpaths:(NSArray *)manpaths
{
	[[NSUserDefaults standardUserDefaults] setObject:manpaths forKey:iManEngineManpaths];
}

- (NSString *)manpathString
{
	return [[self manpaths] componentsJoinedByString:@":"];
}

- (BOOL)useDiskCache
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:iManEngineUseDiskCache];
}

- (void)setUseDiskCache:(BOOL)diskCache
{
	[[NSUserDefaults standardUserDefaults] setBool:diskCache forKey:iManEngineUseDiskCache];
}

- (BOOL)useMemoryCache
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:iManEngineUseMemoryCache];
}

- (void)setUseMemoryCache:(BOOL)memCache
{
	[[NSUserDefaults standardUserDefaults] setBool:memCache forKey:iManEngineUseMemoryCache];
}

@end
