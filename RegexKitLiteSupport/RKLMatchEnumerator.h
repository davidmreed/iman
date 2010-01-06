#import <Foundation/NSEnumerator.h>
#import <Foundation/NSString.h>
#import <stddef.h>

// These files modified from original RKLMatchEnumerator.[hm] for the needs of iMan.

@interface NSString (RegexKitLiteEnumeratorAdditions)

- (NSEnumerator *)matchEnumeratorWithRegex:(NSString *)regex;
- (NSEnumerator *)matchEnumeratorWithRegex:(NSString *)regex options:(RKLRegexOptions)options;

@end
