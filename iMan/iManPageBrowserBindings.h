//
//  iManPageBrowserBindings.h
//  iMan
//  Copyright (c) 2004-2011 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import <Cocoa/Cocoa.h>
#import <iManEngine/iManSection.h>

@protocol iManPageBrowserBindings

- (BOOL)iManPageBrowserIsLeaf;
- (NSArray *)iManPageBrowserContents;
- (NSString *)iManPageBrowserTitle;

@end

@interface iManSection (iManPageBrowser) <iManPageBrowserBindings>
@end

@interface NSString (iManPageBrowser) <iManPageBrowserBindings>
@end