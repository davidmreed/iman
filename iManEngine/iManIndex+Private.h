//
//  iManIndex+Private.h
//  iManEngine
//  Copyright (c) 2006-2009 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import <Cocoa/Cocoa.h>
#import "iManIndex.h"

@interface iManIndex (Private)

- (NSString *)indexPath;
- (iManRWLock *)lock;

@end

extern NSOperationQueue *_iManSearchQueue;