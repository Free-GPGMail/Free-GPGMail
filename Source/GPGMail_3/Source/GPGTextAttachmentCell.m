//
//  GPGTextAttachmentCell.m
//  GPGMail
//
//  Created by Lukas Pitschl on 31.07.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "GPGTextAttachmentCell.h"
#import "GPGMailBundle.h"

@implementation GPGTextAttachmentCell

- (BOOL)wantsToTrackMouse {
	// Apparently, Mavericks wants YES here. Mountain Lion and older wants NO.
	// Well... whatever.
	if([GPGMailBundle isMavericks])
		return YES;
	else
		return NO;
}

@end
