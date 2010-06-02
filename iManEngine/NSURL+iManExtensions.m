//
//  NSURL+iManExtensions.m
//  iManEngine
//  Copyright (c) 2004-2010 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import "NSURL+iManExtensions.h"
#import "RegexKitLite.h"

// grohtml style: man://groff/1. Regex: \/{0,2}([^[:space:]/]+)\/([0-9n][a-zA-Z]*)\/? 
static NSString *const grohtmlStyleURL = @"\\/{0,2}([^[:space:]/]+)\\/([0-9n][a-zA-Z]*)\\/?";
// The old iMan style: man:groff(1). Regex: ([^[:space:](]+)\(([0-9n][a-zA-Z]*)\)
static NSString *const iManStyleURL = @"([^[:space:](]+)\\(([0-9a-zA-Z]+)\\)";
// x-man-page: style: x-man-page://1/groff. Regex: \/{0,2}([0-9n][a-zA-Z]*)\/([^[:space:]/]+)\/?
static NSString *const xmanpageStyleURL = @"\\/{0,2}([0-9n][a-zA-Z]*)\\/([^[:space:]/]+)\\/?";
// grohtml style without section, which may come in (for instance) from our command line tool.
static NSString *const grohtmlStyleURLNoSection = @"\\/{0,2}([^[:space:]/]+)\\/?";


@implementation NSURL (iManExtensions)

- (BOOL)isManURL;
{
	NSString *name = nil, *section = nil;
	NSString *manpage = [[self resourceSpecifier] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	
	return (([[self scheme] isEqualToString:@"man"] || [[self scheme] isEqualToString:@"x-man-page"]) &&
			([manpage isMatchedByRegex:grohtmlStyleURL] ||
			 [manpage isMatchedByRegex:iManStyleURL] ||
			 [manpage isMatchedByRegex:xmanpageStyleURL] ||
			 [manpage isMatchedByRegex:grohtmlStyleURLNoSection]));
}

- (NSString *)pageName
{
	NSString *manpage = [[self resourceSpecifier] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

	if ([manpage isMatchedByRegex:grohtmlStyleURL]) {
		// It's a URL of the format man://groff/1 (as used by grohtml(1))
		return [manpage stringByMatching:grohtmlStyleURL capture:1];
	} else if ([manpage isMatchedByRegex:iManStyleURL]) {
		// It's a URL of the format man:groff(1) (as used by earlier versions of iMan).
		return [manpage stringByMatching:iManStyleURL capture:1];
	} else if ([manpage isMatchedByRegex:xmanpageStyleURL]) {
		// It's a URL of the format x-man-page://1/groff
		return [manpage stringByMatching:xmanpageStyleURL capture:2];
	} else if ([manpage isMatchedByRegex:grohtmlStyleURLNoSection]) {
		// It's a URL of the format man://groff
		return [manpage stringByMatching:grohtmlStyleURLNoSection capture:1];
	}
	
	return nil;
}

- (NSString *)pageSection
{
	NSString *manpage = [[self resourceSpecifier] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

	if ([manpage isMatchedByRegex:grohtmlStyleURL]) {
		// It's a URL of the format man://groff/1 (as used by grohtml(1))
		return [manpage stringByMatching:grohtmlStyleURL capture:2];
	} else if ([manpage isMatchedByRegex:iManStyleURL]) {
		// It's a URL of the format man:groff(1) (as used by earlier versions of iMan).
		return [manpage stringByMatching:iManStyleURL capture:2];
	} else if ([manpage isMatchedByRegex:xmanpageStyleURL]) {
		// It's a URL of the format (x-man-page:)//1/groff
		return [manpage stringByMatching:xmanpageStyleURL capture:1];
	} else if ([manpage isMatchedByRegex:grohtmlStyleURLNoSection]) {
		// It's a URL of the format man://groff
		return nil;
	}
	
	return nil;
}	

@end
