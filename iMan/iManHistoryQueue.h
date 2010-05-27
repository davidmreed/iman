//
//  iManHistoryQueue.h
//  iMan
//  Copyright (c) 2004-2010 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import <Cocoa/Cocoa.h>

@class iManPage;

@interface iManHistoryQueue : NSObject {
	NSMutableArray *_history;
	NSInteger _index;
}

- (NSArray *)history;
- (NSInteger)historyIndex;

- (iManPage *)back;
- (iManPage *)forward;

- (BOOL)canGoBack;
- (BOOL)canGoForward;

- (void)push:(iManPage *)page;

- (void)clearHistory;

@end
