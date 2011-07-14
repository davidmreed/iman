//
//  iManPageCache.m
//  iManEngine
//  Copyright (c) 2004-2010 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import "iManPageCache.h"
#import "iManEnginePreferences.h"
#import "iManPage.h"
#import "NSOperationQueue+iManEngine.h"

@interface iManPageCache (Private)

- (void)_pageDidCompleteLoading:(NSNotification *)notification;
- (void)_writePageToDiskCache:(iManPage *)page;

- (NSString *)_cachePathForPath:(NSString *)path;
- (NSString *)_baseCachePath;

@end

@implementation iManPageCache

+ (iManPageCache *)sharedCache
{
	static iManPageCache *cache = nil;
	
	if (cache == nil) {
		cache = [[iManPageCache alloc] init];
	}
	
	return cache;
}

- init
{
	self = [super init];
	
	if (self != nil) {
		_cache = [[NSMutableDictionary alloc] init];
	}
	
	return self;
}

- (BOOL)isPageCachedWithPath:(NSString *)path
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *cachePath = [self _cachePathForPath:path];

	return (([_cache objectForKey:path] != nil) || 
			([fm isReadableFileAtPath:cachePath] &&
			 ([[[fm fileAttributesAtPath:cachePath traverseLink:NO] fileModificationDate] compare:[[fm fileAttributesAtPath:path traverseLink:YES] fileModificationDate]] != NSOrderedAscending)));
}

- (iManPage *)cachedPageWithPath:(NSString *)path
{
	NSFileManager *fm = [NSFileManager defaultManager];
	if ([_cache objectForKey:path] != nil) {
		return [_cache objectForKey:path];
	}
	
	@try {
		NSString *cachePath = [self _cachePathForPath:path];
		if ([fm isReadableFileAtPath:cachePath] &&
			([[[fm fileAttributesAtPath:cachePath traverseLink:NO] fileModificationDate] compare:[[fm fileAttributesAtPath:path traverseLink:YES] fileModificationDate]] != NSOrderedAscending)) {
			NSData *data = [NSData dataWithContentsOfFile:cachePath];
				
			if (data != nil) {
				iManPage *page = [NSKeyedUnarchiver unarchiveObjectWithData:data];
				return page;
			}
		}
	} @catch (id exception) {
	}
	
	return nil;
}

- (void)cachePage:(iManPage *)page
{
	if ([[iManEnginePreferences sharedInstance] useMemoryCache]) 
		[_cache setObject:page forKey:[page path]];
	if ([[iManEnginePreferences sharedInstance] useDiskCache]) {
		if ([page isLoaded]) {
			[[NSOperationQueue iManEngineOperationQueue] addOperation:[[[NSInvocationOperation alloc] initWithTarget:self selector:@selector(_writePageToDiskCache:) object:page] autorelease]];
		} else {
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_pageDidCompleteLoading:) name:iManPageLoadDidCompleteNotification object:page];
		}
	}
}

- (void)_writePageToDiskCache:(iManPage *)page
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSData *data;
	NSString *path = [self _cachePathForPath:[page path]];
	NSFileManager *fm = [[NSFileManager alloc] init]; // Thread-safe when instantiated thus.

	if (path != nil) {
		// Attempt to create the directory. Ignore errors -- just let the write fail, no big deal.
		[fm createDirectoryAtPath:[path stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
		data = [NSKeyedArchiver archivedDataWithRootObject:page];
		if (data != nil) {
			[data writeToFile:path atomically:YES];
		}
	}
	
	[fm release];
	[pool release];
}

- (void)_pageDidCompleteLoading:(NSNotification *)notification
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:[notification name] object:[notification object]];
	if ([[NSUserDefaults standardUserDefaults] boolForKey:iManEngineUseDiskCache]) {
		[[NSOperationQueue iManEngineOperationQueue] addOperation:[[[NSInvocationOperation alloc] initWithTarget:self selector:@selector(_writePageToDiskCache:) object:[notification object]] autorelease]];
	}
}

- (void)clearCache
{
	[self clearDiskCache];
	[self clearMemoryCache];
}

- (void)clearMemoryCache
{
	[_cache release];
	_cache = [[NSMutableDictionary alloc] init];
}

- (void)clearDiskCache
{
	[[NSFileManager defaultManager] removeItemAtPath:[self _baseCachePath] error:nil];
}

- (NSString *)_cachePathForPath:(NSString *)path
{
	return [[self _baseCachePath] stringByAppendingPathComponent:[path stringByAppendingPathExtension:@"imancache"]];
}

- (NSString *)_baseCachePath
{	
	// We store cached pages as ~/Library/Caches/org.ktema.iman.imanengine/[application bundle ID]/man/path/name.section.imancache
	// We don't lock across apps, so the cache needs to be application-local.
	return [NSString pathWithComponents:[NSArray arrayWithObjects:[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject], [[NSBundle bundleForClass:[iManPageCache class]] bundleIdentifier], [[NSBundle mainBundle] bundleIdentifier], nil]];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_cache release];
	[super dealloc];
}
@end
