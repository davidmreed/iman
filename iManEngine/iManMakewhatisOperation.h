//
//  iManMakewhatisOperation.h
//  iManEngine
//
//  Created by David Reed on 12/17/09.
//  Copyright 2009 David Reed. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface iManMakewhatisOperation : NSOperation {
	NSError *_error;
	NSString *_path;
}

- initWithPath:(NSString *)path;
- (NSError *)error;
- (NSString *)path;

@end
