//
// iManEnginePreferences.h
// iMan
// Copyright (c) 2006 by David Reed, distributed under the BSD License.
// see iman-macosx.sourceforge.net for details.
//

#import <Cocoa/Cocoa.h>

/*!
 @class iManEnginePreferences
 @abstract Interface to engine-specific configuration.
 @discussion iManEnginePreferences is a singleton class that provides an interface to the engine framework's configuration. This class is thread-safe.
 */

@interface iManEnginePreferences : NSObject {

}

/*!
 @method sharedInstance
 @abstract Returns the singleton instance.
 */
+ sharedInstance;

/*!
 @method tools
 @abstract Returns an NSArray of the names of the command-line tools the engine needs.
 */
- (NSArray *)tools;
/*!
 @method pathForTool:
 @abstract Returns the currently set path for the given tool, or the default if none.
 */
- (NSString *)pathForTool:(NSString *)tool;
/*!
 @method setPath:forTool:
 @abstract Sets the current path for the given tool.
 */
- (void)setPath:(NSString *)path forTool:(NSString *)tool;

/*!
 @method manpaths
 @abstract Returns an NSArray of NSStrings containing the value for MANPATH.
 */
- (NSArray *)manpaths;
/*!
 @method setManpaths:
 @abstract Sets the value for MANPATH.
 */
- (void)setManpaths:(NSArray *)manpaths;
/*!
 @method manpathsForTools
 @abstract Returns the actual colon-separated MANPATH.
 */
- (NSString *)manpathsForTools;

@end
