//
//  NSUserDefaults+DMRArchiving.m
//  iMan
//  Copyright (c) 2004-2009 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import "NSUserDefaults+DMRArchiving.h"


@implementation NSUserDefaults (DMRArchiving)

- (void)setArchivedObject:(id <NSCoding>)object forKey:(NSString *)key
{
    [self setObject:[NSArchiver archivedDataWithRootObject:object] forKey:key];
}

- (id)archivedObjectForKey:(NSString *)key
{
    id obj = [self objectForKey:key];

    if ((obj != nil) && ([obj isKindOfClass:[NSData class]]))
        return [NSUnarchiver unarchiveObjectWithData:obj];

    return obj;
}

@end
