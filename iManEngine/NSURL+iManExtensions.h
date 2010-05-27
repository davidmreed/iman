//
//  NSURL+iManExtensions.h
//  iManEngine
//
//  Created by David Reed on 5/27/10.
//  Copyright 2010 David Reed. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSURL (iManExtensions)

- (BOOL)isManURL;

- (NSString *)pageName;
- (NSString *)pageSection;

@end
