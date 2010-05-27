//
//  iManPage.m
//  iManEngine
//  Copyright (c) 2006-2009 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//


#import "iManPage.h"
#import "iManErrors.h"
#import "iManEnginePreferences.h"
#import "iManRenderOperation.h"
#import "iManResolveOperation.h"
#import "RegexKitLite.h"

@interface iManPage (Private)

// Initializers are private because we cache instances.
- initWithPath:(NSString *)path;
- initWithName:(NSString *)name inSection:(NSString *)section;

- (void)_handleRenderOperationFinished:(iManRenderOperation *)operation;
- (void)_handleResolveOperationFinished:(iManResolveOperation *)operation;

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
	// FIXME: are these section regexes appropriate? what about TCL? 
	// grohtml style: man://groff/1. Regex: \/{0,2}([^[:space:]/]+)\/([0-9n][a-zA-Z]*)\/? 
	NSString *grohtmlStyleURL = @"\\/{0,2}([^[:space:]/]+)\\/([0-9n][a-zA-Z]*)\\/?";
	// The old iMan style: man:groff(1). Regex: ([^[:space:](]+)\(([0-9n][a-zA-Z]*)\)
	NSString *iManStyleURL = @"([^[:space:](]+)\\(([0-9a-zA-Z]+)\\)";
	// x-man-page: style: x-man-page://1/groff. Regex: \/{0,2}([0-9n][a-zA-Z]*)\/([^[:space:]/]+)\/?
	NSString *xmanpageStyleURL = @"\\/{0,2}([0-9n][a-zA-Z]*)\\/([^[:space:]/]+)\\/?";
	// grohtml style without section, which may come in (for instance) from our command line tool.
	NSString *grohtmlStyleURLNoSection = @"\\/{0,2}([^[:space:]/]+)\\/?";

	NSString *name = nil, *section = nil;
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
		name = [manpage stringByMatching:xmanpageStyleURL capture:2];
		section = [manpage stringByMatching:xmanpageStyleURL capture:1];
	} else if ([manpage isMatchedByRegex:grohtmlStyleURLNoSection]) {
		// It's a URL of the format man://groff
		name = [manpage stringByMatching:grohtmlStyleURLNoSection capture:1];
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
		_renderOperation = nil;
		_resolveOperation = nil;
	}
	
	return self;
}

- initWithName:(NSString *)name inSection:(NSString *)section
{
	self = [super init];

	if (self) {
		pageName_ = [name retain];
		pageSection_ = [section retain];
		_renderOperation = nil;
		_resolveOperation = nil;
	}
	
	return self;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"iManPage %p: \"%@(%@)\" at \"%@\"", self, [self pageName], [self pageSection], [self path]];
}

- (NSString *)path
{
	// FIXME: make property KVO-compliant.
	return path_;
}

- (NSString *)pageName
{
	// FIXME: make property KVO-compliant.
	if (pageName_)
		return pageName_;
	
	return [[[self path] lastPathComponent] stringByDeletingPathExtension];
}

- (NSString *)pageSection
{	
	// FIXME: make property KVO-compliant.
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
	// FIXME: make property KVO-compliant.
	return [[page_ copy] autorelease];
}

- (NSAttributedString *)pageWithStyle:(NSDictionary *)style
{
	NSMutableAttributedString *ret = [[self page] mutableCopy];
	NSDictionary *normalDictionary;
	NSDictionary *boldDictionary;
	NSDictionary *underlinedDictionary;
	NSDictionary *boldUnderlinedDictionary;
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
	
	boldUnderlinedDictionary = [style objectForKey:iManPageBoldUnderlineStyle];
	if (boldUnderlinedDictionary == nil)
		boldUnderlinedDictionary = [NSDictionary dictionary];
	
	if ([style objectForKey:iManPageUnderlineLinks] != nil)
		showLinks = [[style objectForKey:iManPageUnderlineLinks] boolValue];
	else
		showLinks = YES;
	
	linkDictionary = [NSDictionary dictionaryWithObjectsAndKeys:[NSColor blueColor], NSForegroundColorAttributeName, [NSNumber numberWithInt:NSSingleUnderlineStyle], NSUnderlineStyleAttributeName, nil];
	
	while (index < length) {
		NSDictionary *attributes = [ret attributesAtIndex:index effectiveRange:&range];
		
		if ((obj = [attributes objectForKey:iManPageStyleAttributeName]) != nil) {
			if ([obj isEqualToString:iManPageBoldStyle]) {
				[ret addAttributes:boldDictionary range:range];
			} else if ([obj isEqualToString:iManPageUnderlineStyle]) {
				[ret addAttributes:underlinedDictionary range:range];
			} else if ([obj isEqualToString:iManPageBoldUnderlineStyle]) {
				[ret addAttributes:boldUnderlinedDictionary range:range];
			}
		} else {
			[ret addAttributes:normalDictionary range:range];
		}
		
		if (showLinks && ((obj = [attributes objectForKey:iManPageLinkAttributeName]) != nil)) {
			[ret addAttributes:linkDictionary range:range];
			[ret addAttribute:NSLinkAttributeName value:obj range:range];
		}
		
		index = NSMaxRange(range);
	}
	
	return [ret autorelease];
}

