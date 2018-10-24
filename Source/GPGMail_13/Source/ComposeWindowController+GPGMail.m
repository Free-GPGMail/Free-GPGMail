/* ComposeWindowController+GPGMail.m created by Lukas Pitschl on Tue 22-09-2015 */

/*
 * Copyright (c) 2000-2015, GPGTools <team@gpgtools.org>
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
 * THIS SOFTWARE IS PROVIDED BY THE GPGTools ``AS IS'' AND ANY
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

#import "NSObject+LPDynamicIvars.h"
#import "GMSecurityMethodAccessoryView.h"
#import "TabBarView.h"
#import "ComposeWindowController.h"
#import "ComposeWindowController+GPGMail.h"
#import "FullScreenModalCapableWindow.h"
#import "MessageViewer.h"
#import "FullScreenWindowController.h"
#import "ComposeViewController.h"
#import "ComposeTabViewItem.h"
#import "ComposeWindow.h"
#import "GPGMailBundle.h"

#define mailself ((ComposeWindowController *)self)

const NSString *kComposeWindowControllerAllowWindowTearDown = @"ComposeWindowControllerAllowWindowTearDown";
const NSString *kComposeWindowControllerLastComposeViewController = @"ComposeWindowControllerLastComposeViewController";
const NSString *kComposeWindowControllerWindowFrameOriginBeforeAnimation = @"ComposeWindowControllerWindowFrameOriginBeforeAnimation";
extern const NSString *kFullScreenWindowControllerCloseModalWindowNotYet;

@implementation ComposeWindowController_GPGMail

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
	
	// The delegate of GMSecurityMethodAccessoryView will be the current composeViewController.
	// At this point it's however not yet set on the ComposeWindowController, so once the
	// compose view controller is ready, it will set if self up as delegate.
    NSSize toolbarItemSize = NSMakeSize(75.0, 23.0);
    GMSecurityMethodAccessoryView *securityMethodAccessoryView = [[GMSecurityMethodAccessoryView alloc] initWithStyle:GMSecurityMethodAccessoryViewStyleToolbarItem size:toolbarItemSize];
	[self setIvar:@"SecurityMethodAccessoryView" value:securityMethodAccessoryView];
	
	NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
	
	[item setView:securityMethodAccessoryView];
	[item setMinSize:toolbarItemSize];
	[item setTarget:nil];
	
	return item;
}

// TODO: RE-implement again for High Sierra (for FUCKS SAKE APPLE!!!)
//#pragma mark Allow restoration of Compose Window on send failures
//// Since El Capitan, Mail has no longer been able to properly restore the compose
//// window if message creation or sending fails for some reason, for example, if
//// the user cancels out of signing a message (S/MIME and OpenPGP) is affected.
////
//// On El Capitan the message was simply lost, not even saved in drafts. Sierra
//// "optimized" the behavior by at least saving the message in drafts.
////
//// The following methods restore this functionality:
////   -[ComposeWindowController _performSendAnimationWithCompletion:] -> this method is called
////     within -[ComposeViewController sendMessageAfterChecking:] and is responsible for setting
////     up and displaying the fly up animation of the window. In addition it's also responsible
////     for tearing down the a tab representing the current message (in fullscreen mode only) and the
////     compose window associated with the current message.
////
////   -[ComposeWindowController saveWindowPositionBeforeAnimation] -> this is GPGMail's method
////     which is called *before* _performSendAnimationWithCompletion: is run, in order to store
////     the current position of the window, as well as the content view controller responsible for
////     the message being sent, in order to be able to restore the window position and - in fullscreen mode -
////     re-select the appropriate tab, if sending the message fails.
////
////   -[ComposeWindowController restorePositionBeforeAnimation] -> this is GPGMail's method
////     which is called in order to restore the position of the window after the animation and
////     to re-select the appropriate tab, in case the sending of the message has failed.
////     This method is called from -[ComposeViewController restoreComposerView]
////
////   -[ComposeViewController restoreComposerView] -> this is GPGMail's method which is responsible
////     for starting the restoration process in case of a send failure. It is called from
////     -[ComposeBackEnd backEnd:didCancelMessageDeliveryForEncryptionError:] and
////     -[ComposeBackEnd backEnd:didCancelMessageDeliveryForError:]
////
////   -[ComposeWindowController composeViewControllerDidSend:] -> is responsible for cleaning up the view controller,
////     remove the current tab item from the tab view and tearing down the compose window controller.
////     In order to be able to restore the compose window however, it's necessary to postpone that work.
////
////   -[ComposeViewController backEndDidAppendMessageToOutbox:result:] -> this is the ultimate method that
////     tells whether or not the message has been sent successfully. If result is 3 it means that no errors have occured.
////     In that case it's clear that the window or tab can now be torn down and properly closed. In order to do that,
////     -[ComposeWindowController composeViewControllerDidSend:] is called, which a special ivar set, telling
////     the method that it's now ok, to clean up.
////
////   -[FullScreenWindowController _closeModalWindow:] -> this method is called from -[ComposeWindowController _performSendAnimationWithCompletion:]
////     in order to close the modal window. If only one tab is available, it's necesary to postpone this call,
////     *until* it's invoked by GPGMail within composeViewControllerDidSend:. If more than one tab is available,
////     it's alright to call it immediately.
////     (Not sure why yet, but it is.)
//
//- (void)saveWindowPositionBeforeAnimation {
//    // Store the the current frame position, to restore it in case of an error.
//    ComposeWindowController *originalComposeWindowController = (ComposeWindowController *)[[mailself contentViewController] delegate];
//    if(!originalComposeWindowController) {
//        originalComposeWindowController = mailself;
//    }
//    // When the window is modal, the correct frame is *not* on `self` but on `composeWindowController`
//    NSPoint currentOrigin = [[originalComposeWindowController window] frame].origin;
//    [originalComposeWindowController setIvar:kComposeWindowControllerWindowFrameOriginBeforeAnimation value:@{@"X": @(currentOrigin.x), @"Y": @(currentOrigin.y)}];
//    // It is necessary to store the current content view controller to be able to select the correct
//    // tab if the window is "revived" in case of an error during sending.
//    [originalComposeWindowController setIvar:kComposeWindowControllerLastComposeViewController value:[mailself contentViewController]];
//}
//
//- (void)MA_performSendAnimationWithCompletion:(void (^)(void))completion {
//    // For modal compose windows which allow the user to have multiple tabs,
//    // it is necessary to distinguish between the controller which is represented
//    // by `self` and the "original" controller which keeps the different tabs.
//    // Because it appears that in the case more than one tab is available,
//    // a new ComposeWindowController is created upon send, which is then
//    // used for the animation(?), which only has the current tab view installed
//    // which was active when sending the message.
//    // In order for "invisible" windows not to build up (there shadows are still visible at the very top of the screen)
//    // the "original" compose window controller has to be checked for the number
//    // of tabs currently available.
//    // If however only one tab view is currently available, it is for some reason necessary
//    // to keep the window from being closed to soon, in order to revive it, when
//    // an error occurs during sending.
//    [self saveWindowPositionBeforeAnimation];
//    ComposeWindowController *originalComposeWindowController = (ComposeWindowController *)[[mailself contentViewController] delegate];
//    if(!originalComposeWindowController) {
//        originalComposeWindowController = mailself;
//    }
//
//    if([(FullScreenModalCapableWindow *)[originalComposeWindowController window] isModal]) {
//        // It seems to make a difference, whether or not more than one
//        // tab bar view item is currently available.
//        // In the case only one is available, the window is not closed when it
//        // would normally be, but only after -[self composeViewControllerDidSend:] is called.
//        if([[[originalComposeWindowController tabBarView] tabBarViewItems] count] <= 1) {
//            [[originalComposeWindowController window] setIvar:kFullScreenWindowControllerCloseModalWindowNotYet value:@YES];
//        }
//    }
//    [self MA_performSendAnimationWithCompletion:completion];
//}
//
//- (void)restorePositionBeforeAnimation {
//    ComposeWindowController *originalComposeWindowController = (ComposeWindowController *)[[mailself contentViewController] delegate];
//    if(!originalComposeWindowController) {
//        originalComposeWindowController = mailself;
//    }
//    // Restore the previous window position.
//    NSDictionary *originBeforeAnimation = [originalComposeWindowController getIvar:kComposeWindowControllerWindowFrameOriginBeforeAnimation];
//    if(!originBeforeAnimation)
//        return;
//    [originalComposeWindowController removeIvar:kComposeWindowControllerWindowFrameOriginBeforeAnimation];
//    [[originalComposeWindowController window] setFrameOrigin:NSMakePoint([originBeforeAnimation[@"X"] floatValue], [originBeforeAnimation[@"Y"] floatValue])];
//    // Select the tab last selected.
//    ComposeTabViewItem *tabBarViewItem = nil;
//    for(ComposeTabViewItem *currentTabBarViewItem in [[originalComposeWindowController tabBarView] tabBarViewItems]) {
//        if([currentTabBarViewItem viewController] == [originalComposeWindowController getIvar:kComposeWindowControllerLastComposeViewController]) {
//            tabBarViewItem = currentTabBarViewItem;
//        }
//    }
//    if(tabBarViewItem) {
//        [originalComposeWindowController tabBarView:[originalComposeWindowController tabBarView] selectTabBarViewItem:tabBarViewItem];
//        [originalComposeWindowController removeIvar:kComposeWindowControllerLastComposeViewController];
//    }
//    [[originalComposeWindowController window] makeKeyAndOrderFront:0];
//
//    return;
//}
//
//- (void)MAComposeViewControllerDidSend:(id)composeViewController {
//    // -[ComposeWindowController composeViewControllerDidSend] is called from
//    // -[ComposeViewController sendMessageAfterChecking:] and is among other things
//    // responsible for tearing down the compose view controller.
//    // Unfortunately this happens too early at the moment, giving GPGMail no opportunity
//    // to recover the message being sent if an error occurs.
//    // To circumvent that, GPGMail postpones this call till after the message
//    // was successfully sent.
//    // If an error occurs, the window is simply restored as if nothing has happened,
//    // and displays an error message if necessary.
//    //
//    // -[ComposeViewController backEndDidAppendMessageToOutbox:result:] is called, once the message
//    // is ready to be sent. At that point GPGMail knows whether or not signing and encrypting
//    // the message has succeeded and is ready to tear down the compose view controller.
//    // In order to start the tear down process, composeViewControllDidSend is then called,
//    // with the ivar GMAllowReleaseOfTabBarViewItem set.
//    if([[composeViewController getIvar:kComposeWindowControllerAllowWindowTearDown] boolValue]) {
//        BOOL isModal = [(FullScreenModalCapableWindow *)[mailself window] isModal];
//        FullScreenWindowController *fullScreenWindowController = (FullScreenWindowController *)[(MessageViewer *)[[[mailself window] parentWindow] delegate] fullScreenWindowController];
//
//        if(isModal) {
//            [[mailself window] removeIvar:kFullScreenWindowControllerCloseModalWindowNotYet];
//            if([[[mailself tabBarView] tabBarViewItems] count] <= 1) {
//                [fullScreenWindowController _closeModalWindow:[(id)self window]];
//            }
//        }
//        [self MAComposeViewControllerDidSend:composeViewController];
//        [composeViewController removeIvar:kComposeWindowControllerAllowWindowTearDown];
//    }
//}

@end

#undef mailself
