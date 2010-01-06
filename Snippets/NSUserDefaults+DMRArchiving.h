//
//  NSUserDefaults+DMRArchiving.h
//  iMan
//  iMan
//  Copyright (c) 2004-2009 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import <Foundation/Foundation.h>


@interface NSUserDefaults (DMRArchiving)

- (void)setArchivedObject:(id <NSCoding>)object forKey:(NSString *)key;
- (id)archivedObjectForKey:(NSString *)key;

@end
