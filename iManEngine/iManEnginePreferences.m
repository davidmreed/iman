//
// iManEnginePreferences.m
// iMan
// Copyright (c) 2006 by David Reed, distributed under the BSD License.
// see iman-macosx.sourceforge.net for details.
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

static NSString *const iManEngineBundleIdentifier = @"net.sf.iman-macosx.imanengine";
static NSString *const iManEnginePathDictionary = @"iManEnginePathDictionary";
static NSString *const iManEngineManpaths = @"iManEngineManpaths";

+ (void)initialize
{
    _pathDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:
        @"/usr/bin/man", @"man",
        @"/usr/bin/groff", @"groff",
		@"/usr/bin/manpath", @"manpath",
		@"/usr/libexec/makewhatis", @"makewhatis",
        nil];
	_prefsLock = [[NSLock alloc] init];
	
	[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObject:[NSDictionary dictionaryWithObject:_pathDictionary forKey:iManEnginePathDictionary] forKey:iManEngineBundleIdentifier]];
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
	loadedPathDictionary = [[[NSUserDefaults standardUserDefaults] objectForKey:iManEngineBundleIdentifier] objectForKey:iManEnginePathDictionary];
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
	if (ret != nil)
		return ret;
	
	dat = [NSTask invokeTool:@"manpath" arguments:[NSArray arrayWithObject:@"-q"] environment:nil];
	
	if (dat != nil) {
		string = [NSString stringWithCString:[dat bytes] length:[dat length] - 1];
		ret = [string componentsSeparatedByString:@":"];
	}
	
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
	// FIXME: is it correct in all circumstances to escape spaces? For example, if we set this value as MANPATH in the environment of some process, need it be escaped?
	return [[[self manpaths] componentsJoinedByString:@":"] stringByReplacingOccurrencesOfString:@" " withString:@"\\ "];
}
	
@end
