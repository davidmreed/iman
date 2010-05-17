//
//  iManRenderOperation.m
//  iManEngine
//  Copyright (c) 2009 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import "iManRenderOperation.h"
#import "iManResolveOperation.h"
#import "NSTask+iManExtensions.h"
#import "iManEnginePreferences.h"
#import "iManPage.h"
#import "iManErrors.h"
#import "RegexKitLite.h"
#import "RKLMatchEnumerator.h"
#import <zlib.h>

@interface iManRenderOperation (Private)

- (NSData *)_renderedDataFromPath:(NSString *)path error:(NSError **)error;
- (NSData *)_renderedDataFromGzippedPath:(NSString *)path error:(NSError **)error;
- (NSAttributedString *)_attributedStringFromData:(NSData *)data error:(NSError **)error;

@end

//static unichar _readUnicharFromUTF8String(const unsigned char *bytes, const unsigned char *max, unsigned char **final);


@implementation iManRenderOperation

- (iManRenderOperation *)initWithPath:(NSString *)path
{
	self = [super init];

	if (self != nil) {
		_path = [path copy];
		_error = nil;
		_pendingResolution = NO;
	}
	
	return self;
}

- (iManRenderOperation *)initWithDeferredPath
{
	self = [super init];
	
	if (self != nil) {
		_path = nil;
		_pendingResolution = YES;
	}
	
	return self;
}

- (void)main
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	if (_pendingResolution) {
		iManResolveOperation *resolveOperation = [[self dependencies] lastObject];
		
		if ([resolveOperation path] != nil) {
			_path = [[resolveOperation path] copy];
		} else {
			_error = [[NSError alloc] initWithDomain:iManEngineErrorDomain code:iManResolveFailedError userInfo:[NSDictionary dictionaryWithObject:[resolveOperation error] forKey:NSUnderlyingErrorKey]];
		}
	}

	if (_path != nil) {
		NSData *data;
		NSAttributedString *formattedPage;
		NSError *taskError;
		
		data = [self _renderedDataFromPath:[self path] error:&taskError];
		if (data != nil) {
			formattedPage = [self _attributedStringFromData:data error:&taskError];
			if (formattedPage != nil)
				_page = [formattedPage retain];
		}
		
		if (_page == nil)
			_error = [[NSError alloc] initWithDomain:iManEngineErrorDomain code:iManRenderFailedError userInfo:[NSDictionary dictionaryWithObject:taskError forKey:NSUnderlyingErrorKey]];
	} else {
		_page = nil;
		if (_error == nil) // i.e., if we have not inherited an error from the resolve operation -- we then have an internal inconsistency error.
			_error = [[NSError alloc] initWithDomain:iManEngineErrorDomain code:iManInternalInconsistencyError userInfo:nil];
	}
	
	[pool release];
}

- (NSData *)_renderedDataFromPath:(NSString *)path error:(NSError **)error
{
	if ([[[path lastPathComponent] pathExtension] isEqualToString:@"gz"])
		return [self _renderedDataFromGzippedPath:path error:error];
	
	return [NSTask invokeTool:@"groff"
					arguments:[NSArray arrayWithObjects:
							   @"-Tutf8", // UTF-8 grotty(1) output
							   @"-P", // -P sends next argument to postprocessor
							   @"-c", // tells grotty to use old-style format codes
							   @"-S", // safe mode (on by default, just to be sure)
							   @"-t", // preprocess with tbl (man default).
							   @"-mandoc", // appropriate macro package
							   path,
							   nil]
				  environment:nil
						error:error];
}

