//
//  iManRenderOperation.m
//  iManEngine
//
//  Created by David Reed on 11/20/09.
//  Copyright 2009 David Reed. All rights reserved.
//

#import "iManRenderOperation.h"
#import "iManResolveOperation.h"
#import "NSTask+iManExtensions.h"
#import "iManEnginePreferences.h"
#import "iManPage.h"
#import "RegexKitLite.h"
#import "RKLMatchEnumerator.h"
#import <zlib.h>

@interface iManRenderOperation (Private)

- (NSData *)_renderedDataFromPath:(NSString *)path;
- (NSData *)_renderedDataFromGzippedPath:(NSString *)path;
- (NSAttributedString *)_attributedStringFromData:(NSData *)data;

@end


@implementation iManRenderOperation

- (iManRenderOperation *)initWithPath:(NSString *)path
{
	self = [super init];
	
	if (self != nil)
		_path = [path copy];
	
	return self;
}

- (iManRenderOperation *)initWithName:(NSString *)name section:(NSString *)section
{
	self = [super init];
	
	if (self != nil) {
		[self addDependency:[[[iManResolveOperation alloc] initWithName:name section:section] autorelease]];
	}
	
	return self;
}

- (void)main
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	if (_path == nil) {
		_path = [[[self dependencies] lastObject] path];
	}
	if (_path != nil) 
		_page = [[self _attributedStringFromData:[self _renderedDataFromPath:[self path]]] retain];
	
	[pool release];
}

- (NSData *)_renderedDataFromPath:(NSString *)path
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
    NSData *data = nil;
	NSFileHandle *readHandle;
    int returnStatus;
	
    gzFile theFile = NULL;
    voidp buf = NULL;
    unsigned bytesRead;
    int fd;
	
	@try{
		// Set up the task.
		if (launchPath != nil) {
			[task setLaunchPath:launchPath];
		} else {
			[NSException raise:NSInternalInconsistencyException format:@"Tool path missing"];
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
							  "rb")) == nil)
			[NSException raise:NSGenericException format:@"gzopen failed"];
		if ((buf = malloc(4096)) == nil)
			[NSException raise:NSGenericException format:@"malloc failed"];
		
		[task launch];
		fd = [[input fileHandleForWriting] fileDescriptor];    
		readHandle = [output fileHandleForReading];
		
		while ((bytesRead = gzread(theFile, buf, 4096)) > 0) {
			write(fd, buf, bytesRead); // send it on to groff.
		}
		
		[[input fileHandleForWriting] closeFile];
		
		data = [readHandle readDataToEndOfFile];
		[task waitUntilExit];
		
		returnStatus = [task terminationStatus];
	
		if (returnStatus != EXIT_SUCCESS) {
			[NSException raise:NSGenericException format:@"groff returned nonzero exit code %d", returnStatus];	
			[data release];
			data = nil;
		}
	} @catch (NSException *e) {
		NSLog(@"An error occurred while attempting to render %@. The error is: \"%s\"", [self path], [e reason]);
		return nil;
	} @finally {
		[task release];
		if (theFile != NULL)
			gzclose(theFile);
	}
	
	return data;
}

- (NSAttributedString *)_attributedStringFromData:(NSData *)data
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

- (NSString *)path
{
	return _path;
}

- (NSAttributedString *)page
{
	if ([self isFinished])
		return _page;
}

- (void)dealloc
{
	[_path release];
	[_page release];
	[super dealloc];
}

@end
