//
//  iManIndex+Private.h
//  iManEngine
//  Copyright (c) 2004-2010 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import <Cocoa/Cocoa.h>
#import "iManIndex.h"

@interface iManIndex (Private)

- (NSString *)indexPath;
- (iManRWLock *)lock;

@end