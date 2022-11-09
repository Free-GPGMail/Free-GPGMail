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

#import "GPGConstants.h"
#import "GMSecurityMethodAccessoryView.h"
#import "GPGMailBundle.h"
#import "GMSystemIcon.h"
#import "GMSecurityMethodAccessoryViewCell.h"

// Defines the space between to the previous tool bar item.
#define TOOLBAR_ITEM_PADDING 15

@interface GMSecurityMethodAccessoryView ()

@property (nonatomic, retain) GMSecurityMethodAccessoryViewCell *cell;

@end

@implementation GMSecurityMethodAccessoryView
@dynamic cell;

+ (Class)cellClass {
	if(@available(macOS 10.16, *)) {
		return [GMSecurityMethodAccessoryViewCell class];
	}

	return [GMSecurityMethodAccessoryViewLegacyCell class];
}

- (id)init {
	return [self initWithSize:[[self class] preferredMinSize]];
}

+ (NSSize)preferredMinSize {
	if (@available(macOS 10.16, *)) {
		// 85px seems to properly hold OpenPGP without truncation and barely
		// superflous space.
		return NSMakeSize(85.0, 28);
	}

	return NSMakeSize(90.0, 22.0);
}

// This method is called when the window is too narrow
// to show the full NSPopUpButton control. Instead only a menu is displayed.
// The parent menu item irrelevant since only the submenu is acutally shown.
// By re-using the menu connected to the pop-up button, there's no need to
// re-configure any actions and the menu works as is.
- (NSMenuItem *)menuFormRepresentation {
	NSMenuItem *parentItem = [[NSMenuItem alloc] initWithTitle:@"Security Method" action:nil keyEquivalent:@""];

	parentItem.submenu = self.menu;
	if (@available(macOS 10.16, *)) {
		parentItem.image = [GMSystemIcon iconNamed:kGMSystemIconNameLockClosed accessibilityDescription:@"Security Method"];
	}
	return parentItem;
}

- (id)initWithSize:(NSSize)size {
    self = [self initWithFrame:NSMakeRect(0.0f, 0.0f, size.width, size.height) pullsDown:NO];

    [self _configurePopupWithSecurityMethods:@[@"OpenPGP", @"S/MIME"]];

	// Disabled `bordered`, since the border is drawn by the cell.
	self.bordered = NO;
	// Center text.
	[self setAlignment:NSTextAlignmentCenter];

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
        item.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagOption;
        NSString *accessibilityLabel = [NSString stringWithFormat:[GPGMailBundle localizedStringForKey:@"ACCESSIBILITY_SECURITY_METHOD_POPUP_LABEL"], method];
        item.accessibilityLabel = accessibilityLabel;
		NSMutableAttributedString *title = [[NSMutableAttributedString alloc] initWithString:item.title];
		[title addAttributes:@{NSForegroundColorAttributeName: [NSColor whiteColor]} range:NSMakeRange(0, [item.title length])];
		item.attributedTitle = title;
    }
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
	self.cell.accessibilityLabel = [[self selectedItem] accessibilityLabel];

	self.cell.securityMethod = securityMethod;
	// The active state will be updated later, once the certificate check
	// is run, so in order to not display an active state when no certificates
	// are available, set the cell to non-active.
	self.cell.active = NO;

	[self updateCellInside:self.cell];
}

- (void)setActive:(BOOL)active {
	_active = active;

	self.cell.active = active;

	[self updateCellInside:self.cell];
}

- (NSEdgeInsets)alignmentRectInsets {
	NSEdgeInsets insets = [super alignmentRectInsets];
	// Adds paddding to the previous toolbar item on macOS Big Sur.
	if (@available(macOS 10.16, *)) {
		insets.left = -TOOLBAR_ITEM_PADDING;
	}
	return insets;
}

@end

// When a user chooses to send the message, the custom view (control)
// associated with the toolbar item is automatically disabled.
// If however the user aborts sending the message, by not entering their
// passphrase, it is necessary to re-enable the custom view (cotrol), since
// otherwise it's not possible to change the security method anymore.
// In order to have the the toolbar item automatically take care of that
// it is necessary to create a subclass of NSToolbarItem and implement
// -[NSToolbarItem validate].
//
// For now it's enough to always re-enable the control. For more control
// however, check if validateToolbarItem: is implemented on the target
// and if so, have it decide if the control associated with the
// toolbar item should be enabled or not.
@implementation GMSecurityMethodToolbarItem

- (void)validate {
	NSControl *control = (NSControl *)[self view];
	if(![control isKindOfClass:[NSControl class]]) {
        return;
    }
	// Re-enable the toolbar item, if it was previously disabled.
	[control setEnabled:YES];
}

@end
