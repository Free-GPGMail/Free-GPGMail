/* NSPreferences+GPGMail.m created by Lukas Pitschl (lukele) on Sat 20-Aug-2011 */

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

#import "NSPreferences.h"

@interface NSPreferences (GPGMail)

+ (id)MASharedPreferences;

/**
 Returns the window size necessary to fit all toolbar items.
 */
- (NSSize)sizeForWindowShowingAllToolbarItems:(NSWindow *)window;

/**
 Is called when the preference pane is first shown, or the user
 resizes the preference pane.
 If a use resizes the preference pane, the original method is invoked.
 If the preference is first shown, it calulcates the size needed to fit
 all toolbar items using -[NSPreferences(GPGMail)sizeForWindowShowingAllToolbarItems:]
 and returns that value, so the window is correctly resized.
*/
- (NSSize)MAWindowWillResize:(id)window toSize:(NSSize)toSize;

/**
 Helper function to resize the preference pane window to fit all
 toolbar items.
 */
- (void)resizeWindowToShowAllToolbarItems:(NSWindow *)window;

/**
 Is called whenever the user clicks on a toolbar item.
 This also resizes the window, which is why internally
 -[NSPreferences(GPGMail) resizeWindowToShowAllToolbarItems:]
 is called, to force the window to resize again to fit all toolbar items.
 */
- (void)MAToolbarItemClicked:(id)toolbarItem;

/**
 Is called whenever the preference pane is displayed.
 This also resizes the window, which is why internally
 -[NSPreferences(GPGMail) resizeWindowToShowAllToolbarItems:]
 is called, to force the window to resize again to fit all toolbar items.
 */
- (void)MAShowPreferencesPanelForOwner:(id)owner;

@end
