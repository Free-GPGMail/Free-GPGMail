//
//  OptionalView+GPGMail.m
//  GPGMail
//
//  Created by Lukas Pitschl on 31.07.11.
//  Copyright 2013 GPGTools. All rights reserved.
//

#import <Libmacgpg/Libmacgpg.h>
#import "NSObject+LPDynamicIvars.h"
#import "OptionalView+GPGMail.h"

@implementation OptionalView_GPGMail

- (double)MAWidthIncludingOptionSwitch:(BOOL)includeOptionSwitch {
	double width;
	if ([[self getIvar:@"AdjustedWidth"] boolValue]) {
		width = self.frame.size.width;
		if (!includeOptionSwitch) {
			width -= 22;
		}
	} else {
		width = [self MAWidthIncludingOptionSwitch:includeOptionSwitch];
	}

	return width;
}


@end
