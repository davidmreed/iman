//
//  iManHistoryQueue.h
//  iMan
//
//  Created by David Reed on 5/23/10.
//  Copyright 2010 David Reed. All rights reserved.
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
