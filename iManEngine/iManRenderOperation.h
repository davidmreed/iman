//
//  iManRenderOperation.h
//  iManEngine
//  Copyright (c) 2009 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import <Cocoa/Cocoa.h>


@interface iManRenderOperation : NSOperation {
	NSString *_path;
	NSError *_error;
	BOOL _pendingResolution;
	NSAttributedString *_page;
}

- (iManRenderOperation *)initWithPath:(NSString *)path;
- (iManRenderOperation *)initWithDeferredPath;

- (NSString *)path;
- (NSAttributedString *)page;
- (NSError *)error;

@end