- (BOOL)isLoaded
{
	// FIXME: make property KVO-compliant.

	return ([self page] != nil);
}

- (BOOL)isLoading
{
	// FIXME: make property KVO-compliant.

	return ((_renderOperation != nil) && [_renderOperation isExecuting]);
}

- (BOOL)isResolved
{
	// FIXME: make property KVO-compliant.

	return ([self path] != nil);
}

- (BOOL)isResolving
{
	// FIXME: make property KVO-compliant.

	return ((_resolveOperation != nil) && [_resolveOperation isExecuting]);
}

// When a load or resolve request is made, we create a new NSOperation and observe changes in its "isFinished" property. 

- (void)load
{
	if (![self isLoaded] && ![self isLoading] && ![self isResolving]) {		
		if ([self isResolved]) {
			_renderOperation = [[iManRenderOperation alloc] initWithPath:[self path]];
			[_iManPageRenderingQueue addOperation:_renderOperation];
		} else {
			_resolveOperation = [[iManResolveOperation alloc] initWithName:[self pageName] section:[self pageSection]];
			_renderOperation = [[iManRenderOperation alloc] initWithDeferredPath];
			[_renderOperation addDependency:_resolveOperation];
			[_resolveOperation addObserver:self forKeyPath:@"isFinished" options:0 context:NULL];
			[_iManPageRenderingQueue addOperation:_renderOperation];
			[_iManPageRenderingQueue addOperation:_resolveOperation];
		}
		
		[_renderOperation addObserver:self forKeyPath:@"isFinished" options:0 context:NULL];
	}
}

- (void)reload
{
	if ([self isLoaded] && ![self isLoading]) {
		[page_ release];
		page_ = nil;
		[self load];
	}
}

- (void)resolve
{
	if (![self isResolved] && ![self isResolving] && ![self isLoading]) {
		_resolveOperation = [[iManResolveOperation alloc] initWithName:[self pageName] section:[self pageSection]];
		
		[_resolveOperation addObserver:self forKeyPath:@"isFinished" options:0 context:NULL];
		[_iManPageRenderingQueue addOperation:_resolveOperation];
	}
}

- (void)_handleRenderOperationFinished:(iManRenderOperation *)operation
{
	// This method called on main thread when KVO notification tells us (on *worker* thread, because that's where the KVO notification is posted) that the operation is finished.
	[page_ release];
	[path_ release];
	page_ = nil;
	path_ = nil;
	
	if ([_renderOperation page] != nil) {
		page_ = [[_renderOperation page] copy];
		path_ = [[_renderOperation path] copy];
		[[NSNotificationCenter defaultCenter] postNotificationName:iManPageLoadDidCompleteNotification object:self userInfo:nil];
	} else {
		[[NSNotificationCenter defaultCenter] postNotificationName:iManPageLoadDidFailNotification object:self userInfo:[NSDictionary dictionaryWithObject:[operation error] forKey:iManErrorKey]];
	}
	[_renderOperation removeObserver:self forKeyPath:@"isFinished"];
	[_renderOperation release];
	_renderOperation = nil;
}

- (void)_handleResolveOperationFinished:(iManResolveOperation *)operation
{
	// This method called on main thread when KVO notification tells us (on *worker* thread, because that's where the KVO notification is posted) that the operation is finished.
	[path_ release];
	path_ = nil;
	
	if ([_resolveOperation path] != nil) {
		path_ = [[_resolveOperation path] copy];
		// Update the page cache so that attempts to load our newly resolved path will return this object.
		[_iManPageCache setObject:self forKey:[self path]];
		[[NSNotificationCenter defaultCenter] postNotificationName:iManPageResolveDidCompleteNotification object:self userInfo:nil];
	} else {
		[[NSNotificationCenter defaultCenter] postNotificationName:iManPageResolveDidFailNotification object:self userInfo:[NSDictionary dictionaryWithObject:[operation error] forKey:iManErrorKey]];
	}
	[_resolveOperation removeObserver:self forKeyPath:@"isFinished"];
	[_resolveOperation release];
	_resolveOperation = nil;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{	
	if ([keyPath isEqualToString:@"isFinished"]) {
		if (object == _renderOperation) {
			[self performSelectorOnMainThread:@selector(_handleRenderOperationFinished:) withObject:object waitUntilDone:NO];
		} else if (object == _resolveOperation) {
			[self performSelectorOnMainThread:@selector(_handleResolveOperationFinished:) withObject:object waitUntilDone:NO];
		}
	}
}

#pragma mark -

- (void)dealloc
{
	// It is not impossible (although unlikely due to caching) for us to be deallocated before our operations complete, resulting in -observeValueForKeyPath: messages being sent to a freed object. Remove observers here. FIXME: kill the operations.
	if (_resolveOperation != nil) {
		[_resolveOperation removeObserver:self forKeyPath:@"isFinished"];
		[_resolveOperation release];
	}
	if (_renderOperation != nil) {
		[_renderOperation removeObserver:self forKeyPath:@"isFinished"];
		[_renderOperation release];
	}
	
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
NSString *const iManPageBoldUnderlineStyle = @"iManPageBoldUnderlineStyle";
NSString *const iManPageDefaultStyle = @"iManPageDefaultStyle";
NSString *const iManPageUnderlineLinks = @"iManPageUnderlineLinks";