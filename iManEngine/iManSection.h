//
//  iManSection.h
//  iManEngine
//  Copyright (c) 2004-2011 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.

#import <Cocoa/Cocoa.h>


@interface iManSection : NSObject <NSCoding> {
	NSString *name;
	NSMutableArray *subsections;
	NSMutableArray *pages;
}

- initWithName:(NSString *)aName;

@property (readonly) NSString *name;
@property (readwrite, copy) NSMutableArray *subsections;
@property (readwrite, copy) NSMutableArray *pages;
@property (readonly) NSArray *contents;

@end
