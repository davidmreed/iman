//
//  iManErrors.h
//  iManEngine
//
//  Created by David Reed on 12/16/09.
//  Copyright 2009 David Reed. All rights reserved.
//

#import <Cocoa/Cocoa.h>

extern NSString *const iManErrorKey;
extern NSString *const iManEngineErrorDomain;

enum {
	iManToolNotConfiguredError = 1,
	iManInternalInconsistencyError,
	iManIndexLockedError
};
