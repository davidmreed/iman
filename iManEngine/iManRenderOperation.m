//
//  iManRenderOperation.m
//  iManEngine
//  Copyright (c) 2004-2010 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import "iManRenderOperation.h"
#import "NSTask+iManExtensions.h"
#import "iManEnginePreferences.h"
#import "iManPage.h"
#import "iManErrors.h"
#import "RegexKitLite.h"
#import "RKLMatchEnumerator.h"
#import <zlib.h>

@interface iManRenderOperation (Private)

- (NSData *)_renderedDataFromPath:(NSString *)path error:(NSError **)error;
- (NSString *)_decompressPath:(NSString *)path error:(NSError **)error;
- (NSAttributedString *)_attributedStringFromData:(NSData *)data error:(NSError **)error;

@end

@implementation iManRenderOperation

- (iManRenderOperation *)initWithPath:(NSString *)path
{
	self = [super init];

	if (self != nil) {
		_path = [path copy];
		_error = nil;
	}
	
	return self;
}

- (void)main
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

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
		_error = [[NSError alloc] initWithDomain:iManEngineErrorDomain code:iManInternalInconsistencyError userInfo:nil];
	}
	
	[pool release];
}

- (NSData *)_renderedDataFromPath:(NSString *)path error:(NSError **)error
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *finalPath = path;
	NSData *ret;
	BOOL didDecompress = NO;
	
	// If we've been passed a gzipped path, decompress it to /tmp
	if ([[[path lastPathComponent] pathExtension] isEqualToString:@"gz"]) {
		finalPath = [self _decompressPath:path error:error];
		didDecompress = YES;
		if (finalPath == nil)
			return nil;
	}
	
	// Some pages consist only of the line ".so manX/page.X", which man(1) itself reads and dereferences. Duplicate that behavior.
	// Note: running soelim(1) is not the solution; it just says "file not found", and man itself doesn't anyway.
	NSDictionary *attributes = [fm attributesOfItemAtPath:finalPath error:NULL];
	if (attributes != nil) {
		// Only perform the check if the file is under 128 bytes in size (just a reasonable upper bound).
		if ([attributes fileSize] < 128) {
			NSData *data = [NSData dataWithContentsOfFile:finalPath];
			NSString *contents;
			
			contents = [fm stringWithFileSystemRepresentation:[data bytes] length:[data length]];
			if ([contents hasPrefix:@".so"]) {
				// Okay, we've got a .so redirection. The paths given are *weird*; they usually appear to be relative to the base manpath, not the current (section) directory. man(1) also checks the current directory and tries interpreting the string as a relative path (I *think*, the source is an awful mess). 
				NSMutableString *soPath = [[[contents substringFromIndex:3] mutableCopy] autorelease];
				NSString *newPath;
				NSArray *pathComponents, *originalPathComponents;
				
				CFStringTrimWhitespace((CFMutableStringRef)soPath);
				
				// See if we have an absolute path
				if (([soPath hasPrefix:@"/"]) && ([fm isReadableFileAtPath:soPath])) 
					return [self _renderedDataFromPath:soPath error:error];
				
				// See if we have the very common case where original path is .../manX/page.X[.gz] and file contains a line of the form .so manY/page.Y
				pathComponents = [soPath pathComponents];
				originalPathComponents = [path pathComponents];
				if (([originalPathComponents count] >= 2) && [[originalPathComponents objectAtIndex:[originalPathComponents count] - 2] hasPrefix:@"man"] && ([pathComponents count] == 2) && [[pathComponents objectAtIndex:0] hasPrefix:@"man"]) {
					newPath = [[[originalPathComponents subarrayWithRange:NSMakeRange(0, [originalPathComponents count] - 2)] arrayByAddingObjectsFromArray:pathComponents] componentsJoinedByString:@"/"];
					if ([fm isReadableFileAtPath:newPath]) {
						return [self _renderedDataFromPath:newPath error:error];
					} else if ([fm isReadableFileAtPath:[newPath stringByAppendingPathExtension:@"gz"]]) {
						return [self _renderedDataFromPath:[newPath stringByAppendingPathExtension:@"gz"] error:error];
					}
				}
				
				// See if we should just append this to the current path.
				newPath = [[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:soPath];
				if ([fm isReadableFileAtPath:newPath])
					return [self _renderedDataFromPath:newPath error:error];
				newPath = [newPath stringByAppendingPathExtension:@"gz"];
				if ([fm isReadableFileAtPath:newPath])
					return [self _renderedDataFromPath:newPath error:error];
				
				// Finally, try taking the last path component of the .so-path and looking for it in the directory containing the page.
				newPath = [[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:[soPath lastPathComponent]];
				if ([fm isReadableFileAtPath:newPath])
					return [self _renderedDataFromPath:newPath error:error];
				newPath = [newPath stringByAppendingPathExtension:@"gz"];
				if ([fm isReadableFileAtPath:newPath])
					return [self _renderedDataFromPath:newPath error:error];
				
				return nil;
			}
		}
	}
				
	ret = [NSTask invokeTool:@"groff"
				   arguments:[NSArray arrayWithObjects:
							   @"-Tutf8", // UTF-8 grotty(1) output
							   @"-P", // -P sends next argument to postprocessor
							   @"-c", // tells grotty to use old-style format codes
							   @"-S", // safe mode (on by default, just to be sure)
							   @"-t", // preprocess with tbl (man default).
							   @"-mandoc", // appropriate macro package
							   finalPath,
							   nil]
				  environment:nil
						error:error];
	if (didDecompress)
		[fm removeItemAtPath:finalPath error:nil];
	
	return ret;
}

- (NSString *)_decompressPath:(NSString *)path error:(NSError **)error
{
	// Decompress the gzipped file into /tmp and return the path of the decompressed file.
	char filename[] = "/tmp/iManXXXXXXXX";
	gzFile file = NULL;
	void *buffer;
	int fd, bytesRead;
	
	fd = mkstemp(&filename);
	if (fd == -1) {
		if (error != nil) *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
		return nil;
	}
	
	if ((file = gzopen([[NSFileManager defaultManager] fileSystemRepresentationWithPath:path], "rb")) == NULL) {
		// if errno == 0, memory allocation failed. Otherwise, errno contains the real error (file couldn't be opened)
		if (errno == 0) {
			if (error != nil) *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:ENOMEM userInfo:nil];
		} else {
			if (error != nil) *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
		}
		close(fd);
		unlink(filename);
		return nil;
	}
	if ((buffer = malloc(4096)) == nil) {
		if (error != nil) *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:ENOMEM userInfo:nil];
		gzclose(file);
		close(fd);
		unlink(filename);
		return nil;
	}
		
	while ((bytesRead = gzread(file, buffer, 4096)) > 0) {
		write(fd, buffer, bytesRead);
	}
	
	if (bytesRead == -1) { 
		// An error occured (0 means EOF). 
		if (error != NULL) {
			int errnum;
			const char *errorString = NULL;
			errorString = gzerror(file, &errnum);
			if (errnum == Z_ERRNO) errnum = errno;
			*error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errnum userInfo: ((errorString == NULL) ? nil : [NSDictionary dictionaryWithObject:[NSString stringWithCString:errorString encoding:NSASCIIStringEncoding] forKey:NSLocalizedDescriptionKey])];
		}
		return nil;
	}
	
	gzclose(file);
	close(fd);
	free(buffer);
	
	return [[NSFileManager defaultManager] stringWithFileSystemRepresentation:filename length:strlen(filename)];
}

