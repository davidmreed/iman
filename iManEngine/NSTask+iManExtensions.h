//
// NSTask+iManExtensions.h
// iMan
// Copyright (c) 2006 by David Reed, distributed under the BSD License.
// see iman-macosx.sourceforge.net for details.
//

#import <Foundation/Foundation.h>

@interface NSTask (iManExtensions)

+ (NSData *)invokeTool:(NSString *)tool
             arguments:(NSArray *)arguments
           environment:(NSDictionary *)environment
				 error:(NSError **)returnedError;

@end
