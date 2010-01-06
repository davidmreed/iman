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
							   @"-Tascii", // ASCII output, UTF-8 doesn't work right now
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

- (NSAttributedString *)_attributedStringFromData:(NSData *)data error:(NSError **)error
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
	char cString[2] = "\0\0";
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
					cString[0] = *(char *)(bytes + index + 2);
                    [str appendAttributedString:
					 [[[NSAttributedString alloc] initWithString:[NSString stringWithCString:cString encoding:[NSString defaultCStringEncoding]] attributes:underlineDictionary] autorelease]];
                } else {
					cString[0] = *(char *)(bytes + index);
                    [str appendAttributedString:
					 [[[NSAttributedString alloc] initWithString:[NSString stringWithCString:cString encoding:[NSString defaultCStringEncoding]] attributes:boldDictionary] autorelease]];
                }
				
                index += 2;
            }
        } else {
			cString[0] = *(char *)(bytes + index);
            [str appendAttributedString:
			 [[[NSAttributedString alloc] initWithString:[NSString stringWithCString:cString encoding:[NSString defaultCStringEncoding]]
											  attributes:normalDictionary] autorelease]];
        }
    }
	
    // Now, use RegexKitLite to find anything that looks like a page reference and add a link.
    // Pattern for link matching: ([^[:space:](]+)\(([0-9n][a-zA-Z]*)\)
    
	{
        NSEnumerator *results;
		NSString *searchText = [str string];
		NSValue *match;
		NSString *regex = @"([^[:space:](]+)\\(([0-9n][a-zA-Z]*)\\)";
		
        results = [searchText matchEnumeratorWithRegex:regex options:RKLNoOptions | RKLMultiline];
		
		
		while ((match = [results nextObject]) != nil) {
            NSRange range = [match rangeValue];
			NSString *matchString = [searchText substringWithRange:range];
			NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"man://%@/%@", [matchString stringByMatching:regex capture:1], [matchString stringByMatching:regex capture:2]]];
			
			if (url != nil)
				[str addAttribute:iManPageLinkAttributeName
							value:url
							range:range];
        }
    }
	
	if (error != nil) *error = nil; // Currently formatting errors are just ignored.
    return [str autorelease];
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
