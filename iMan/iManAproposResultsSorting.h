//
//  iManAproposResultsSorting.h
//  iMan
//  Copyright (c) 2006-2009 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import <Cocoa/Cocoa.h>

// This category is for sorting the results of an apropos/whatis search,
// where one result might have many names. The results are stored in a
// dictionary whose keys are either arrays of names or simply strings.
// This category sorts that list, by sorting arrays as their first
// element would be sorted (it is guaranteed to be a string).

@interface NSObject (iManSorting)

- (NSComparisonResult)iManResultSort:(id)other;

@end