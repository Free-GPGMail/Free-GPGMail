/*
* Copyright (c) 2021, GPGTools GmbH <team@gpgtools.org>
* All rights reserved.
* Redistribution and use in source and binary forms, with or without
* modification, are permitted provided that the following conditions are met:
*
*     * Redistributions of source code must retain the above copyright
*       notice, this list of conditions and the following disclaimer.
*     * Redistributions in binary form must reproduce the above copyright
*       notice, this list of conditions and the following disclaimer in the
*       documentation and/or other materials provided with the distribution.
*     * Neither the name of GPGTools nor the names of GPGMail
*       contributors may be used to endorse or promote products
*       derived from this software without specific prior written permission.
*
* THIS SOFTWARE IS PROVIDED BY GPGTools ``AS IS'' AND ANY
* EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
* WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
* DISCLAIMED. IN NO EVENT SHALL GPGTools BE LIABLE FOR ANY
* DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
* (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
* LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
* ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
* (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
* SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import "ComposeManager+GPGMail.h"

#import "GPGMailBundle.h"
#import "GMSecurityMethodAccessoryView.h"

@implementation ComposeManager_GPGMail

#pragma mark Security Indicator in Toolbar

- (id)MAToolbarDefaultItemIdentifiers:(id)toolbar {
    if(![[GPGMailBundle sharedInstance] hasActiveContractOrActiveTrial]) {
        return [self MAToolbarDefaultItemIdentifiers:toolbar];
    }
    id defaultItemIdentifiers = [self MAToolbarDefaultItemIdentifiers:toolbar];

    // Appending the security method identifier to toggle between OpenPGP and S/MIME.
    NSMutableArray *identifiers = [defaultItemIdentifiers mutableCopy];
    [identifiers addObject:@"toggleSecurityMethod:"];

    return identifiers;
}

- (id)MAToolbar:(id)toolbar itemForItemIdentifier:(id)itemIdentifier willBeInsertedIntoToolbar:(BOOL)willBeInsertedIntoToolbar {
    if(![[GPGMailBundle sharedInstance] hasActiveContractOrActiveTrial]) {
        return [self MAToolbar:toolbar itemForItemIdentifier:itemIdentifier willBeInsertedIntoToolbar:willBeInsertedIntoToolbar];
    }
    if(![itemIdentifier isEqualToString:@"toggleSecurityMethod:"]) {
        return [self MAToolbar:toolbar itemForItemIdentifier:itemIdentifier willBeInsertedIntoToolbar:willBeInsertedIntoToolbar];
    }

    // Make sure our toolbar item was not already added.
    for(NSToolbarItem *item in [toolbar items]) {
        if([item.itemIdentifier isEqualToString:itemIdentifier])
            return nil;
    }

    GMSecurityMethodToolbarItem *item = [[GMSecurityMethodToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
    [self configureSecurityMethodToolbarItem:item];

    return item;
}

- (void)configureSecurityMethodToolbarItem:(GMSecurityMethodToolbarItem *)toolbarItem {
    // The delegate of GMSecurityMethodAccessoryView will be the current composeViewController.
    // At this point it's however not yet set on the ComposeWindowController, so once the
    // compose view controller is ready, it will set if self up as delegate.
    GMSecurityMethodAccessoryView *securityMethodControl = [GMSecurityMethodAccessoryView new];
    // Store the security method control.
    //[self setIvar:@"SecurityMethodAccessoryView" value:securityMethodControl];

    toolbarItem.target = nil;
    toolbarItem.label = @"Security Method";
    toolbarItem.toolTip = @"Choose security method with which to encrypt/sign message";
    // Configure the menu that is shown instead of the custom control
    // in case there's no enough space (window is too small).
    toolbarItem.menuFormRepresentation = [securityMethodControl menuFormRepresentation];
    toolbarItem.minSize = [GMSecurityMethodAccessoryView preferredMinSize];
    toolbarItem.view = securityMethodControl;
}

@end
