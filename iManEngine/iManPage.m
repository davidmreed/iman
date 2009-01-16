//
// iManPage.m
// iMan
// Copyright (c) 2006 by David Reed, distributed under the BSD License.
// see iman-macosx.sourceforge.net for details.
//


#import "iManPage.h"
#import "DMRTask.h"
#import "DMRTaskQueue.h"
#import "iManEnginePreferences.h"
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
static DMRTaskQueue *_iManPageRenderingQueue;

+ (void)initialize
{
	_iManPageCache = [[NSMutableDictionary alloc] init];
	_iManPageRenderingQueue = [[DMRTaskQueue alloc] init];
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
	NSString *path;
	
	@synchronized (path_) {
		path = [[path_ retain] autorelease];
	}
	
	return path;
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

// When a load or resolve request is made, we create a new DMRTask with this page as the delegate. 
// Then, when we are notified that the operation completed, we use the main-thread notification center to post a notification.

- (void)load
{
	if (![self isLoaded] && !loading_) {
		DMRTask *task = [DMRTask taskWithTarget:self selector:@selector(_load:) object:nil contextInfo:nil];
		
		[task setDelegate:self];
		loading_ = YES;
		[_iManPageRenderingQueue addTask:task];
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
	if (![self isResolved] && !resolving_) {
		DMRTask *task = [DMRTask taskWithTarget:self selector:@selector(_resolve:) object:nil contextInfo:nil];
		
		[task setDelegate:self];
		resolving_ = YES;
		[_iManPageRenderingQueue addTask:task];
	}
}

#pragma mark -
#pragma mark DMRTask Delegate Methods

- (void)taskDidComplete:(DMRTask *)task
{
	if ([task selector] == @selector(_load:)) {
		loading_ = NO;
		[[NSNotificationCenter defaultCenter] postNotificationName:iManPageLoadDidCompleteNotification
															object:self
														  userInfo:nil];
	} else if ([task selector] == @selector(_resolve:)) {
		resolving_ = NO;
		// Update the page cache so that attempts to load our newly resolved path will return this object.
		[_iManPageCache setObject:self forKey:[self path]];
		[[NSNotificationCenter defaultCenter] postNotificationName:iManPageResolveDidCompleteNotification
															object:self
														  userInfo:nil];
	}
}

- (void)task:(DMRTask *)task failedWithError:(NSString *)error
{
	NSString *err = NSLocalizedStringFromTableInBundle(error, @"Localizable.strings", [NSBundle bundleForClass:[self class]], nil);
	
	if ([task selector] == @selector(_load:)) {
		loading_ = NO;
		[[NSNotificationCenter defaultCenter] postNotificationName:iManPageLoadDidFailNotification
															object:self
														  userInfo:[NSDictionary dictionaryWithObject:err forKey:iManPageError]];
	} else if ([task selector] == @selector(_resolve:)) {
		resolving_ = NO;
		[[NSNotificationCenter defaultCenter] postNotificationName:iManPageResolveDidFailNotification
															object:self
														  userInfo:[NSDictionary dictionaryWithObject:err forKey:iManPageError]];
	}
}

#pragma mark -
#pragma mark Low-Level Private Methods

- (void)_load:(id)ignored
{
	id data;
	
	if (![self isResolved])
		[self _resolve:ignored];
	
	if ((data = [self renderedDataFromPath:[self path]]) == nil) 
		[self _reportFailure:@"The requested man page exists, but could not be loaded."];
	
	if ((data = [self attributedStringFromData:data]) == nil)
		[self _reportFailure:@"The requested man page exists, but could not be rendered."];
	
	@synchronized (page_) {
		[page_ release];
		page_ = [data retain];
	}
}

- (void)_resolve:(id)ignored
{
    // Calls man -w section page, via our NSTask category, to get the filename to load.
    NSArray *args;
    NSData *ret;
	
    // Set up the arguments based on whether or not the section is known.
    if (pageSection_ == nil) {
        args = [NSArray arrayWithObjects:
			@"-M",
			[[iManEnginePreferences sharedInstance] manpathString],
            @"-w",
            pageName_,
            nil];
    } else {
        args = [NSArray arrayWithObjects:
			@"-M",
			[[iManEnginePreferences sharedInstance] manpathString],
            @"-w",
            pageSection_,
            pageName_,
            nil];
    }
    ret = [NSTask invokeTool:@"man" arguments:args environment:nil];
	
    // the data returned has a newline at the end, so if we got some data,
    // convert it to an NSString, omitting the newline, and make sure it's an OK path.
    if (ret != nil) {
		@synchronized (path_) {
			[path_ release];
			path_ = [[[NSString stringWithCString:[ret bytes] length:([ret length] - 1)] stringByStandardizingPath] retain];
		}
	} else {
		[self _reportFailure:@"The requested man page could not be located."];
	}
}

- (void)_reportFailure:(NSString *)error
{
	[NSException raise:NSGenericException format:error];
}

- (NSData *)renderedDataFromPath:(NSString *)path
{
	if ([[[path lastPathComponent] pathExtension] isEqualToString:@"gz"])
		return [self _renderedDataFromGzippedPath:path];
	
	return [NSTask invokeTool:@"groff"
					arguments:[NSArray arrayWithObjects:
						@"-Tascii", // ASCII output, UTF-8 doesn't work right now
						@"-P", // -P sends next argument to postprocessor
						@"-c", // tells grotty to use old-style format codes
						@"-S", // safe mode (on by default, just to be sure)
						@"-t", // preprocess with tbl (man default).
						@"-mandoc", // appropriate macro package
						path,
						nil]
				  environment:nil];
}

- (NSData *)_renderedDataFromGzippedPath:(NSString *)path
{
    // This is a rather clunky but workable hack to deal with gzip'ed man pages.
    // Much of this code is copied from the NSTask category, but it has had an input pipe
    // with on-the-fly decompression added (courtesy of zlib).
	
    NSTask *task = [[NSTask alloc] init];
    NSPipe *output = [NSPipe pipe];
    NSPipe *input = [NSPipe pipe];
    NSString *launchPath = [[iManEnginePreferences sharedInstance] pathForTool:@"groff"];
    NSData *data;
	NSFileHandle *readHandle;
    int returnStatus;
	
    gzFile theFile;
    voidp buf;
    unsigned bytesRead;
    int fd;
	
    // Set up the task.
    if (launchPath != nil) {
        [task setLaunchPath:launchPath];
    } else {
        [task release];
        return nil;
    }
    [task setArguments:[NSArray arrayWithObjects:
        @"-Tascii",		// ASCII output, UTF-8 doesn't work right now
        @"-P",			// -P sends next argument to postprocessor
        @"-c",			// tells grotty to use old-style format codes
        @"-S",			// safe mode (on by default, just to be sure)
        @"-t",			// preprocess with tbl (man default).
        @"-mandoc",		// appropriate macro package
        @"-",			// input on stdin
        nil]];
	
    [task setStandardInput:input];
    [task setStandardOutput:output];
    [task setStandardError:[NSFileHandle fileHandleWithNullDevice]];
	
    if ((theFile = gzopen([[NSFileManager defaultManager] fileSystemRepresentationWithPath:path],
                          "rb")) == nil) {
        [task release];
        return nil;
    }
	
    if ((buf = malloc(4096)) == nil) {
        [task release];
        gzclose(theFile);
        return nil;
    }
	
    [task launch];
    fd = [[input fileHandleForWriting] fileDescriptor];    
	readHandle = [output fileHandleForReading];
	
    while ((bytesRead = gzread(theFile, buf, 4096)) > 0) {
        write(fd, buf, bytesRead); // send it on to groff.
    }
		
    [[input fileHandleForWriting] closeFile];
    gzclose(theFile);
	
	data = [readHandle readDataToEndOfFile];
    [task waitUntilExit];
	
    returnStatus = [task terminationStatus];
    [task release];
	
    if (returnStatus == EXIT_SUCCESS)
        return data;
    else
        return nil;
}

- (NSAttributedString *)attributedStringFromData:(NSData *)data
{
    // This function converts the output of grotty(1) from old-style formatted ASCII
    // to an NSAttributedString, replacing the crude format codes with attributes.
	// The string returned is cacheable, no preference specific formatting. It must be
	// fed through displayStringFromAttributedString: to add font/style info.
    NSMutableAttributedString *str = [[NSMutableAttributedString alloc] init];
    NSDictionary *underlineDictionary;
    NSDictionary *boldDictionary;
    NSDictionary *normalDictionary;
    const unsigned char *bytes = [data bytes];
    unsigned length = [data length];
    unsigned index;
	
    // Cache style dictionaries for speed.
    underlineDictionary = [NSDictionary dictionaryWithObject:iManPageUnderlineStyle
													  forKey:iManPageStyleAttributeName];
    boldDictionary = [NSDictionary dictionaryWithObject:iManPageBoldStyle 
												 forKey:iManPageStyleAttributeName];
    normalDictionary = [NSDictionary dictionary];
	
    // Iterate over the input data character by character. If we encounter a backspace
    // (0x08), this indicates a format code. The sequence 'c 0x08 c' means a bold 'c',
    // '_ 0x08 c' means an underlined 'c'.
    // Basically we just scan through looking for a backspace. When we find one, append the
    // following character to the string with the appropriate style, then skip two characters
    // (the backspace and the next one). Otherwise, just append the character.
    
    // Note that sometimes grotty uses extra overstriking (apparently to mean "more bold").
    // This will be marked by the sequence "x 0x08 x 0x08 x 0x08 x".
    // We already parse the first x 0x08 x, so when we hit an unexpected 0x08, we just
    // drop it and the next character.
    
    for (index = 0; index < length; index++) {
        if (*(bytes + index) == 0x08)  { // drop extra overstriking
            index++; // inc to skip this and the next one.
            continue;
        }
        
        if (*(bytes + index + 1) == 0x08) { // backspace
            if ((index + 1) < length) {
                if (*(bytes + index) == '_') { // underline
                    [str appendAttributedString:
                        [[[NSAttributedString alloc] initWithString:[NSString stringWithCString:(char *)(bytes + index + 2) length:1] attributes:underlineDictionary] autorelease]];
                } else {
                    [str appendAttributedString:
                        [[[NSAttributedString alloc] initWithString:[NSString stringWithCString:(char *)(bytes + index) length:1] attributes:boldDictionary] autorelease]];
                }
				
                index += 2;
            }
        } else {
            [str appendAttributedString:
                [[[NSAttributedString alloc] initWithString:[NSString stringWithCString:(char *)(bytes + index) length:1]
                                                 attributes:normalDictionary] autorelease]];
        }
    }
	
    // Now, use RegexKitLite to find anything that looks like a page reference and add a link.
    // Pattern for link matching: \S+\(\d[a-z]*\)
    
	{
        NSEnumerator *results;
		NSString *searchText = [str string];
		NSValue *match;

        results = [searchText matchEnumeratorWithRegex:@"\\S+\\(\\d[a-zA-Z]*\\)" options:RKLNoOptions | RKLMultiline];
		
		
		while ((match = [results nextObject]) != nil) {
            NSRange range = [match rangeValue];
			NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"man:%@", [searchText substringWithRange:range]]];
			
			if (url != nil)
				[str addAttribute:iManPageLinkAttributeName
							value:url
							range:range];
        }
    }
	
    return [str autorelease];
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