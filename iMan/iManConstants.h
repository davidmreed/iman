//
// iManConstants.h
// iMan
// Copyright (c) 2006 by David Reed, distributed under the BSD License.
// see iman-macosx.sourceforge.net for details.
//

#import <Foundation/Foundation.h>

extern NSString *const iManPageFont;
extern NSString *const iManFontChangedNotification;
extern NSString *const iManEmphasizedStyle;
extern NSString *const iManBoldStyle;

extern NSString *const iManShowPageLinks;
extern NSString *const iManHandlePageLinks;
extern NSString *const iManHandleExternalLinks;
extern NSString *const iManHandleSearchResults;

enum {
    k_iManHandleLinkInCurrentWindow = 0,
    k_iManHandleLinkInNewWindow
};
