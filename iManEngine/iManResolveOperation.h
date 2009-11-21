//
//  iManResolveOperation.h
//  iManEngine
//
//  Created by David Reed on 11/20/09.
//  Copyright 2009 David Reed. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface iManResolveOperation : NSOperation {
	NSString *_name;
	NSString *_section;
	NSString *_path;
}

- initWithName:(NSString *)name section:(NSString *)section;

- (NSString *)path;

@end
