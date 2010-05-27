//
//  iManMakewhatisOperation.h
//  iManEngine
//  Copyright (c) 2004-2010 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
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
