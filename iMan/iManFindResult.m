//
//  iManFindResult.m
//  iMan
//  Copyright (c) 2004-2010 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import "iManFindResult.h"
#import <iManEngine/iManPage.h>
#import "iManConstants.h"
#import "NSUserDefaults+DMRArchiving.h"

@implementation iManFindResult

static NSAttributedString *_iManFindResultEllipses;
static NSAttributedString *_iManFindResultNewlineReplacementCharacter;

+ (void)initialize
{
	unichar character;
	
	character = 0x2026; // Unicode HORIZONTAL ELLIPSIS MARK (option-semicolon)
	_iManFindResultEllipses = [[NSAttributedString alloc] initWithString:[NSString stringWithCharacters:&character length:1] attributes:[NSDictionary dictionaryWithObject:[NSColor disabledControlTextColor] forKey:NSForegroundColorAttributeName]];
	character = 0x23CE; // Unicode RETURN SYMBOL
	_iManFindResultNewlineReplacementCharacter = [[NSAttributedString alloc] initWithString:[NSString stringWithCharacters:&character length:1] attributes:[NSDictionary dictionaryWithObject:[NSColor disabledControlTextColor] forKey:NSForegroundColorAttributeName]];
}
	

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
	NSRange range = [self range];
	unsigned leftMargin, rightMargin, length, resLength;
	unichar theChar;
	const int marginSize = 10;
	
	if (_matchWithContext != nil)
		return _matchWithContext;
		
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
			[ret insertAttributedString:_iManFindResultEllipses atIndex:0];
	}
	
	if (NSMaxRange(range) < [_source length]) {
		theChar = [[_source string] characterAtIndex:NSMaxRange(range) + 1];
		if ((theChar != 0x000D) && (theChar != 0x000A))
			[ret appendAttributedString:_iManFindResultEllipses];
	}
	
	// Remove CR/LF & co.
	{
		NSCharacterSet *characterSet = [NSCharacterSet newlineCharacterSet];
		NSRange result;
		NSString *string = [ret string];
		
		result = [string rangeOfCharacterFromSet:characterSet];
		
		while (result.location != NSNotFound) {
			[ret replaceCharactersInRange:NSMakeRange(result.location, result.length)
					 withAttributedString:_iManFindResultNewlineReplacementCharacter];
			result = [string rangeOfCharacterFromSet:characterSet];
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
