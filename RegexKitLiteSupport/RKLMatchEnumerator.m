#import <Foundation/NSArray.h>
#import <Foundation/NSRange.h>
#import "RegexKitLite.h"
#import "RKLMatchEnumerator.h"

// Note. This file has been modified from the original packaged with RegexKitLite. -nextObject now returns an NSValue object containing the matched range rather than the matched string.

@interface RKLMatchEnumerator : NSEnumerator {
	NSString   *string;
	NSString   *regex;
	NSUInteger  location;
	RKLRegexOptions options;
}

- (id)initWithString:(NSString *)initString regex:(NSString *)initRegex options:(RKLRegexOptions)initOptions;

@end

@implementation RKLMatchEnumerator

- (id)initWithString:(NSString *)initString regex:(NSString *)initRegex options:(RKLRegexOptions)initOptions
{
	if (self = [self init]) {
		string = [initString copy];
		regex  = [initRegex copy];
		options = initOptions;
	}
	
	return self;
}

- (id)nextObject
{
	if (location != NSNotFound) {
		NSRange searchRange  = NSMakeRange(location, [string length] - location);
		NSRange matchedRange = [string rangeOfRegex:regex options:options inRange:searchRange capture:0 error:NULL];
		
		location = NSMaxRange(matchedRange) + ((matchedRange.length == 0) ? 1 : 0);
		
		if (matchedRange.location != NSNotFound) {
			return [NSValue valueWithRange:matchedRange];
		}
	}
	return nil;
}

- (void) dealloc
{
	[string release];
	[regex release];
	[super dealloc];
}

@end

@implementation NSString (RegexKitLiteEnumeratorAdditions)

- (NSEnumerator *)matchEnumeratorWithRegex:(NSString *)regex options:(RKLRegexOptions)options
{
	return ([[[RKLMatchEnumerator alloc] initWithString:self regex:regex options:options] autorelease]);
}

- (NSEnumerator *)matchEnumeratorWithRegex:(NSString *)regex
{
	return [self matchEnumeratorWithRegex:regex options:RKLNoOptions];
}

@end
