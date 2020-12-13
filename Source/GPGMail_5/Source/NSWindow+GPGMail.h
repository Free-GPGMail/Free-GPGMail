/* NSWindow+GPGMail.h created by Lukas Pitschl (@lukele) on Mon 27-Feb-2012 */

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

#import <Foundation/Foundation.h>

@interface NSWindow (GPGMail)

/**
 Allows to add an accessory view to a NSWindow which will be
 added to the top right.
 */
- (void)addAccessoryView:(NSView *)accessoryView;

/**
 Positions the accessory view at the top right of the theme frame.
 */
- (void)positionAccessoryView:(NSView *)accessoryView;

/**
 Positions the accessory view at the top right, but allows the set an offset.
 */
- (void)positionAccessoryView:(NSView *)accessoryView offset:(NSPoint)offset;

/**
 Centers an accessory view horizontally in the theme frame.
 */
- (void)centerAccessoryView:(NSView *)accessoryView;

/**
 Is called by Mail.app whenever the user clicks the fullscreen toggle button.
 This method is injected for immediately hiding any accessory views in any document
 editors, so there's no glitch in the fullscreen to normal window animation.
 */
- (void)MAToggleFullScreen:(id)sender;

- (id)titlebarView;

@end
