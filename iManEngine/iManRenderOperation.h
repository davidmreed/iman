//
//  iManRenderOperation.h
//  iManEngine
//  Copyright (c) 2004-2010 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import <Cocoa/Cocoa.h>


@interface iManRenderOperation : NSOperation {
	NSString *_path;
	NSError *_error;
	NSAttributedString *_page;
}

- (iManRenderOperation *)initWithPath:(NSString *)path;

- (NSString *)path;
- (NSAttributedString *)page;
- (NSError *)error;

@end
