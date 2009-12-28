//
//  NSTask+iManExtensions.m
//  iManEngine
//  Copyright (c) 2006-2009 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import "NSTask+iManExtensions.h"
#import "iManEnginePreferences.h"
#import "iManErrors.h"

@implementation NSTask (iManExtensions)

+ (NSData *)invokeTool:(NSString *)tool
             arguments:(NSArray *)arguments
           environment:(NSDictionary *)environment
				 error:(NSError **)returnedError
{
    NSTask *task = [[NSTask alloc] init];
    NSPipe *output = [NSPipe pipe];
    NSString *launchPath = [[iManEnginePreferences sharedInstance] pathForTool:tool];
    NSData *data = nil;
	NSError *err;
    int returnStatus;

    if (launchPath != nil) {
        [task setLaunchPath:launchPath];
    } else {
        [task release];
		if (returnedError != nil)
			*returnedError = [NSError errorWithDomain:iManEngineErrorDomain code:iManToolNotConfiguredError userInfo:nil];
        return nil;
    }
    if (arguments != nil)
        [task setArguments:arguments];
    if (environment != nil)
        [task setEnvironment:environment];

    [task setStandardOutput:output];
    [task setStandardError:[NSFileHandle fileHandleWithNullDevice]];

    [task launch];
    data = [[output fileHandleForReading] readDataToEndOfFile];
    [task waitUntilExit];

    returnStatus = [task terminationStatus];
    [task release];

    if (returnStatus == EXIT_SUCCESS) {
		if (returnedError != nil)
			*returnedError = nil;
		return data;
    } else {
		if (returnedError != nil)
			*returnedError = [NSError errorWithDomain:NSPOSIXErrorDomain code:returnStatus userInfo:nil];
        return nil;
	}
}

@end
