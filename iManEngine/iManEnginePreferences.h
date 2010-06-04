//
//  iManEnginePreferences.h
//  iMan
//  Copyright (c) 2004-2010 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import <Cocoa/Cocoa.h>

/*!
 @class iManEnginePreferences
 @abstract Interface to engine-specific configuration.
 @discussion iManEnginePreferences is a singleton class that provides an interface to the engine framework's configuration. This class is thread-safe, as it covers on NSUserDefaults
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
- (NSString *)manpathString;

- (BOOL)useDiskCache;
- (void)setUseDiskCache:(BOOL)diskCache;
- (BOOL)useMemoryCache;
- (void)setUseMemoryCache:(BOOL)memCache;


@end

extern NSString *const iManEngineManpaths;
extern NSString *const iManEngineToolPathMan;
extern NSString *const iManEngineToolPathGroff;
extern NSString *const iManEngineToolPathMakewhatis;
extern NSString *const iManEngineUseDiskCache;
extern NSString *const iManEngineUseMemoryCache;