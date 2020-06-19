//
//  NSBezierPath_KBAdditions.h
//  --------------------------
//
//  Created by Keith Blount on 06/05/2006.
//  Copyright 2006 Keith Blount. All rights reserved.
//
//	Based on Andy Matuschak's PXRoundedRectangleAdditions, but with an added 'flipped' option.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

typedef enum KBCornerTypes
{
	KBTopLeftCorner = 1,
	KBTopRightCorner = 2,
	KBBottomLeftCorner = 4,
	KBBottomRightCorner = 8
} KBCornerType;

@interface NSBezierPath (KBAdditions)
+ (NSBezierPath *)bezierPathWithRoundedRect:(NSRect)aRect cornerRadius:(float)radius;
+ (NSBezierPath *)bezierPathWithRoundedRect:(NSRect)aRect
								  inCorners:(KBCornerType)corners
							   cornerRadius:(float)radius
									flipped:(BOOL)isFlipped;
@end
