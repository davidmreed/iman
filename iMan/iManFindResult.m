//
//  iManFindResult.m
//  iMan
//  Copyright (c) 2004-2010 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import "iManFindResult.h"
#import <CoreFoundation/CoreFoundation.h>
#import <iManEngine/iManPage.h>
#import "iManConstants.h"
#import "NSUserDefaults+DMRArchiving.h"

@implementation iManFindResult

+ findResultWithRange:(NSRange)range inAttributedString:(NSAttributedString *)string
{
	return [[[iManFindResult alloc] initWithRange:range inAttributedString:string] autorelease];
}

- initWithRange:(NSRange)range inAttributedString:(NSAttributedString *)string
{
	self = [super init];
	
	if (self) {
		_range = range;
		_source = [string retain];
		_match = [[[_source string] substringWithRange:_range] copy];
	}
	
	return self;
}

- (NSRange)range
{
	return _range;
}

- (NSString *)match
{
	return _match;
}

- (NSAttributedString *)matchWithContext
{
	NSMutableAttributedString *ret;
	static NSAttributedString *greyEllipses;
	NSRange range = [self range];
	unsigned leftMargin, rightMargin, length, resLength;
	unichar theChar;
	const int marginSize = 10;
	
	if (_matchWithContext != nil)
		return _matchWithContext;
	
	if (greyEllipses == nil)
		greyEllipses = [[NSAttributedString alloc] initWithString:NSLocalizedString(@"...", nil)
													   attributes:[NSDictionary dictionaryWithObject:[NSColor disabledControlTextColor] forKey:NSForegroundColorAttributeName]];
	
	resLength = range.length;
	length = [[_source string] length];
	
	if (range.location < marginSize) {
		leftMargin = range.location;
		range.length += range.location;
		range.location = 0;
	} else {
		leftMargin = marginSize;
		range.length += marginSize;
		range.location -= marginSize;
	}
	
	rightMargin = MIN(marginSize, length - NSMaxRange(range));
	range.length += rightMargin;
	
	ret = [[_source attributedSubstringFromRange:range] mutableCopy];
	
	// Highlight the find result in red.
	[ret addAttribute:NSForegroundColorAttributeName
				value:[NSColor redColor]
				range:NSMakeRange(leftMargin, resLength)];
	
	// Add ellipses if not at beginning/end of line.
	if (range.location > 0) {
		theChar = [[_source string] characterAtIndex:range.location - 1];
		if ((theChar != 0x000D) && (theChar != 0x000A))
			[ret insertAttributedString:greyEllipses atIndex:0];
	}
	
	if (NSMaxRange(range) < [_source length]) {
		theChar = [[_source string] characterAtIndex:NSMaxRange(range) + 1];
		if ((theChar != 0x000D) && (theChar != 0x000A))
			[ret appendAttributedString:greyEllipses];
	}
	
	// Use CF functions to remove CR/LF & co.
	{
		CFCharacterSetRef characters = CFCharacterSetGetPredefined(kCFCharacterSetWhitespaceAndNewline);
		CFRange range = CFRangeMake(0, [ret length]), result;
		CFStringRef stringRef = (CFStringRef)[ret string];
		NSRange junk;
		
		while (CFStringFindCharacterFromSet(stringRef, characters, range, 0, &result)) {
			NSAttributedString *repl = [[NSAttributedString alloc] initWithString:@" " attributes:[ret attributesAtIndex:result.location effectiveRange:&junk]];
			[ret replaceCharactersInRange:NSMakeRange(result.location, result.length)
					 withAttributedString:repl];
			[repl release];
			range = CFRangeMake(result.location + 1, [ret length] - (result.location + 1));
		}
	}
	
	_matchWithContext = [ret retain];
	
	return [ret autorelease];
}

- (void)dealloc
{
	[_source release];
	[_match release];
	[_matchWithContext release];
	[super dealloc];
}

@end
