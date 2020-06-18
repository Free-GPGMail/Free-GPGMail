/* GMSecurityMethodAccessoryView.m created by Lukas Pitschl (@lukele) on Thu 01-Mar-2012 */

/*
 * Copyright (c) 2000-2011, GPGTools Project Team <gpgtools-devel@lists.gpgtools.org>
 * All rights reserved.
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of GPGTools Project Team nor the names of GPGMail
 *       contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE GPGTools Project Team ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE GPGTools Project Team BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "CCLog.h"
#import "GPGConstants.h"
#import "NSObject+LPDynamicIvars.h"
#import "NSBezierPath+StrokeExtensions.h"
#import "NSBezierPath_KBAdditions.h"
#import "NSWindow+GPGMail.h"
#import "GMSecurityMethodAccessoryView.h"
#import "GPGMailBundle.h"



@interface NSAppearance(bestMatchFromAppearancesWithNames)
- (NSAppearanceName)bestMatchFromAppearancesWithNames:(NSArray<NSAppearanceName> *)appearances;
@end



@interface GMSecurityMethodAccessoryView ()
@property (nonatomic, assign) BOOL fullscreen;
@property (nonatomic, assign) NSRect nonFullScreenFrame;

@property (nonatomic, strong) NSImageView *arrow;
@property (nonatomic, strong) NSTextField *label;

@property (nonatomic, strong) NSMapTable *attributedTitlesCache;


// cell defined as NSPopUpButtonCell to need no casts.
@property NSPopUpButtonCell *cell;

@end



@interface GMSecurityMethodAccessoryCell : NSPopUpButtonCell
@end
@implementation GMSecurityMethodAccessoryCell
- (void)selectItem:(__unused NSMenuItem *)item {
	// Do not select the menu item when the user clicks on it, only notify the delegate.
	// -setSecurityMethod: changes the selection.
}
@end


@implementation GMSecurityMethodAccessoryView
@synthesize fullscreen = _fullscreen, active = _active, arrow = _arrow,
            nonFullScreenFrame = _nonFullScreenFrame, securityMethod = _securityMethod,
            delegate = _delegate, label = _label, attributedTitlesCache = _attributedTitlesCache, style = _style;
@dynamic cell;

+ (Class)cellClass {
	return [GMSecurityMethodAccessoryCell class];
}

- (id)init {
	return [self initWithStyle:GMSecurityMethodAccessoryViewStyleWindowAccessory];
}

- (id)initWithStyle:(GMSecurityMethodAccessoryViewStyle)style size:(NSSize)size {
    self = [self initWithFrame:NSMakeRect(0.0f, 0.0f, size.width, size.height) pullsDown:NO];
    if(!self) {
        return nil;
    }
    
    self.autoresizingMask = NSViewMinYMargin | NSViewMinXMargin;
    
    // The arrow is hidden, since it's strangely aligned by default.
    // GPGMail adds its own.
    self.cell.arrowPosition = NSPopUpNoArrow;
    
    _attributedTitlesCache = [NSMapTable mapTableWithStrongToStrongObjects];
    _style = style;
    [self _configurePopupWithSecurityMethods:@[@"OpenPGP", @"S/MIME"]];
    [self _configureArrow];
    
    return self;
}

- (id)initWithStyle:(GMSecurityMethodAccessoryViewStyle)style {
    self = [self initWithStyle:style size:NSMakeSize(GMSMA_DEFAULT_WIDTH, GMSMA_DEFAULT_HEIGHT)];
	if (!self) {
		return nil;
	}
	
    return self;
}

- (BOOL)isFlipped {
	return NO;
}

- (void)_configurePopupWithSecurityMethods:(NSArray *)methods {
    NSMenu *menu = self.menu;
    menu.autoenablesItems = NO;
    menu.delegate = self;
    
    for(NSString *method in methods) {
        NSMenuItem *item = [menu addItemWithTitle:method action:@selector(changeSecurityMethod:) keyEquivalent:@""];
        item.target = self;
        item.enabled = YES;
        item.tag = [methods indexOfObject:method] == 0 ? GPGMAIL_SECURITY_METHOD_OPENPGP : GPGMAIL_SECURITY_METHOD_SMIME;
        item.keyEquivalent = [methods indexOfObject:method] == 0 ? @"p" : @"s";
        item.keyEquivalentModifierMask = NSCommandKeyMask | NSAlternateKeyMask;
    }
    
    // Add the initial label.
    NSTextField *label = [[NSTextField alloc] initWithFrame:NSMakeRect(0.0f, 0.0f, self.frame.size.width, self.frame.size.height)];
    label.backgroundColor = [NSColor clearColor];
    label.bordered = NO;
    label.selectable = NO;
    label.editable = NO;
    
    [self addSubview:label];
    self.label = label;

	
	if (self.style == GMSecurityMethodAccessoryViewStyleToolbarItem) {
		self.menu.font = [NSFont systemFontOfSize:18.f];
	}
	
    // Update the label value and center it.
    [self updateAndCenterLabelForItem:nil];
    
}
- (void)_configureArrow {
    NSImage *arrow = [NSImage imageNamed:@"MenuArrowWhite"];
    NSImageView *imageView = [[NSImageView alloc] initWithFrame:NSMakeRect(60.0f, 4.0f, arrow.size.width, arrow.size.height)];
    imageView.image = arrow;
    
    // Add the arrow as subview.
    [self addSubview:imageView];
    
    self.arrow = imageView;
	NSRect arrowFrame = self.arrow.frame;
	arrowFrame.origin.y = 6.0f;
	self.arrow.frame = arrowFrame;
}

- (void)configureForFullScreenWindow:(NSWindow *)window {
    DebugLog(@"Enter fullscreen: move security method accessory view");
    self.fullscreen = YES;
	
    // Add the accessory view to the window.
    [window addAccessoryView:self];
	
    // Center the view within the window.
    [window positionAccessoryView:self offset:NSMakePoint(200.0f, 0.f)];
	
    // Adjust the height to match the other fullscreen mail buttons.
    NSRect frame = self.frame;
    frame.size.height = GMSMA_FULLSCREEN_HEIGHT;
    // Align it vertically to match the other mail buttons.
    frame.origin.y = frame.origin.y - 16.0f;
    self.frame = frame;
	
	// Center the arrow vertically.
	NSRect arrowFrame = self.arrow.frame;
	arrowFrame.origin.y = 6.0f;
	self.arrow.frame = arrowFrame;

	// Set optimal font size.
    self.menu.font = [NSFont systemFontOfSize:12.f];
	
	self.needsDisplay = YES;
    [self updateAndCenterLabelForItem:nil];
}

- (void)configureForWindow:(NSWindow *)window {
    DebugLog(@"Exit fullscreen: re-add security method accessory view");
    self.fullscreen = NO;
	
    [self removeFromSuperview];
	
	// Add the accessory view to the window.
	[window addAccessoryView:self];
	
	// Adjust the height to the default value.
    NSRect frame = self.frame;
    frame.size.height = GMSMA_DEFAULT_HEIGHT;
    self.frame = frame;
	
	// Center the arrow vertically.
	NSRect arrowFrame = self.arrow.frame;
	arrowFrame.origin.y = 4.0f;
	self.arrow.frame = arrowFrame;
	
	// Set optimal font size.
    self.menu.font = [NSFont systemFontOfSize:10.f];
	
	self.needsDisplay = YES;
    [self updateAndCenterLabelForItem:nil];
}

- (void)changeSecurityMethod:(NSMenuItem *)sender {
	// Only tell the delegate if the current method is not the new method.
	if (self.securityMethod == sender.tag) {
		return;
	}
    
    self.securityMethod = (GPGMAIL_SECURITY_METHOD)sender.tag;
	
	[self.delegate securityMethodAccessoryView:self didChangeSecurityMethod:(GPGMAIL_SECURITY_METHOD)sender.tag];
}

- (void)setSecurityMethod:(GPGMAIL_SECURITY_METHOD)securityMethod {
	if (securityMethod == self.securityMethod) {
        return;
	}
	
    _previousSecurityMethod = _securityMethod;
    _securityMethod = securityMethod;
    // Update the selection and center the menu title again.
    [self selectItemAtIndex:securityMethod == GPGMAIL_SECURITY_METHOD_OPENPGP ? 0 : 1];
    [self updateAndCenterLabelForItem:nil];
    self.needsDisplay = YES;
}

#pragma mark - NSMenuDelegate is repsonsible for adjusting the color of the menu titles.

- (NSAttributedString *)attributedTitle:(NSString *)title highlight:(BOOL)highlight {
    // Title must never be nil!
    if(!title)
        title = @"";
    
    NSString *cacheID = [NSString stringWithFormat:@"%@::%@::%@", title, @(highlight),
                         @(self.fullscreen)];
    
    NSAttributedString *cachedString = [self.attributedTitlesCache objectForKey:cacheID];
    if(cachedString) {
        return cachedString;
    }
    
    // Create the white shadow that sits behind the text
    NSShadow *shadow = [[NSShadow alloc] init];
    if(!highlight)
        [shadow setShadowColor:[NSColor colorWithDeviceWhite:1.0 alpha:0.5]];
    else
        [shadow setShadowColor:[NSColor colorWithDeviceRed:0.0/255.0f green:0.0f/255.0f blue:0.0f/255.0f alpha:0.5]];
    [shadow setShadowOffset:NSMakeSize(1.0, -1.1)];
    
    NSFont *font = nil;
    NSColor *color = nil;
    if(!highlight)
        color = [NSColor colorWithDeviceRed:51.0f/255.0f green:51.0f/255.0f blue:51.0f/255.0f alpha:1.0];
    else
        color = [NSColor colorWithDeviceRed:255.0f/255.0f green:255.0f/255.0f blue:255.0f/255.0f alpha:1.0];
    
    // Font size is 12.0f for Fullscreen, 10.f for normal.
    font = !self.fullscreen ? [NSFont systemFontOfSize:10.0f] : [NSFont systemFontOfSize:12.0f];
    
    NSMutableParagraphStyle *mutParaStyle=[[NSMutableParagraphStyle alloc] init];
    [mutParaStyle setAlignment:NSLeftTextAlignment];
    
    NSMutableDictionary *attributes = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                        font ,NSFontAttributeName,
                                        shadow, NSShadowAttributeName, color,
                                        NSForegroundColorAttributeName, mutParaStyle, NSParagraphStyleAttributeName,
                                        nil];
    // The shadow object has been assigned to the dictionary, so release
    // Create a new attributed string with your attributes dictionary attached
    NSAttributedString *attributedTitle = [[NSAttributedString alloc] initWithString:title
                                                                          attributes:attributes];
    
    [self.attributedTitlesCache setObject:attributedTitle forKey:cacheID];
    
    return attributedTitle;
}

- (void)updateAndCenterLabelForItem:(NSMenuItem *)item {
    item = item != nil ? item : self.selectedItem;
    
	NSString *title = item.title;
	
	
	// Set the string for accessibility.
	NSString *accessibilityLabel = [NSString stringWithFormat:[GPGMailBundle localizedStringForKey:@"ACCESSIBILITY_SECURITY_METHOD_POPUP_LABEL"], title];
	if ([self.cell respondsToSelector:@selector(setAccessibilityLabel:)]) {
		[self.cell setValue:accessibilityLabel forKey:@"accessibilityLabel"];
	} else {
		[self.cell accessibilitySetOverrideValue:accessibilityLabel forAttribute:@"AXTitle"];
	}
	
	
	
    NSAttributedString *attributedTitle = [self attributedTitle:title highlight:YES];
    self.label.attributedStringValue = attributedTitle;
    // Adjust the label frame to fit the text.
    [self.label sizeToFit];
    
    NSRect frame = self.label.frame;
    // Center vertically.
    frame.origin.y = (self.frame.size.height - frame.size.height) / 2.0f;
    
    // Now center the new label.
    frame.origin.x = roundf((self.frame.size.width - (frame.size.width + self.arrow.frame.size.width)) / 2.0f);
    // And position the frame.
    NSRect arrowFrame = self.arrow.frame;
    arrowFrame.origin.x = frame.origin.x + frame.size.width;
    self.arrow.frame = arrowFrame;
    
    self.label.frame = frame;
}

- (NSGradient *)gradientSMIMEWithStrokeColor:(NSColor **)strokeColor {
    NSGradient *gradient = nil;
    
    NSUInteger redStart = 20.0f;
    NSUInteger greenStart = 80.0f;
    // Start for full screen.
    NSUInteger greenStartAlt = 128.0f;
    NSUInteger blueStart = 240.0f;
    NSUInteger redStep, greenStep, blueStep;
    redStep = greenStep = blueStep = 18.0f;
	
	if (@available(macOS 10.14, *)) {
		NSAppearance *appearance = NSAppearance.currentAppearance;
		NSAppearanceName appearanceName = [appearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, @"NSAppearanceNameDarkAqua"]];
		if ([appearanceName isEqualToString:@"NSAppearanceNameDarkAqua"]) {
			redStart = 0;
			greenStart *= 0.5;
			greenStartAlt *= 0.5;
			redStep = 0;
			greenStep *= 0.5;
		}
	}

	
    if(!self.fullscreen) {
        gradient = [[NSGradient alloc] initWithColorsAndLocations:[NSColor colorWithDeviceRed:redStart/255.0f green:greenStart/255.0f blue:blueStart/255.0f alpha:1.0], 0.0f,
                    [NSColor colorWithDeviceRed:(redStart + (redStep * 1))/255.0f green:(greenStart + (greenStep * 1))/255.0f blue:blueStart/255.0f alpha:1.0], 0.13f,
                    [NSColor colorWithDeviceRed:(redStart + (redStep * 1))/255.0f green:(greenStart + (greenStep * 1))/255.0f blue:blueStart/255.0f alpha:1.0], 0.27f,
                    [NSColor colorWithDeviceRed:(redStart + (redStep * 2))/255.0f green:(greenStart + (greenStep * 2))/255.0f blue:blueStart/255.0f alpha:1.0], 0.61f,
                    [NSColor colorWithDeviceRed:(redStart + (redStep * 3))/255.0f green:(greenStart + (greenStep * 3))/255.0f blue:blueStart/255.0f alpha:1.0], 1.0f, nil];
    }
    else {
        redStep = greenStep = blueStep *= 0.44;
        gradient = [[NSGradient alloc] initWithColorsAndLocations:[NSColor colorWithDeviceRed:(redStart + (redStep * 2))/255.0f green:(greenStartAlt + (greenStep * 2))/255.0f blue:(blueStart + (blueStep * 1))/255.0f alpha:1.0], 0.0f,
                    [NSColor colorWithDeviceRed:(redStart + (redStep * 3))/255.0f green:(greenStartAlt + (greenStep * 3))/255.0f blue:(blueStart + (blueStep * 1))/255.0f alpha:1.0], 0.13f,
                    [NSColor colorWithDeviceRed:(redStart + (redStep * 4))/255.0f green:(greenStartAlt + (greenStep * 4))/255.0f blue:(blueStart + (blueStep * 1))/255.0f alpha:1.0], 0.27f,
                    [NSColor colorWithDeviceRed:(redStart + (redStep * 5))/255.0f green:(greenStartAlt + (greenStep * 5))/255.0f blue:(blueStart + (blueStep * 1))/255.0f alpha:1.0], 0.61f,
                    [NSColor colorWithDeviceRed:(redStart + (redStep * 6))/255.0f green:(greenStartAlt + (greenStep * 6))/255.0f blue:(blueStart + (blueStep * 1))/255.0f alpha:1.0], 1.0f, nil];
    }
    
    *strokeColor = [NSColor colorWithDeviceRed:redStart/255.0f green:greenStart/255.0f blue:blueStart/255.0f alpha:1.0];
    
    return gradient;
}

- (NSGradient *)gradientPGPWithStrokeColor:(NSColor **)strokeColor {
    NSGradient *gradient = nil;
    
    NSUInteger greenStart = 128.0f;
    NSUInteger greenStep = 18.0f;
	
	if (@available(macOS 10.14, *)) {
		NSAppearance *appearance = NSAppearance.currentAppearance;
		NSAppearanceName appearanceName = [appearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, @"NSAppearanceNameDarkAqua"]];
		if ([appearanceName isEqualToString:@"NSAppearanceNameDarkAqua"]) {
			greenStart *= 0.5;
		}
	}

	
    if(!self.fullscreen) {
        gradient = [[NSGradient alloc] initWithColorsAndLocations:[NSColor colorWithDeviceRed:0/255.0f green:greenStart/255.0f blue:0/255.0f alpha:1.0], 0.0f,
                    [NSColor colorWithDeviceRed:0/255.0f green:(greenStart + (greenStep * 1))/255.0f blue:0/255.0f alpha:1.0], 0.13f,
                    [NSColor colorWithDeviceRed:0/255.0f green:(greenStart + (greenStep * 1))/255.0f blue:0/255.0f alpha:1.0], 0.27f,
                    [NSColor colorWithDeviceRed:0/255.0f green:(greenStart + (greenStep * 2))/255.0f blue:0/255.0f alpha:1.0], 0.61f,
                    [NSColor colorWithDeviceRed:0/255.0f green:(greenStart + (greenStep * 3))/255.0f blue:0/255.0f alpha:1.0], 1.0f, nil];
    }
    else {
        greenStep = 8.0f;
        gradient = [[NSGradient alloc] initWithColorsAndLocations:[NSColor colorWithDeviceRed:0/255.0f green:(greenStart + (greenStep * 6))/255.0f blue:0/255.0f alpha:1.0], 0.0f,
                    [NSColor colorWithDeviceRed:0/255.0f green:(greenStart + (greenStep * 7))/255.0f blue:0/255.0f alpha:1.0], 0.13f,
                    [NSColor colorWithDeviceRed:0/255.0f green:(greenStart + (greenStep * 8))/255.0f blue:0/255.0f alpha:1.0], 0.27f,
                    [NSColor colorWithDeviceRed:0/255.0f green:(greenStart + (greenStep * 9))/255.0f blue:0/255.0f alpha:1.0], 0.61f,
                    [NSColor colorWithDeviceRed:0/255.0f green:(greenStart + (greenStep * 10))/255.0f blue:0/255.0f alpha:1.0], 1.0f, nil];
    }
    
    *strokeColor = [NSColor colorWithDeviceRed:0/255.0f green:greenStart/255.0f blue:0/255.0f alpha:1.0];
    
    return gradient;
}

- (NSGradient *)gradientNotActiveWithStrokeColor:(NSColor **)strokeColor {
    NSGradient *gradient = nil;
    
    NSUInteger greyStart = 146.0f;
    NSUInteger greyStep = 18.0f;
    NSUInteger strokeGrey = 219.0f;
	
	
	if (@available(macOS 10.14, *)) {
		NSAppearance *appearance = NSAppearance.currentAppearance;
		NSAppearanceName appearanceName = [appearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, @"NSAppearanceNameDarkAqua"]];
		if ([appearanceName isEqualToString:@"NSAppearanceNameDarkAqua"]) {
			greyStart *= 0.15;
			strokeGrey *= 0.15;
		}
	}
	
    if(!self.fullscreen) {
        gradient = [[NSGradient alloc] initWithColorsAndLocations:[NSColor colorWithDeviceRed:greyStart/255.0f green:greyStart/255.0f blue:greyStart/255.0f alpha:1.0], 0.0f,
                    [NSColor colorWithDeviceRed:(greyStart + (greyStep * 1))/255.0f green:(greyStart + (greyStep * 1))/255.0f blue:(greyStart + (greyStep * 1))/255.0f alpha:1.0], 0.13f,
                    [NSColor colorWithDeviceRed:(greyStart + (greyStep * 1))/255.0f green:(greyStart + (greyStep * 1))/255.0f blue:(greyStart + (greyStep * 1))/255.0f alpha:1.0], 0.27f,
                    [NSColor colorWithDeviceRed:(greyStart + (greyStep * 2))/255.0f green:(greyStart + (greyStep * 2))/255.0f blue:(greyStart + (greyStep * 2))/255.0f alpha:1.0], 0.61f,
                    [NSColor colorWithDeviceRed:(greyStart + (greyStep * 3))/255.0f green:(greyStart + (greyStep * 3))/255.0f blue:(greyStart + (greyStep * 3))/255.0f alpha:1.0], 1.0f,
                    nil];
    }
    else {
        greyStep = 8.0f;
        gradient = [[NSGradient alloc] initWithColorsAndLocations:[NSColor colorWithDeviceRed:(greyStart + (greyStep * 4))/255.0f green:(greyStart + (greyStep * 4))/255.0f blue:(greyStart + (greyStep * 4))/255.0f alpha:1.0], 0.0f,
                    [NSColor colorWithDeviceRed:(greyStart + (greyStep * 5))/255.0f green:(greyStart + (greyStep * 5))/255.0f blue:(greyStart + (greyStep * 5))/255.0f alpha:1.0], 0.13f,
                    [NSColor colorWithDeviceRed:(greyStart + (greyStep * 6))/255.0f green:(greyStart + (greyStep * 6))/255.0f blue:(greyStart + (greyStep * 6))/255.0f alpha:1.0], 0.27f,
                    [NSColor colorWithDeviceRed:(greyStart + (greyStep * 7))/255.0f green:(greyStart + (greyStep * 7))/255.0f blue:(greyStart + (greyStep * 7))/255.0f alpha:1.0], 0.61f,
                    [NSColor colorWithDeviceRed:(greyStart + (greyStep * 8))/255.0f green:(greyStart + (greyStep * 8))/255.0f blue:(greyStart + (greyStep * 8))/255.0f alpha:1.0], 1.0f,
                    nil];
    }
    
    
    *strokeColor = [NSColor colorWithDeviceRed:strokeGrey/255.0f green:strokeGrey/255.0f blue:strokeGrey/255.0f alpha:1.0];
    
    return gradient;
}

- (void)setActive:(BOOL)active {
    _active = active;
	self.needsDisplay = YES;
}

- (void)drawRect:(__unused NSRect)dirtyRect {
    NSRect rect = [self bounds];
    rect.origin = NSMakePoint(0, 0);
    float cornerRadius = 4.0f;
	KBCornerType corners;
	
	if (self.fullscreen || self.style == GMSecurityMethodAccessoryViewStyleToolbarItem) {
		corners = (KBTopLeftCorner | KBBottomLeftCorner | KBTopRightCorner | KBBottomRightCorner);
	} else {
		corners = (KBTopRightCorner | KBBottomLeftCorner);
	}
	
	NSBezierPath* path = [NSBezierPath bezierPathWithRoundedRect:rect inCorners:corners cornerRadius:cornerRadius flipped:NO];
    
    NSGradient *gradient = nil;
    NSColor *strokeColor = nil;
    
    if(!self.active)
        gradient = [self gradientNotActiveWithStrokeColor:&strokeColor];
    else if(self.securityMethod == GPGMAIL_SECURITY_METHOD_OPENPGP)
        gradient = [self gradientPGPWithStrokeColor:&strokeColor];
    else if(self.securityMethod == GPGMAIL_SECURITY_METHOD_SMIME)
        gradient = [self gradientSMIMEWithStrokeColor:&strokeColor];
    
    [gradient drawInBezierPath:path angle:90.0f];
    [strokeColor setStroke];
    
    [path strokeInside];
}

@end
