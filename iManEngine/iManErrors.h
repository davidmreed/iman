//
//  iManErrors.h
//  iManEngine
//  Copyright (c) 2009 by David Reed, distributed under the BSD License.
//  see iman-macosx.sourceforge.net for details.
//

#import <Cocoa/Cocoa.h>

extern NSString *const iManErrorKey;
extern NSString *const iManEngineErrorDomain;

enum {
	iManToolNotConfiguredError = 1,
	iManInternalInconsistencyError,
	iManIndexLockedError,
	iManResolveFailedError,
	iManRenderFailedError
};
