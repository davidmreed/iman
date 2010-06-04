//
//  NSOperationQueue+iManEngine.m
//  iManEngine
//  Copyright (c) 2004-2010 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import "NSOperationQueue+iManEngine.h"


@implementation NSOperationQueue (iManEngine)

+ (NSOperationQueue *)iManEngineOperationQueue
{
	static NSOperationQueue *queue = nil;
	
	if (queue == nil) {
		queue = [[NSOperationQueue alloc] init];
	}
	
	return queue;
}

@end
