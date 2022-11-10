/* GMSecurityMethodAccessoryViewCell.m created by Lukas Pitschl (@lukele) on Sat 10-Apr-2021 */

/*
 * Copyright (c) 2021, GPGTools Gmbh <team@gpgtools.org>
 * All rights reserved.
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of GPGTools nor the names of GPG Mail
 *       contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE GPGTools GmbH ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE GPGTools GmbH BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "NSBezierPath_KBAdditions.h"
#import "NSBezierPath+StrokeExtensions.h"

#import "GMSecurityMethodAccessoryViewCell.h"

#define to255(x) x/255.0f

@interface NSPopUpButtonCell (Private)
- (NSRect)_indicatorFrameForCellFrame:(NSRect)rect inView:(id)view;
- (NSImage *)_indicatorImage;
@end

typedef enum {
	GMSecurityMethodAccessoryViewCellBackgroundTypeInactive = 0,
	GMSecurityMethodAccessoryViewCellBackgroundTypeOpenPGP,
	GMSecurityMethodAccessoryViewCellBackgroundTypeSMIME
} GMSecurityMethodAccessoryViewCellBackgroundType;

// Big Sur version.
@implementation GMSecurityMethodAccessoryViewCell

+ (BOOL)useDarkModeColors {
	NSAppearance *appearance = [NSAppearance currentAppearance];
	NSAppearanceName appearanceName = [appearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]];
	if ([appearanceName isEqualToString:NSAppearanceNameDarkAqua]) {
		return YES;
	}

	return NO;
}

- (void)selectItem:(__unused NSMenuItem *)item {
	// Do not select the menu item when the user clicks on it, only notify the delegate.
	// -setSecurityMethod: changes the selection.
}

- (NSRect)_indicatorFrameForCellFrame:(NSRect)rect inView:(id)view {
	NSRect indicatorFrame = [super _indicatorFrameForCellFrame:rect inView:view];
	// Pull the indicator arrows to the left so there's a space between the border
	// and the indiciator.
	indicatorFrame.origin.x -= 4;
	return indicatorFrame;
}

- (NSImage *)_indicatorImage {
    NSImage *image = [[super _indicatorImage] copy];
    
    [image lockFocus];
    [[NSColor whiteColor] set];
    
    NSRect rect = NSMakeRect(0, 0, image.size.width, image.size.height);
    NSRectFillUsingOperation(rect, NSCompositingOperationSourceIn);
    [image unlockFocus];
    [image setTemplate:NO];
    
    return image;
}

- (NSRect)titleRectForBounds:(NSRect)bounds {
	NSRect titleBounds = [super titleRectForBounds:bounds];
	if(self.securityMethod == GPGMAIL_SECURITY_METHOD_OPENPGP) {
		titleBounds.origin.x = 5;
	}
	else {
		titleBounds.origin.x = 7;
	}
	return titleBounds;
}

- (GMSecurityMethodAccessoryViewCellBackgroundType)backgroundType {
	// If the control is currently disabled, and as such not usable,
	// use the inactive color for background type.
	if(![self isEnabled]) {
		return GMSecurityMethodAccessoryViewCellBackgroundTypeInactive;
	}
	if(!self.active) {
		return GMSecurityMethodAccessoryViewCellBackgroundTypeInactive;
	}
	else if(self.securityMethod == GPGMAIL_SECURITY_METHOD_OPENPGP) {
		return GMSecurityMethodAccessoryViewCellBackgroundTypeOpenPGP;
	}
	else if(self.securityMethod == GPGMAIL_SECURITY_METHOD_SMIME) {
		return GMSecurityMethodAccessoryViewCellBackgroundTypeSMIME;
	}

	return GMSecurityMethodAccessoryViewCellBackgroundTypeInactive;
}

- (NSColor *)backgroundColorForType:(GMSecurityMethodAccessoryViewCellBackgroundType)type {
	NSColor *color = nil;

	if([[self class] useDarkModeColors]) {
		switch (type) {
			case GMSecurityMethodAccessoryViewCellBackgroundTypeOpenPGP:
				color = [NSColor colorWithRed:0.25 green:0.53 blue:0.28 alpha:1.00];
				break;
			case GMSecurityMethodAccessoryViewCellBackgroundTypeSMIME:
				color = [NSColor colorWithRed:0.02 green:0.34 blue:0.80 alpha:1.00];
				break;
			case GMSecurityMethodAccessoryViewCellBackgroundTypeInactive:
			default:
				color = [NSColor colorWithRed: 0.20 green: 0.20 blue: 0.20 alpha: 1.00];
				break;
		}
	}
	else {
		switch (type) {
			case GMSecurityMethodAccessoryViewCellBackgroundTypeOpenPGP:
				//color = [NSColor colorWithRed:0.0 green:0.57 blue:0.0 alpha:0.2];
				color = [NSColor colorWithRed:to255(14.0f) green:to255(170.0f) blue:to255(47.0f) alpha:0.8];
				break;
			case GMSecurityMethodAccessoryViewCellBackgroundTypeSMIME:
				color = [NSColor colorWithRed:0 green:0.48 blue:0.99 alpha:1.0];
				break;
			case GMSecurityMethodAccessoryViewCellBackgroundTypeInactive:
			default:
				color = [NSColor colorWithRed:0.89 green:0.89 blue:0.89 alpha:1.00];
				break;
		}
	}

	return color;
}

- (void)drawBorderAndBackgroundWithFrame:(NSRect)frame {
	float cornerRadius = 5.0f;
	KBCornerType corners = (KBTopLeftCorner | KBBottomLeftCorner | KBTopRightCorner | KBBottomRightCorner);
	NSBezierPath* path = [NSBezierPath bezierPathWithRoundedRect:frame inCorners:corners cornerRadius:cornerRadius flipped:NO];

	NSColor *color = [self backgroundColorForType:[self backgroundType]];
	[color set];

	[path fill];
}

- (void)drawBorderAndBackgroundWithFrame:(NSRect)frame inView:(NSView *)controlView {
	// On macOS Big Sur it seems necessary to push the frame one pixel
	// to the right, since otherwise the rounded corners are cut off.
	NSUInteger spacing = 1;
	frame.size.width -= spacing;
	frame.origin.x += spacing;
	[self drawBorderAndBackgroundWithFrame:frame];

	[super drawBorderAndBackgroundWithFrame:frame inView:controlView];
}

- (NSRect)drawTitle:(NSAttributedString *)title withFrame:(NSRect)frame inView:(NSView *)controlView {
	return [super drawTitle:title withFrame:frame inView:controlView];
}

@end

// Pre Big Sur version.
@implementation GMSecurityMethodAccessoryViewLegacyCell

- (NSGradient *)gradientSMIMEWithStrokeColor:(NSColor __autoreleasing **)strokeColor {
	NSGradient *gradient = nil;

	NSUInteger redStart = 20.0f;
	NSUInteger greenStart = 80.0f;
	// Start for full screen.
	NSUInteger greenStartAlt = 128.0f;
	NSUInteger blueStart = 240.0f;
	NSUInteger redStep, greenStep, blueStep;
	redStep = greenStep = blueStep = 18.0f;

	if([[self class] useDarkModeColors]) {
		redStart = 0;
		greenStart *= 0.5;
		greenStartAlt *= 0.5;
		redStep = 0;
		greenStep *= 0.5;
	}

	gradient = [[NSGradient alloc] initWithColorsAndLocations:[NSColor colorWithDeviceRed:redStart/255.0f green:greenStart/255.0f blue:blueStart/255.0f alpha:1.0], 0.0f,
				[NSColor colorWithDeviceRed:(redStart + (redStep * 1))/255.0f green:(greenStart + (greenStep * 1))/255.0f blue:blueStart/255.0f alpha:1.0], 0.13f,
				[NSColor colorWithDeviceRed:(redStart + (redStep * 1))/255.0f green:(greenStart + (greenStep * 1))/255.0f blue:blueStart/255.0f alpha:1.0], 0.27f,
				[NSColor colorWithDeviceRed:(redStart + (redStep * 2))/255.0f green:(greenStart + (greenStep * 2))/255.0f blue:blueStart/255.0f alpha:1.0], 0.61f,
				[NSColor colorWithDeviceRed:(redStart + (redStep * 3))/255.0f green:(greenStart + (greenStep * 3))/255.0f blue:blueStart/255.0f alpha:1.0], 1.0f, nil];

	*strokeColor = [NSColor colorWithDeviceRed:redStart/255.0f green:greenStart/255.0f blue:blueStart/255.0f alpha:1.0];

	return gradient;
}

- (NSGradient *)gradientPGPWithStrokeColor:(NSColor __autoreleasing **)strokeColor {
	NSGradient *gradient = nil;

	NSUInteger greenStart = 128.0f;
	NSUInteger greenStep = 18.0f;

	if([[self class] useDarkModeColors]) {
		greenStart *= 0.5;
	}

	gradient = [[NSGradient alloc] initWithColorsAndLocations:[NSColor colorWithDeviceRed:0/255.0f green:greenStart/255.0f blue:0/255.0f alpha:1.0], 0.0f,
				[NSColor colorWithDeviceRed:0/255.0f green:(greenStart + (greenStep * 1))/255.0f blue:0/255.0f alpha:1.0], 0.13f,
				[NSColor colorWithDeviceRed:0/255.0f green:(greenStart + (greenStep * 1))/255.0f blue:0/255.0f alpha:1.0], 0.27f,
				[NSColor colorWithDeviceRed:0/255.0f green:(greenStart + (greenStep * 2))/255.0f blue:0/255.0f alpha:1.0], 0.61f,
				[NSColor colorWithDeviceRed:0/255.0f green:(greenStart + (greenStep * 3))/255.0f blue:0/255.0f alpha:1.0], 1.0f, nil];

	*strokeColor = [NSColor colorWithDeviceRed:0/255.0f green:greenStart/255.0f blue:0/255.0f alpha:1.0];

	return gradient;
}

- (NSGradient *)gradientNotActiveWithStrokeColor:(NSColor __autoreleasing **)strokeColor {
	NSGradient *gradient = nil;

	NSUInteger greyStart = 146.0f;
	NSUInteger greyStep = 18.0f;
	NSUInteger strokeGrey = 219.0f;

	if([[self class] useDarkModeColors]) {
		greyStart *= 0.15;
		strokeGrey *= 0.15;
	}

	gradient = [[NSGradient alloc] initWithColorsAndLocations:[NSColor colorWithDeviceRed:greyStart/255.0f green:greyStart/255.0f blue:greyStart/255.0f alpha:1.0], 0.0f,
				[NSColor colorWithDeviceRed:(greyStart + (greyStep * 1))/255.0f green:(greyStart + (greyStep * 1))/255.0f blue:(greyStart + (greyStep * 1))/255.0f alpha:1.0], 0.13f,
				[NSColor colorWithDeviceRed:(greyStart + (greyStep * 1))/255.0f green:(greyStart + (greyStep * 1))/255.0f blue:(greyStart + (greyStep * 1))/255.0f alpha:1.0], 0.27f,
				[NSColor colorWithDeviceRed:(greyStart + (greyStep * 2))/255.0f green:(greyStart + (greyStep * 2))/255.0f blue:(greyStart + (greyStep * 2))/255.0f alpha:1.0], 0.61f,
				[NSColor colorWithDeviceRed:(greyStart + (greyStep * 3))/255.0f green:(greyStart + (greyStep * 3))/255.0f blue:(greyStart + (greyStep * 3))/255.0f alpha:1.0], 1.0f,
				nil];

	*strokeColor = [NSColor colorWithDeviceRed:strokeGrey/255.0f green:strokeGrey/255.0f blue:strokeGrey/255.0f alpha:1.0];

	return gradient;
}

- (void)drawBorderAndBackgroundWithFrame:(NSRect)frame {
	float cornerRadius = 4.0f;
	KBCornerType corners = (KBTopLeftCorner | KBBottomLeftCorner | KBTopRightCorner | KBBottomRightCorner);

	NSBezierPath* path = [NSBezierPath bezierPathWithRoundedRect:frame inCorners:corners cornerRadius:cornerRadius flipped:NO];

	NSGradient *gradient = nil;
	NSColor *strokeColor = nil;

	switch([self backgroundType]) {
		case GMSecurityMethodAccessoryViewCellBackgroundTypeOpenPGP:
			gradient = [self gradientPGPWithStrokeColor:&strokeColor];
			break;
		case GMSecurityMethodAccessoryViewCellBackgroundTypeSMIME:
			gradient = [self gradientSMIMEWithStrokeColor:&strokeColor];
			break;
		case GMSecurityMethodAccessoryViewCellBackgroundTypeInactive:
		default:
			gradient = [self gradientNotActiveWithStrokeColor:&strokeColor];
			break;
	}

	[gradient drawInBezierPath:path angle:90.0f];
	[strokeColor setStroke];

	[path strokeInside];
}

@end



