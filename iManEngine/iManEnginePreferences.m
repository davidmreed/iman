//
//  iManEnginePreferences.m
//  iManEngine
//  Copyright (c) 2004-2010 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import "iManEnginePreferences.h"
#import "NSTask+iManExtensions.h"

@interface iManEnginePreferences (EnginePreferencesPrivate)

- (NSMutableDictionary *)_enginePreferences;
- (void)_setEnginePreferences:(NSDictionary *)enginePreferences;

@end

@implementation iManEnginePreferences

static iManEnginePreferences *_sharedInstance;
static NSDictionary *_pathDictionary;
static NSLock *_prefsLock;

static NSString *const iManEngineBundleIdentifier = @"org.ktema.iman.imanengine";
static NSString *const iManEnginePathDictionary = @"iManEnginePathDictionary";
static NSString *const iManEngineManpaths = @"iManEngineManpaths";

+ (void)initialize
{
	NSArray *manpaths = [NSArray arrayWithObjects:@"/usr/share/man", @"/usr/local/share/man", @"/usr/X11/man", @"/usr/X11R6/man", @"/sw/share/man", @"/Developer/usr/share/man", nil];
    _pathDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:
        @"/usr/bin/man", @"man",
        @"/usr/bin/groff", @"groff",
		@"/usr/bin/manpath", @"manpath",
		@"/usr/libexec/makewhatis", @"makewhatis",
        nil];
	_prefsLock = [[NSLock alloc] init];
	
	[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObject:[NSDictionary dictionaryWithObjectsAndKeys:_pathDictionary, iManEnginePathDictionary, manpaths, iManEngineManpaths, nil] forKey:iManEngineBundleIdentifier]];
}

+ sharedInstance
{
	if (_sharedInstance == nil)
		_sharedInstance = [[iManEnginePreferences alloc] init];
	
	return _sharedInstance;
}

- (NSMutableDictionary *)_enginePreferences
{
	return [[[[NSUserDefaults standardUserDefaults] objectForKey:iManEngineBundleIdentifier] mutableCopy] autorelease];
}

- (void)_setEnginePreferences:(NSDictionary *)enginePreferences
{
	[[NSUserDefaults standardUserDefaults] setObject:enginePreferences forKey:iManEngineBundleIdentifier];
}

- (NSArray *)tools
{
	return [_pathDictionary allKeys];
}

- (NSString *)pathForTool:(NSString *)tool
{
    NSString *path = nil;
	id loadedPathDictionary = nil;
	
    [_prefsLock lock];
	loadedPathDictionary = [[self _enginePreferences] objectForKey:iManEnginePathDictionary];
	path = [[loadedPathDictionary objectForKey:tool] retain];
    [_prefsLock unlock];
    
    if ((path == nil) || (![[NSFileManager defaultManager] isExecutableFileAtPath:path]))
        path = [[_pathDictionary objectForKey:tool] retain];
	
    if ((path == nil) || (![[NSFileManager defaultManager] isExecutableFileAtPath:path]))
        return nil;
	
    return [path autorelease];
}

- (void)setPath:(NSString *)path forTool:(NSString *)tool
{
	NSMutableDictionary *prefs;
	NSMutableDictionary *pathDict;
	
    [_prefsLock lock];
	prefs = [self _enginePreferences];
	pathDict = [[prefs objectForKey:iManEnginePathDictionary] mutableCopy];
	[pathDict setObject:path forKey:tool];
	[prefs setObject:pathDict forKey:iManEnginePathDictionary];
	[self _setEnginePreferences:prefs];
	[pathDict release];
    [_prefsLock unlock];
}

- (NSArray *)manpaths
{
	NSArray *ret;
	NSData *dat;
	NSString * string;
	
	[_prefsLock lock];
	ret = [[[NSUserDefaults standardUserDefaults] objectForKey:iManEngineBundleIdentifier] objectForKey:iManEngineManpaths];
	[_prefsLock unlock];

	return ret;
}	

- (void)setManpaths:(NSArray *)manpaths
{
	NSMutableDictionary *prefs;
	
	[_prefsLock lock];
	prefs = [self _enginePreferences];
	[prefs setObject:manpaths forKey:iManEngineManpaths];
	[self _setEnginePreferences:prefs];
	[_prefsLock unlock];
}

- (NSString *)manpathString
{
	return [[self manpaths] componentsJoinedByString:@":"];
}
	
@end
