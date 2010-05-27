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
#import "RegexKitLite.h"

@interface iManPage (Private)

- (void)_handleRenderOperationFinished:(iManRenderOperation *)operation;

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

+ pageWithPath:(NSString *)path
{
	iManPage *ret;
	
	if (ret = [_iManPageCache objectForKey:path])
		return ret;
	
	ret = [[iManPage alloc] initWithPath:path];
	[_iManPageCache setObject:ret forKey:path];
	
	return [ret autorelease];
}

- initWithPath:(NSString *)path
{
	self = [super init];
	
	if (self) {
		if ([_iManPageCache objectForKey:path] != nil) {
			// If there is a cached instance for this path, substitute it.
			[self dealloc];
			return [_iManPageCache objectForKey:path];
		} else {
			path_ = [path retain];
			_renderOperation = nil;
		}
	}
	
	return self;
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
	if ([[[self path] pathExtension] isEqualToString:@"gz"]) 
		return [[[[self path] lastPathComponent] stringByDeletingPathExtension] stringByDeletingPathExtension];
	
	return [[[self path] lastPathComponent] stringByDeletingPathExtension];
}

- (NSString *)pageSection
{	
	if ([[[[self path] lastPathComponent] pathExtension] isEqualToString:@"gz"])
		return [[[[self path] lastPathComponent] stringByDeletingPathExtension] pathExtension];

	return [[[self path] lastPathComponent] pathExtension];
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

// When a load or resolve request is made, we create a new NSOperation and observe changes in its "isFinished" property. 

- (void)load
{
	if (![self isLoaded] && ![self isLoading]) {		
		_renderOperation = [[iManRenderOperation alloc] initWithPath:[self path]];
		[_renderOperation addObserver:self forKeyPath:@"isFinished" options:0 context:NULL];
		[_iManPageRenderingQueue addOperation:_renderOperation];
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

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{	
	if ([keyPath isEqualToString:@"isFinished"]) {
		[self performSelectorOnMainThread:@selector(_handleRenderOperationFinished:) withObject:object waitUntilDone:NO];
	}
}

#pragma mark -

- (void)dealloc
{
	// It is not impossible (although unlikely due to caching) for us to be deallocated before our operations complete, resulting in -observeValueForKeyPath: messages being sent to a freed object. Remove observers here. FIXME: kill the operations.
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