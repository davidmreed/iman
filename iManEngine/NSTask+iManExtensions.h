//
//  NSTask+iManExtensions.h
//  iManEngine
//  Copyright (c) 2006-2009 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import <Foundation/Foundation.h>

@interface NSTask (iManExtensions)

+ (NSData *)invokeTool:(NSString *)tool
             arguments:(NSArray *)arguments
           environment:(NSDictionary *)environment
				 error:(NSError **)returnedError;

@end
