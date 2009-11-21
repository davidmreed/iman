//
// iManPage.m
// iMan
// Copyright (c) 2006 by David Reed, distributed under the BSD License.
// see iman-macosx.sourceforge.net for details.
//


#import "iManPage.h"
#import "iManEnginePreferences.h"
#import "iManRenderOperation.h"
#import "iManResolveOperation.h"
#import "NSTask+iManExtensions.h"

#import <zlib.h>
#import <unistd.h>
#import "RegexKitLite/RegexKitLite.h"
#import "RegexKitLiteSupport/RKLMatchEnumerator.h"

@interface iManPage (Private)

- initWithPath:(NSString *)path;
- initWithName:(NSString *)name inSection:(NSString *)section;
- (void)_load:(id)ignored;
- (void)_resolve:(id)ignored;
- (void)_reportFailure:(NSString *)error;
- (NSData *)renderedDataFromPath:(NSString *)path;
- (NSData *)_renderedDataFromGzippedPath:(NSString *)path;
- (NSAttributedString *)attributedStringFromData:(NSData *)data;

@end

@implementation iManPage

static NSMutableDictionary *_iManPageCache;
static NSOperationQueue *_iManPageRenderingQueue;

+ (void)initialize
{
	_iManPageCache = [[NSMutableDictionary alloc] init];
	_iManPageRenderingQueue = [[NSOperationQueue alloc] init];
}

+ (void)clearCache
{
	[_iManPageCache removeAllObjects];
}

