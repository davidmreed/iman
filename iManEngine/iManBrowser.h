//
//  iManBrowser.h
//  iManEngine
//
//  Created by David Reed on 5/18/10.
//  Copyright 2010 David Reed. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface iManBrowser : NSObject {
	NSArray *_manpaths;
}

- init;
- initWithManpaths:(NSArray *)paths;

- (NSArray *)manpaths;
- (NSArray *)categories;
- (NSArray *)pagesInCategory:(NSString *)category underManpath:(NSString *)manpath;
- (NSArray *)pagesinCategory:(NSString *)category;

@end
