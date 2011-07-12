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

@interface iManFindResult (Notifications)

- (void)_pageStyleDidChange:(NSNotification *)notification;

@end


@implementation iManFindResult

static NSAttributedString *_iManFindResultEllipses;
static NSAttributedString *_iManFindResultNewlineReplacementCharacter;	

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
		
		// Initialize our shared replacement character objects. NOTE that this isn't exactly thread-safe.
		// This code is here rather than in +initialize because we need to run it after the user defaults have been registered, so that we can get the proper font to use from NSUserDefaults.
		if (_iManFindResultEllipses == nil) {
			unichar character;
			
			character = 0x2026; // Unicode HORIZONTAL ELLIPSIS MARK (option-semicolon)
			_iManFindResultEllipses = [[NSAttributedString alloc] initWithString:[NSString stringWithCharacters:&character length:1] attributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSColor disabledControlTextColor], NSForegroundColorAttributeName, [NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:iManDefaultStyle]], NSFontAttributeName, nil]];
			character = 0x23CE; // Unicode RETURN SYMBOL
			_iManFindResultNewlineReplacementCharacter = [[NSAttributedString alloc] initWithString:[NSString stringWithCharacters:&character length:1] attributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSColor disabledControlTextColor], NSForegroundColorAttributeName, [NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:iManDefaultStyle]], NSFontAttributeName, nil]];
		}
		// Register for notification, so that if the formatting of the underlying page changes so will our -matchWithContext
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_pageStyleDidChange:) name:iManStyleChangedNotification object:nil];
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
	NSCharacterSet *whiteSpace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	NSString *string = [_source string];
	NSRange newRange = [self range];
	unsigned leftMargin = 0, rightMargin = 0, spaces = 0, i;
	const int marginSize = 15, spaceThreshold = 2;
	
	if (_matchWithContext != nil)
		return _matchWithContext;
			
	// Find the left margin -- marginSize characters of context. Don't count any consecutive spaces past the second; we'll ellipsize them.
	while ((leftMargin < marginSize) && (newRange.location > 0)) {
		newRange.location--;
		newRange.length++;
		if ([whiteSpace characterIsMember:[string characterAtIndex:newRange.location]]) {
			spaces++;
			if (spaces <= spaceThreshold)
				leftMargin++;
		} else {
			leftMargin++;
			// After each space run which will be collapsed, subtract the difference between the threshold and the replacement string's length to compensate for the fact that the spaces were initially counted in the margin up to the threshold.
			if (spaces > spaceThreshold)
				leftMargin -= (spaceThreshold - [_iManFindResultEllipses length]);
			spaces = 0;
		}
	}
		
	// Do the same on the right margin.
	spaces = 0;
	while ((rightMargin < marginSize) && (NSMaxRange(newRange) < [string length])) {
		newRange.length++;
		if ([whiteSpace characterIsMember:[string characterAtIndex:NSMaxRange(newRange) - 1]]) {
			spaces++;
			if (spaces <= spaceThreshold)
				rightMargin++;
		} else {
			rightMargin++;
			if (spaces > spaceThreshold)
				rightMargin -= (spaceThreshold - [_iManFindResultEllipses length]);
			spaces = 0;
		}
		
	}
	ret = [[_source attributedSubstringFromRange:newRange] mutableCopy];
	
	// Highlight the find result in red.
	[ret addAttribute:NSForegroundColorAttributeName
				value:[NSColor redColor]
				range:NSMakeRange([self range].location - newRange.location, [self range].length)];
	
	// Go through and replace all instances of three or more spaces with " ... ".
	spaces = 0;
	for (i = 0; i < [ret length]; i++) {
		if ([[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:[[ret string] characterAtIndex:i]]) {
			spaces++;
		} else {
			// if we just ended reading a run of spaces.
			if (spaces > spaceThreshold) {
				int delta;
				
				[ret replaceCharactersInRange:NSMakeRange(i - spaces, spaces) withAttributedString:_iManFindResultEllipses];
				delta = (spaces - [_iManFindResultEllipses length]);
				i -= delta;
				newRange.length -= delta;
			}
			spaces = 0;
		}
	}
	
	// Add ellipses if not at beginning/end of line (unless our result already begins with an ellipsis).
	if ((newRange.location > 0) && ![[NSCharacterSet newlineCharacterSet] characterIsMember:[string characterAtIndex:newRange.location - 1]] && ![string hasPrefix:[_iManFindResultEllipses string]]) {
		[ret insertAttributedString:_iManFindResultEllipses atIndex:0];
	}
	
	if ((NSMaxRange(newRange) < [string length]) && ![[NSCharacterSet newlineCharacterSet] characterIsMember:[string characterAtIndex:NSMaxRange(newRange)]] && ![string hasPrefix:[_iManFindResultEllipses string]]) {
		[ret appendAttributedString:_iManFindResultEllipses];
	}
	
	// Replace CR/LF & co.
	{
		NSCharacterSet *characterSet = [NSCharacterSet newlineCharacterSet];
		NSRange result;
		NSString *retString = [ret string];
		
		result = [retString rangeOfCharacterFromSet:characterSet];
		
		while (result.location != NSNotFound) {
			[ret replaceCharactersInRange:result withAttributedString:_iManFindResultNewlineReplacementCharacter];
			result = [retString rangeOfCharacterFromSet:characterSet];
		}
	}
	
	_matchWithContext = [ret retain];
	
	return [ret autorelease];
}

- (void)_pageStyleDidChange:(NSNotification *)notification
{
	// Font information in the underlying page has been changed by the user.
	// Release our cached styled result; it will be regenerated automatically by -matchWithContext if needed.
	if (_matchWithContext != nil) {
		[_matchWithContext release];
		_matchWithContext = nil;
	}
}

- (void)dealloc
{
	[_source release];
	[_match release];
	[_matchWithContext release];
	[super dealloc];
}

@end