+ pageWithURL:(NSURL *)url
{
	NSString *grohtmlStyleURL = @"\\/{1,2}([^\\/\\s]+)\\/(\\d+[a-zA-Z]*)\\/?";
	NSString *iManStyleURL = @"\\/{0,2}(\\S+)\\((\\d+[a-zA-Z]*)\\)";
	NSString *xmanpageStyleURL = @"\\/{1,2}(\\d+[a-zA-Z]*)\\/([^\\/\\s]+)\\/?";
	NSString *name, *section;
	NSString *manpage = [[url resourceSpecifier] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		
	if ([manpage isMatchedByRegex:grohtmlStyleURL]) {
		// It's a URL of the format man://groff/1 (as used by grohtml(1))
		name = [manpage stringByMatching:grohtmlStyleURL capture:1];
		section = [manpage stringByMatching:grohtmlStyleURL capture:2];
	} else if ([manpage isMatchedByRegex:iManStyleURL]) {
		// It's a URL of the format man:groff(1) (as used by earlier versions of iMan).
		name = [manpage stringByMatching:iManStyleURL capture:1];
		section = [manpage stringByMatching:iManStyleURL capture:2];
	} else if ([manpage isMatchedByRegex:xmanpageStyleURL]) {
		// It's a URL of the format (x-man-page:)//1/groff
		name = [manpage stringByMatching:iManStyleURL capture:2];
		section = [manpage stringByMatching:iManStyleURL capture:1];
	}
	
	if ((name != nil) && ([name length] > 0))
		return [iManPage pageWithName:name inSection:section];
	
	return nil;
}	

+ pageWithPath:(NSString *)path
{
	iManPage *ret;
	
	if (ret = [_iManPageCache objectForKey:path])
		return ret;
	
	ret = [[iManPage alloc] initWithPath:path];
	[_iManPageCache setObject:ret forKey:path];
	
	return [ret autorelease];
}

+ pageWithName:(NSString *)name inSection:(NSString *)section
{
	iManPage *ret;
	
	if (ret = [_iManPageCache objectForKey:[NSString stringWithFormat:@"%@(%@)", name, section]])
		return ret;
	
	ret = [[iManPage alloc] initWithName:name inSection:section];
	[_iManPageCache setObject:ret forKey:[NSString stringWithFormat:@"%@(%@)", name, section]];
	
	return [ret autorelease];
}

- initWithPath:(NSString *)path
{
	self = [super init];
	
	if (self) {
		path_ = [path retain];
		resolving_ = loading_ = NO;
	}
	
	return self;
}

- initWithName:(NSString *)name inSection:(NSString *)section
{
	self = [super init];

	if (self) {
		pageName_ = [name retain];
		pageSection_ = [section retain];
		resolving_ = loading_ = NO;		
	}
	
	return self;
}

- (NSString *)path
{
	return path_;
}

- (NSString *)pageName
{
	if (pageName_)
		return pageName_;
	
	return [[[self path] lastPathComponent] stringByDeletingPathExtension];
}

- (NSString *)pageSection
{	
	if ((pageSection_ != nil) && ([pageSection_ length] > 0)) {
		return pageSection_;
	} else {	
		if ([[[[self path] lastPathComponent] pathExtension] isEqualToString:@"gz"])
			return [[[[self path] lastPathComponent] stringByDeletingPathExtension] pathExtension];
		else
			return [[[self path] lastPathComponent] pathExtension];
	}
	
	return nil;
}

- (NSAttributedString *)page
{
	NSAttributedString *page;
	
	@synchronized (page_) {
		page = [[page_ retain] autorelease];
	}
	
	return page;
}

- (NSAttributedString *)pageWithStyle:(NSDictionary *)style
{
	NSMutableAttributedString *ret = [[self page] mutableCopy];
	NSDictionary *normalDictionary;
	NSDictionary *boldDictionary;
	NSDictionary *underlinedDictionary;
	NSDictionary *linkDictionary;
	id obj;
	unsigned index = 0, length = [ret length];
	NSRange range;
	BOOL showLinks;
	
	normalDictionary = [style objectForKey:iManPageDefaultStyle];
	if (normalDictionary == nil)
		normalDictionary = [NSDictionary dictionary];
	
	boldDictionary = [style objectForKey:iManPageBoldStyle];
	if (boldDictionary == nil)
		boldDictionary = [NSDictionary dictionary];
	
	underlinedDictionary = [style objectForKey:iManPageUnderlineStyle];
	if (underlinedDictionary == nil)
		underlinedDictionary = [NSDictionary dictionary];
	
	if ([style objectForKey:iManPageUnderlineLinks] != nil)
		showLinks = [[style objectForKey:iManPageUnderlineLinks] boolValue];
	else
		showLinks = YES;
	
	linkDictionary = [NSDictionary dictionaryWithObjectsAndKeys:[NSColor blueColor], NSForegroundColorAttributeName, [NSNumber numberWithInt:NSSingleUnderlineStyle], NSUnderlineStyleAttributeName, nil];
	
	while (index < length) {
		NSDictionary *attributes = [ret attributesAtIndex:index effectiveRange:&range];
		
		if ((obj = [attributes objectForKey:iManPageStyleAttributeName]) != nil) {
			if ([obj isEqualToString:iManPageBoldStyle])
				[ret addAttributes:boldDictionary range:range];
			else if ([obj isEqualToString:iManPageUnderlineStyle])
				[ret addAttributes:underlinedDictionary range:range];
		} else {
			[ret addAttributes:normalDictionary range:range];
		}
		
		if (showLinks && ((obj = [attributes objectForKey:iManPageLinkAttributeName]) != nil)) {
			[ret addAttributes:linkDictionary range:range];
			[ret addAttribute:NSLinkAttributeName value:obj range:range];
		}
		
		index = NSMaxRange(range) + 1;
	}
	
	return [ret autorelease];
}

- (BOOL)isLoaded
{
	return ([self page] != nil);
}

- (BOOL)isLoading
{
	return loading_;
}

- (BOOL)isResolved
{
	return ([self path] != nil);
}

- (BOOL)isResolving
{
	return resolving_;
}

// When a load or resolve request is made, we create a new NSOperation and observe changes in its "finished" property. 

- (void)load
{
	if (![self isLoaded] && !loading_ && !resolving_) {
		iManRenderOperation *operation;
		if ([self isResolved])
			operation = [[[iManRenderOperation alloc] initWithPath:[self path]] autorelease];
		else
			operation = [[[iManRenderOperation alloc] initWithName:[self pageName] section:[self pageSection]] autorelease];
		
		loading_ = YES;
		[operation addObserver:self forKeyPath:@"finished" options:0 context:NULL];
		[_iManPageRenderingQueue addOperation:operation];
	}
}

- (void)reload
{
	if ([self isLoaded] && !loading_) {
		[page_ release];
		page_ = nil;
		[self load];
	}
}

- (void)resolve
{
	if (![self isResolved] && !resolving_ && !loading_) {
		iManResolveOperation *operation = [[[iManResolveOperation alloc] initWithName:[self pageName] section:[self pageSection]] autorelease];
		
		resolving_ = YES;
		[operation addObserver:self forKeyPath:@"finished" options:0 context:NULL];
		[_iManPageRenderingQueue addOperation:operation];
	}
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"finished"]) {
		if ([object isMemberOfClass:[iManRenderOperation class]]) {
			[page_ release];
			[path_ release];
			page_ = path_ = nil;
			loading_ = NO;

			if ([object page] != nil) {
				page_ = [[object page] copy];
				path_ = [[object path] copy];
				[[NSNotificationCenter defaultCenter] postNotificationName:iManPageLoadDidCompleteNotification object:self userInfo:nil];
			} else {
				[[NSNotificationCenter defaultCenter] postNotificationName:iManPageLoadDidFailNotification object:self userInfo:nil];
			}
		} else if ([object isMemberOfClass:[iManResolveOperation class]]) {
			resolving_ = NO;
			[path_ release];
			path_ = nil;
			
			if ([object path] != nil) {
				path_ = [[object path] copy];
				// Update the page cache so that attempts to load our newly resolved path will return this object.
				[_iManPageCache setObject:self forKey:[self path]];
				[[NSNotificationCenter defaultCenter] postNotificationName:iManPageResolveDidCompleteNotification object:self userInfo:nil];
			} else {
				[[NSNotificationCenter defaultCenter] postNotificationName:iManPageResolveDidFailNotification object:self userInfo:nil];
			}
		}
	
		[object removeObserver:self forKeyPath:keyPath];
	}
}

#pragma mark -

- (void)dealloc
{
	[page_ release];
	[path_ release];
	[pageName_ release];
	[pageSection_ release];
	[super dealloc];
}

@end

NSString *const iManPageLoadDidCompleteNotification = @"iManPageLoadDidCompleteNotification";
NSString *const iManPageLoadDidFailNotification = @"iManPageLoadDidFailNotification";
NSString *const iManPageResolveDidCompleteNotification = @"iManPageResolveDidCompleteNotification";
NSString *const iManPageResolveDidFailNotification = @"iManPageResolveDidFailNotification";
NSString *const iManPageError = @"iManPageError";

NSString *const iManPageStyleAttributeName = @"iManPageStyleAttributeName";
NSString *const iManPageLinkAttributeName = @"iManPageLinkAttributeName";

NSString *const iManPageUnderlineStyle = @"iManPageUnderlineStyle";
NSString *const iManPageBoldStyle = @"iManPageBoldStyle";
NSString *const iManPageDefaultStyle = @"iManPageDefaultStyle";
NSString *const iManPageUnderlineLinks = @"iManPageUnderlineLinks";