//
//  NSURL+iManExtensions.h
//  iManEngine
//  Copyright (c) 2004-2010 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import <Cocoa/Cocoa.h>


@interface NSURL (iManExtensions)

- (BOOL)isManURL;

- (NSString *)pageName;
- (NSString *)pageSection;

@end
