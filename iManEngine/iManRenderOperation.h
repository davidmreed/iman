//
//  iManRenderOperation.h
//  iManEngine
//
//  Created by David Reed on 11/20/09.
//  Copyright 2009 David Reed. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface iManRenderOperation : NSOperation {
	NSString *_path;
	NSAttributedString *_page;
}

- (iManRenderOperation *)initWithPath:(NSString *)path;
- (iManRenderOperation *)initWithName:(NSString *)name section:(NSString *)section;

- (NSString *)path;
- (NSAttributedString *)page;

@end
