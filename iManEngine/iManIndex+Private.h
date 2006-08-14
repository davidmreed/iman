//
// iManIndex+Private.h
// iMan
// Copyright (c) 2006 by David Reed, distributed under the BSD License.
// see iman-macosx.sourceforge.net for details.
//

#import <Cocoa/Cocoa.h>
#import "iManIndex.h"

@interface iManIndex (Private)

- (NSString *)indexPath;
- (NSDistributedLock *)lock;

@end
