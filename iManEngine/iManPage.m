//
//  iManPage.m
//  iManEngine
//  Copyright (c) 2004-2010 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//


#import "iManPage.h"
#import "iManErrors.h"
#import "iManEnginePreferences.h"
#import "iManRenderOperation.h"
#import "iManPageCache.h"
#import "NSString+iManPathExtensions.h"
#import "RegexKitLite.h"
#import "NSOperationQueue+iManEngine.h"

@interface iManPage (Private)

- (void)_handleRenderOperationFinished:(iManRenderOperation *)operation;

@end

@implementation iManPage

+ pageWithPath:(NSString *)path
{
	return [[[iManPage alloc] initWithPath:path] autorelease];
}

- initWithPath:(NSString *)path
{
	self = [super init];
	
	if (self) {
		if ([[iManPageCache sharedCache] isPageCachedWithPath:path] &&
			([[iManPageCache sharedCache] cachedPageWithPath:path] != nil)) {
			// If there is a cached instance for this path, substitute it.
			[self dealloc];
			return [[[iManPageCache sharedCache] cachedPageWithPath:path] retain];
		} else {
			path_ = [path retain];
			_renderOperation = nil;
			[[iManPageCache sharedCache] cachePage:self];
		}
	}
	
	return self;
}

- initWithCoder:(NSCoder *)coder
{
	self = [super init];
	
	if (self) {
		if ([coder allowsKeyedCoding]) {
			path_ = [[coder decodeObjectForKey:@"path"] retain];
			page_ = [[coder decodeObjectForKey:@"page"] retain];
		} else {
			path_ = [[coder decodeObject] retain];
			page_ = [[coder decodeObject] retain];
		}
	} 
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	if ([coder allowsKeyedCoding]) {
		[coder encodeObject:[self path] forKey:@"path"];
		[coder encodeObject:[self page] forKey:@"page"];
	} else {
		[coder encodeObject:[self path]];
		[coder encodeObject:[self page]];
	}
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"iManPage %p: \"%@(%@)\" at \"%@\"", self, [self pageName], [self pageSection], [self path]];
}

- (NSString *)path
{
	return path_;
}

- (NSString *)pageName
{
	return [[self path] pageName]; 
}

- (NSString *)pageSection
{	
	return [[self path] pageSection];
}

- (NSAttributedString *)page
{
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

// When a load or resolve request is made, we create a new NSOperation and observe changes in its "isFinished" property. 

- (void)load
{
	if (![self isLoaded] && ![self isLoading]) {		
		_renderOperation = [[iManRenderOperation alloc] initWithPath:[self path]];
		[_renderOperation addObserver:self forKeyPath:@"isFinished" options:0 context:NULL];
		[[NSOperationQueue iManEngineOperationQueue] addOperation:_renderOperation];
	}
}

- (void)reload
{
	if ([self isLoaded] && ![self isLoading]) {
		[self willChangeValueForKey:@"page"];
		[page_ release];
		page_ = nil;
		[self didChangeValueForKey:@"page"];
		[self load];
	}
}

- (void)_handleRenderOperationFinished:(iManRenderOperation *)operation
{
	// This method called on main thread when KVO notification tells us (on *worker* thread, because that's where the KVO notification is posted) that the operation is finished.
	[self willChangeValueForKey:@"page"];
	[page_ release];
	page_ = nil;
	
	if ([_renderOperation page] != nil) {
		page_ = [[_renderOperation page] copy];
		[[NSNotificationCenter defaultCenter] postNotificationName:iManPageLoadDidCompleteNotification object:self userInfo:nil];
	} else {
		[[NSNotificationCenter defaultCenter] postNotificationName:iManPageLoadDidFailNotification object:self userInfo:[NSDictionary dictionaryWithObject:[operation error] forKey:iManErrorKey]];
	}
	[_renderOperation removeObserver:self forKeyPath:@"isFinished"];
	[_renderOperation release];
	_renderOperation = nil;
	[self didChangeValueForKey:@"page"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{	
	if ([keyPath isEqualToString:@"isFinished"]) {
		[self performSelectorOnMainThread:@selector(_handleRenderOperationFinished:) withObject:object waitUntilDone:NO];
	}
}

#pragma mark -

- (void)dealloc
{
	// It is not impossible (although unlikely due to caching) for us to be deallocated before our operations complete, resulting in -observeValueForKeyPath: messages being sent to a freed object. Remove observers here.
	if (_renderOperation != nil) {
		[_renderOperation removeObserver:self forKeyPath:@"isFinished"];
		[_renderOperation release];
	}
	
	[page_ release];
	[path_ release];
	[super dealloc];
}

@end

NSString *const iManPageLoadDidCompleteNotification = @"iManPageLoadDidCompleteNotification";
NSString *const iManPageLoadDidFailNotification = @"iManPageLoadDidFailNotification";
NSString *const iManPageError = @"iManPageError";

NSString *const iManPageStyleAttributeName = @"iManPageStyleAttributeName";
NSString *const iManPageLinkAttributeName = @"iManPageLinkAttributeName";

NSString *const iManPageUnderlineStyle = @"iManPageUnderlineStyle";
NSString *const iManPageBoldStyle = @"iManPageBoldStyle";
NSString *const iManPageBoldUnderlineStyle = @"iManPageBoldUnderlineStyle";
NSString *const iManPageDefaultStyle = @"iManPageDefaultStyle";
NSString *const iManPageUnderlineLinks = @"iManPageUnderlineLinks";