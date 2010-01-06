//
//  iManResolveOperation.h
//  iManEngine
//  Copyright (c) 2009 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import <Cocoa/Cocoa.h>


@interface iManResolveOperation : NSOperation {
	NSString *_name;
	NSString *_section;
	NSString *_path;
	NSError *_error;
}

- initWithName:(NSString *)name section:(NSString *)section;

- (NSString *)path;
- (NSError *)error;

@end
