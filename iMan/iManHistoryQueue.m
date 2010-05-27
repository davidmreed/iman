//
//  iManHistoryQueue.m
//  iMan
//  Copyright (c) 2004-2010 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import "iManHistoryQueue.h"
#import <iManEngine/iManPage.h>

@implementation iManHistoryQueue

- init
{
	self = [super init];
	if (self) {
		_history = [[NSMutableArray alloc] init];
		_index = -1;
	}
	
	return self;
}

- (NSArray *)history
{
	return [[_history copy] autorelease];
}

- (NSInteger)historyIndex
{
	return _index;
}

- (iManPage *)back
{
	if (_index > 0) {
		_index--;
		return [_history objectAtIndex:_index];
	}
	
	return nil;
}

- (iManPage *)forward
{
	if (_index < ([_history count] - 1)) {
		_index++;
		return [_history objectAtIndex:_index];
	}
	
	return nil;
}

- (BOOL)canGoBack
{
	return (_index > 0);
}

- (BOOL)canGoForward
{
	return (_index < ([_history count] - 1));
}

- (void)push:(iManPage *)page
{
	if ([self canGoForward])
		[_history removeObjectsInRange:NSMakeRange(_index + 1, [_history count] - _index - 1)];
	[_history addObject:page];
	_index++;
}

- (void)clearHistory
{
	[_history removeAllObjects];
	_index = -1;
}

- (void)dealloc
{
	[_history release];
	[super dealloc];
}

@end