- (NSData *)_renderedDataFromGzippedPath:(NSString *)path error:(NSError **)error
{
    // This is a rather clunky but workable hack to deal with gzip'ed man pages.
    // Much of this code is copied from the NSTask category, but it has had an input pipe
    // with on-the-fly decompression added (courtesy of zlib).
	
    NSTask *task = [[NSTask alloc] init];
    NSPipe *output = [NSPipe pipe];
    NSPipe *input = [NSPipe pipe];
    NSString *launchPath = [[iManEnginePreferences sharedInstance] pathForTool:@"groff"];
    NSData *data = nil;
	NSFileHandle *readHandle;
    int returnStatus;
	
    gzFile theFile = NULL;
    voidp buf = NULL;
    unsigned bytesRead;
    int fd;
	
	// Set up the task.
	if (launchPath != nil) {
		[task setLaunchPath:launchPath];
	} else {
		[task release];
		if (error != nil) *error = [NSError errorWithDomain:iManEngineErrorDomain code:iManToolNotConfiguredError userInfo:nil];
		return nil;
	}
	
	[task setArguments:[NSArray arrayWithObjects:
						@"-Tutf8",		// UTF-8 grotty(1) output.
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
	
	if ((theFile = gzopen([[NSFileManager defaultManager] fileSystemRepresentationWithPath:path], "rb")) == nil) {
		// if errno == 0, memory allocation failed. Otherwise, errno contains the real error (file couldn't be opened)
		if (errno == 0)
			if (error != nil) *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:ENOMEM userInfo:nil];
		else
			if (error != nil) *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
		[task release];
		return nil;
	}
	if ((buf = malloc(4096)) == nil) {
		if (error != nil) *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:ENOMEM userInfo:nil];
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
	
	if (returnStatus != EXIT_SUCCESS) {
		[data release];
		data = nil;
		if (error != nil) *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:returnStatus userInfo:nil];
	}
	
	return data;
}

// This collection is quasi-macros makes the implementation of _attributedStringFromData: a lot less mind-boggling.
// Note that each checks whether the style tag it is examining *can* occur in the given space, and as such is safe to call without doing pointer arithmetic first.

static inline BOOL _hasStyle(unichar *buf, unichar *end)
{
	return (((buf + 2) < end) && (*(buf + 1) == 0x08));
}

static inline BOOL _hasBoldMarker(unichar *buf, unichar *end)
{
	return (((buf + 2) < end) && (*(buf + 1) == 0x08) && (*(buf + 2) == *buf));
}

static inline BOOL _hasAdditionalBoldMarker(unichar *buf, unichar *end)
{
	return (((buf + 1) < end) && (*buf == 0x08));
}

static inline BOOL _hasUnderlineMarker(unichar *buf, unichar *end) 
{
	return (((buf + 2) < end) && (*buf == '_') && (*(buf + 1) == 0x08) && (*(buf + 2) != '_'));
}

// FIXME: Underlined underscores look just like bolded ones. Do we need to care enough to heuristically guess which it should be?