// This collection of quasi-macros makes the implementation of _attributedStringFromData: a lot less mind-boggling.
// Note that each checks whether the style tag it is examining *can* occur in the given space, and as such is safe to call without doing pointer arithmetic first.

static inline BOOL _hasStyle(unichar *buf, unichar *end)
{
	return (((buf + 2) < end) && (*(buf + 1) == 0x08));
}

static inline BOOL _hasBoldMarker(unichar *buf, unichar *end)
{
	return (((buf + 2) < end) && (*(buf + 1) == 0x08) && (*(buf + 2) == *buf));
}

static inline BOOL _hasAdditionalBoldMarker(unichar *buf, unichar *end, unichar character)
{
	return (((buf + 1) < end) && (*buf == 0x08) && (*(buf + 1) == character));
}

static inline BOOL _hasUnderlineMarker(unichar *buf, unichar *end) 
{
	return (((buf + 2) < end) && (*buf == '_') && (*(buf + 1) == 0x08) && (*(buf + 2) != '_'));
}

static inline BOOL _hasSpuriousOverstriking(unichar *buf, unichar *end)
{
	return (_hasStyle(buf, end) && !_hasBoldMarker(buf, end) && !_hasUnderlineMarker(buf, end));
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

	// Parsing requires so much lookahead that it is hard to do without a simple buffer. Get the data back out of our NSString in UTF-16 form.
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
			} else {
				// Sometimes we see bizarre formatting that seems to just represent literal overstriking, as when the title of a page is so long as to overlap the name/section part of the header (most Perl module manpages are examples). Typically this will be something like c 0x08 y 0x08 x, where taking the final character of each sequence yields a more-or-less cogent result.
				while (_hasSpuriousOverstriking(position, end))
					position +=2;
				
				thisCharacter = *position;
				position++;
			}

			// Process any additional boldface markers. (as c 0x08 c 0x08 c or _ 0x08 c 0x08 c).
			while (_hasAdditionalBoldMarker(position, end, thisCharacter)) {
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
