/* BannerController+GPGMail.m created by Lukas Pitschl (@lukele) on Thu 06-Jun-2013 */

/*
 * Copyright (c) 2000-2013, GPGTools Team <team@gpgtools.org>
 * All rights reserved.
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of GPGTools Team nor the names of GPGMail
 *       contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE GPGTools Team ``AS IS'' AND ANY
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

#import "BannerController+GPGMail.h"
//#import "MessageViewingState.h"
//#import "MFError.h"
//
//@implementation BannerController_GPGMail
//
//- (void)MAUpdateBannerForViewingState:(MessageViewingState *)viewingState {
//	// First off, we'll call the original method, which will set the banner
//	// Mail.app finds appropriate.
//	// Now this works perfectly for PGP/MIME and PGP/MIME encrpyted (?) messages
//	// since they look to Mail.app just like S/MIME signed/encrypted messages.
//	// (Internally, Mail.app checks if the sign flag is set on the message.)
//	
//	// For inline, we have to help Mail a little.
//	// If no banner was set yet, but [viewingState error] matches error domain MFMessageErrorDomain
//	// we'll force displaying the certificateBanner.
//	[self MAUpdateBannerForViewingState:viewingState];
//	
//	// Now, let's check if a banner is already shown.
//	NSView *bannerContainer = [self valueForKey:@"_bannerContainerView"];
//	BOOL bannerAvailable = NO;
//	for(id view in [bannerContainer subviews]) {
//		if([view isKindOfClass:NSClassFromString(@"BannerView")]) {
//			bannerAvailable = YES;
//			break;
//		}
//	}
//	
//	// A banner is already available or there's no error needed to be displayed,
//	// let's not mess with that and out!
//	if(bannerAvailable || ![viewingState error])
//		return;
//	
//	// Otherwise remove the current banner and display the certificate banner.
//	if([viewingState error] && [[[viewingState error] domain] isEqualToString:@"MFMessageErrorDomain"]) {
//		BannerController *this = (BannerController *)self;
//		[this removeCurrentBanner];
//		[this _showCertificateBanner];
//	}
//}
//
//@end
