/* NSWindow+GPGMail.m created by Lukas Pitschl (@lukele) on Mon 27-Feb-2012 */

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
#import "GPGMailBundle.h"
//#import "MailDocumentEditor.h"
#import "MailDocumentEditor+GPGMail.h"
#import "NSWindow+GPGMail.h"

@implementation NSWindow (GPGMail)

- (void)addAccessoryView:(NSView *)accessoryView {
    NSView *themeFrame = [[self contentView] superview];
    [self positionAccessoryView:accessoryView];
    if([GPGMailBundle isYosemite])
        [[(id)themeFrame titlebarView] addSubview:accessoryView];
    else
        [themeFrame addSubview:accessoryView];
}

- (void)positionAccessoryView:(NSView *)accessoryView {
    [self positionAccessoryView:accessoryView offset:NSMakePoint(0.0f, 0.0f)];
}

- (void)positionAccessoryView:(NSView *)accessoryView offset:(NSPoint)offset {
    NSView *themeFrame = [[self contentView] superview];
    NSRect c = [themeFrame frame];	// c for "container"
    if([GPGMailBundle isYosemite])
        c = [[(id)themeFrame titlebarView] frame];
    NSRect aV = [accessoryView frame];	// aV for "accessory view"
    
    NSRect newFrame = NSMakeRect(
                                 c.size.width - aV.size.width - offset.x,	// x position
                                 c.size.height - aV.size.height - offset.y,	// y position
                                 aV.size.width,	// width
                                 aV.size.height);	// height
    
    [accessoryView setFrame:newFrame];
}

- (void)centerAccessoryView:(NSView *)accessoryView {
	NSView *themeFrame = [[self contentView] superview];
    NSRect c = [themeFrame frame];	// c for "container"
    NSRect aV = [accessoryView frame];	// aV for "accessory view"
	aV.origin.x = floorf((c.size.width - aV.size.width) / 2.0f);
	
    [accessoryView setFrame:aV];
}

- (void)MAToggleFullScreen:(id)sender {
    // Loop through all document editors and remove the security method
    // accessory view, so there's no animation glitch.
    // TODO: Figure out if this is still called, and if so, what we should be doing here in Sierra!
//    DebugLog(@"Toggle fullscreen: remove security method accessory view");
//    for(MailDocumentEditor *editor in [NSClassFromString(@"MailDocumentEditor") documentEditors]) {
//        if(editor.isModal)
//            [((MailDocumentEditor_GPGMail *)editor) hideSecurityMethodAccessoryView];
//    }
//    [self MAToggleFullScreen:sender];
}

@end
