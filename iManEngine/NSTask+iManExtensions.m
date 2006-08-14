//
// NSTask+iManExtensions.m
// iMan
// Copyright (c) 2006 by David Reed, distributed under the BSD License.
// see iman-macosx.sourceforge.net for details.
//

#import "NSTask+iManExtensions.h"
#import "iManEnginePreferences.h"

@implementation NSTask (iManExtensions)

+ (NSData *)invokeTool:(NSString *)tool
             arguments:(NSArray *)arguments
           environment:(NSDictionary *)environment
{
    NSTask *task = [[NSTask alloc] init];
    NSPipe *output = [NSPipe pipe];
    NSString *launchPath = [[iManEnginePreferences sharedInstance] pathForTool:tool];
    NSData *data;
    int returnStatus;


    if (launchPath != nil) {
        [task setLaunchPath:launchPath];
    } else {
        [task release];
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

    if (returnStatus == EXIT_SUCCESS)
        return data;
    else
        return nil;
}

@end