- (NSAttributedString *)_attributedStringFromData:(NSData *)data error:(NSError **)error
{
	// This function converts the output of grotty(1) from old-style formatted ASCII
    // to an NSAttributedString, replacing the crude format codes with attributes.
	// The string returned is cacheable, no preference specific formatting. It must be
	// fed through -[iManPage pageWithStyle:] to add font/style info.
    NSMutableAttributedString *formattedString = [[NSMutableAttributedString alloc] init];
	NSString *string;
    NSDictionary *normalDictionary, *underlineDictionary, *boldDictionary, *boldUnderlineDictionary;
	unichar *buffer, *position, *end, thisStyleRun[128];
	NSUInteger positionInStyleRun = 0;
	unichar thisCharacter;
	enum {
		kNormalFont, kBoldFont = 0x01, kUnderlinedFont = 0x02, kBoldUnderlinedFont = kBoldFont | kUnderlinedFont
	} currentFont, thisCharacterFont;
	
    // Cache style dictionaries.
    underlineDictionary = [NSDictionary dictionaryWithObject:iManPageUnderlineStyle forKey:iManPageStyleAttributeName];
    boldDictionary = [NSDictionary dictionaryWithObject:iManPageBoldStyle forKey:iManPageStyleAttributeName];
	boldUnderlineDictionary = [NSDictionary dictionaryWithObject:iManPageBoldUnderlineStyle forKey:iManPageStyleAttributeName];
    normalDictionary = [NSDictionary dictionary];
	
	// The input data should just be UTF-8 with some backspace (0x08) characters thrown in. Get NSString to parse it for us.
	string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	if (string == nil) return nil;

	// Parsing requires so much lookahead that it is hard to do without a simple buffer. Get the data back out of our NSString in UTF-16 form. FIXME: this is a silly way to do encoding conversion.
	buffer = malloc(sizeof(unichar) * [string length]);
	[string getCharacters:buffer range:NSMakeRange(0, [string length])];
	end = buffer + [string length];
	position = buffer;
	[string release];
	
	currentFont = kNormalFont;
	
	while (position < end) {
		thisCharacterFont = kNormalFont;
		
		if (_hasStyle(position, end)) { 
			// This character has a style applied to it.
			if (_hasUnderlineMarker(position, end)) {
				// Underline (represented by _ 0x08 c)
				thisCharacter = *(position + 2);
				thisCharacterFont |= kUnderlinedFont;
				position += 3;
			} else if (_hasBoldMarker(position, end)) {
				// c 0x08 c
				thisCharacter = *position;
				thisCharacterFont |= kBoldFont;
				position += 3;
			}
			// Process any additional boldface markers. (as c 0x08 c 0x08 c or _ 0x08 c 0x08 c).
			while (_hasAdditionalBoldMarker(position, end)) {
				thisCharacterFont |= kBoldFont;
				position += 2;
			}
		} else {
			thisCharacter = *position;
			position++;
		}
		
		if ((thisCharacterFont != currentFont) || (positionInStyleRun == 127) || (position == end)) {
			// The buffer is full, or the character is the start of a new style run, or we're done and need to clear this style run.
			// Add the buffer to the page we're building and start a new one.
			NSDictionary *attributes;
			
			if (currentFont == kNormalFont) {
				attributes = normalDictionary;
			} else if (currentFont == kBoldFont) {
				attributes = boldDictionary;
			} else if (currentFont == kUnderlinedFont) {
				attributes = underlineDictionary;
			} else if (currentFont == kBoldUnderlinedFont) {
				attributes = boldUnderlineDictionary;
			}
			[formattedString appendAttributedString:[[[NSAttributedString alloc] initWithString:[NSString stringWithCharacters:thisStyleRun length:positionInStyleRun] attributes:attributes] autorelease]];
			
			// Add this character as the first character of the new style run.
			positionInStyleRun = 1;
			thisStyleRun[0] = thisCharacter;
			currentFont = thisCharacterFont;
		} else {
			// This character matches our current style run and fits in the buffer.
			thisStyleRun[positionInStyleRun] = thisCharacter;
			positionInStyleRun++;
		}
	}
	
	// We have converted the whole page into an attributed string.
    // Now, use RegexKitLite to find anything that looks like a page reference and add a link.
    // Pattern for link matching: ([^[:space:](]+)\(([0-9n][a-zA-Z]*)\)
    
	{
        NSEnumerator *results;
		NSString *searchText = [formattedString string];
		NSValue *match;
		NSString *regex = @"([^[:space:](]+)\\(([0-9n][a-zA-Z]*)\\)";
		
        results = [searchText matchEnumeratorWithRegex:regex options:RKLNoOptions | RKLMultiline];
		
		
		for (match in results) {
			NSRange range = [match rangeValue];
			NSString *matchString = [searchText substringWithRange:range];
			NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"man://%@/%@", [matchString stringByMatching:regex capture:1], [matchString stringByMatching:regex capture:2]]];
			
			if (url != nil)
				[formattedString addAttribute:iManPageLinkAttributeName value:url range:range];
        }
    }
	
    return [formattedString autorelease];
}

- (NSString *)path
{
	return _path;
}

- (NSAttributedString *)page
{
	if ([self isFinished])
		return _page;
}

- (NSError *)error
{
	return _error;
}

- (void)dealloc
{
	[_error release];
	[_path release];
	[_page release];
	[super dealloc];
}

@end	
