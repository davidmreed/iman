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
	BOOL _pendingResolution;
	NSAttributedString *_page;
}

- (iManRenderOperation *)initWithPath:(NSString *)path;
- (iManRenderOperation *)initWithDeferredPath;

- (NSString *)path;
- (NSAttributedString *)page;

@end
