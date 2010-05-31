//
//  iManConstants.h
//  iMan
//  Copyright (c) 2004-2010 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import <Foundation/Foundation.h>

extern NSString *const iManDefaultStyle;
extern NSString *const iManStyleChangedNotification;

extern NSString *const iManBoldStyleMakeBold;
extern NSString *const iManBoldStyleMakeItalic;
extern NSString *const iManBoldStyleMakeUnderline;
extern NSString *const iManBoldStyleColor;

extern NSString *const iManUnderlineStyleMakeBold;
extern NSString *const iManUnderlineStyleMakeItalic;
extern NSString *const iManUnderlineStyleMakeUnderline;
extern NSString *const iManUnderlineStyleColor;

extern NSString *const iManShowPageSelectionPanelForDuplicates;

extern NSString *const iManShowPageLinks;
extern NSString *const iManHandlePageLinks;
extern NSString *const iManHandleExternalLinks;
extern NSString *const iManHandleSearchResults;

enum {
    kiManHandleLinkInCurrentWindow = 0,
    kiManHandleLinkInNewWindow
};
