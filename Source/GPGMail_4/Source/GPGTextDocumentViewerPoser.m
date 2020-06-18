//
//  GPGTextDocumentViewerPoser.m
//  GPGMail
//
//  Created by GPGMail Project Team on Mon Sep 16 2002.
//

/*
 *	Copyright GPGMail Project Team (gpgtools-devel@lists.gpgtools.org), 2000-2011
 *	(see LICENSE.txt file for license information)
 */

#import "GPGTextDocumentViewerPoser.h"
#import "GPGMessageViewerAccessoryViewOwner.h"
#import "GPGMailBundle.h"
#import <MessageViewer+GPGMail.h>
#import <Message+GPGMail.h>
#import <AppKit/AppKit.h>


@interface NSObject (GPGTextDocumentViewerPoser)
- (void)gpgSetClass:(Class)class;
@end

@implementation NSObject (GPGTextDocumentViewerPoser)

- (void)gpgSetClass:(Class)class {
	isa = class;
}

@end

@interface GPGTextDocumentViewerPoser (Private)
- (BOOL)_gpgBannerIsShown;
- (GPGMessageViewerAccessoryViewOwner *)_gpgMessageViewerAccessoryViewOwner;
@end

@implementation GPGTextDocumentViewerPoser

static NSMapTable *_extraIVars = NULL;
static NSLock *_extraIVarsLock = nil;

+ (void)load {
	NSEnumerator *anEnum = [[MessageViewer allMessageViewers] objectEnumerator];
	MessageViewer *aViewer;

	_extraIVars = NSCreateMapTableWithZone(NSObjectMapKeyCallBacks, NSObjectMapValueCallBacks, 3, [self zone]);
	_extraIVarsLock = [[NSLock alloc] init];
	[GPGTextDocumentViewerPoser poseAsClass:[TextDocumentViewer class]];
	while (aViewer = [anEnum nextObject])
		[[aViewer gpgTextViewer:nil] gpgSetClass:[GPGTextDocumentViewerPoser class]];
}

- (NSMutableDictionary *)gpgExtraIVars {
	NSMutableDictionary *aDict;
	NSValue *aValue = [NSValue valueWithNonretainedObject:self];

	// We cannot use self as key, because in -dealloc this method is called when invoking super's
	// and thus puts self back in mapTable; by using the NSValue and changing the dealloc,
	// it corrects the problem.

	[_extraIVarsLock lock];
	aDict = NSMapGet(_extraIVars, aValue);
	if (aDict == nil) {
		aDict = [NSMutableDictionary dictionary];
		NSMapInsert(_extraIVars, aValue, aDict);
	}
	[_extraIVarsLock unlock];

	return aDict;
}

- (BOOL)gpgMessageWasInFactSigned {
	return [[[self gpgExtraIVars] objectForKey:@"messageWasInFactSigned"] boolValue];
}

- (void)gpgSetMessageWasInFactSigned:(BOOL)flag {
	[[self gpgExtraIVars] setObject:[NSNumber numberWithBool:flag] forKey:@"messageWasInFactSigned"];
}

- (BOOL)gpgMessageHasBeenDecrypted {
	return [[[self gpgExtraIVars] objectForKey:@"messageHasBeenDecrypted"] boolValue];
}

- (void)gpgSetMessageHasBeenDecrypted:(BOOL)flag {
	[[self gpgExtraIVars] setObject:[NSNumber numberWithBool:flag] forKey:@"messageHasBeenDecrypted"];
}

- (BOOL)gpgMessageReadStatusHasChanged {
	return [[[self gpgExtraIVars] objectForKey:@"messageReadStatusHasChanged"] boolValue];
}

- (void)gpgSetMessageReadStatusHasChanged:(BOOL)flag {
	[[self gpgExtraIVars] setObject:[NSNumber numberWithBool:flag] forKey:@"messageReadStatusHasChanged"];
}

/*
 * - (void)_displayHTMLDocument:fp12
 * {
 *  NSLog(@"WILL _displayHTMLDocument:%@", fp12);
 *  [super _displayHTMLDocument:fp12];
 *  NSLog(@"DID _displayHTMLDocument:");
 * }
 *
 * - (void)displayAttributedString:fp12
 * {
 *  NSLog(@"WILL displayAttributedString:%@", fp12);
 *  [super displayAttributedString:fp12];
 *  NSLog(@"DID displayAttributedString:");
 * }
 */

- (void)gpgMessageStoreMessageFlagsChanged:(NSNotification *)notification {
	if ([[[[notification userInfo] objectForKey:@"flags"] objectForKey:@"MessageIsRead"] isEqualToString:@"YES"]) {
		NSEnumerator *anEnum = [[[notification userInfo] objectForKey:@"messages"] objectEnumerator];
		Message *aMessage;
		Message *myMessage = [self message];

		while (aMessage = [anEnum nextObject]) {
			if (aMessage == myMessage) {
				[self gpgSetMessageReadStatusHasChanged:YES];
				break;
			}
		}
	}
}

- (void)_updateDisplay {
	GPGMailBundle *mailBundle = [GPGMailBundle sharedInstance];
	Message *aMessage = [self message];
	BOOL shouldAuthenticate = NO;
	BOOL shouldDecrypt = NO;
	BOOL compareFlags = ([aMessage messageStore] != nil && ([mailBundle decryptsOnlyUnreadMessagesAutomatically] || [mailBundle authenticatesOnlyUnreadMessagesAutomatically]));
	BOOL readStatusChanged = NO;

//    NSView          *originalCertifBanner = [certificateView retain];

	if (compareFlags) {
		[self gpgSetMessageReadStatusHasChanged:NO];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(gpgMessageStoreMessageFlagsChanged:) name:@"MessageStoreMessageFlagsChanged" object:[aMessage messageStore]];
	}

// [super _updateDisplay];
	if (aMessage == nil) {
		if ([self _gpgBannerIsShown]) {
			[self gpgHideBanner];
//            [originalCertifBanner release]; originalCertifBanner = nil;
		}
	} else if ([aMessage gpgIsEncrypted]) {
		[self gpgShowPGPEncryptedBanner];
		if ([mailBundle decryptsMessagesAutomatically]) {
			shouldDecrypt = YES;
		}
	} else if ([aMessage gpgHasSignature]) {
		if ([mailBundle authenticatesMessagesAutomatically]) {
			[self gpgShowPGPSignatureBanner];
			shouldAuthenticate = YES;
		} else {
			[self gpgShowPGPSignatureBanner];
		}
	} else if ([self gpgMessageWasInFactSigned]) {
		[self gpgShowPGPSignatureBanner];
		[self gpgSetMessageWasInFactSigned:NO];
		[self gpgSetMessageHasBeenDecrypted:NO];
	} else if ([self gpgMessageHasBeenDecrypted]) {
		[self gpgShowPGPEncryptedBanner];
		[self gpgSetMessageHasBeenDecrypted:NO];
		if ([mailBundle authenticatesMessagesAutomatically]) {
			shouldAuthenticate = YES;
		}
	} else if ([self _gpgBannerIsShown]) {
		[self gpgHideBanner];
//        [originalCertifBanner release]; originalCertifBanner = nil;
	}

	[super _updateDisplay];

	if (compareFlags) {
		readStatusChanged = [self gpgMessageReadStatusHasChanged];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:@"MessageStoreMessageFlagsChanged" object:[aMessage messageStore]];
	}

	if (shouldAuthenticate && (![mailBundle authenticatesOnlyUnreadMessagesAutomatically] || readStatusChanged)) {
		[self performSelector:@selector(gpgAuthenticate:) withObject:nil afterDelay:0.];
	} else if (shouldDecrypt && (![mailBundle decryptsOnlyUnreadMessagesAutomatically] || readStatusChanged)) {
		[self performSelector:@selector(gpgDecrypt:) withObject:nil afterDelay:0.];
	}
//    if(originalCertifBanner){
//        certificateView = originalCertifBanner;
// //        [self setCertificateView:originalCertifBanner]; // Has side-effects: resets other attributes
//        [originalCertifBanner release];
//    }
}

- (void)dealloc {
	[super dealloc];             // Will call -gpgExtraIVars!
	[_extraIVarsLock lock];
	NSMapRemove(_extraIVars, [NSValue valueWithNonretainedObject:self]);
	[_extraIVarsLock unlock];
}

- (void)gpgForwardAction:(SEL)action from:(id)sender {
	id target = [self _gpgMessageViewerAccessoryViewOwner];

	if (target && [target respondsToSelector:action]) {
		[target performSelector:action withObject:sender];
	}
}

- (IBAction)gpgDecrypt:(id)sender {
	[self gpgForwardAction:_cmd from:sender];
}

- (IBAction)gpgAuthenticate:(id)sender {
	[self gpgForwardAction:_cmd from:sender];
}

- (BOOL)gpgValidateAction:(SEL)anAction {
	if (anAction == @selector(gpgDecrypt:) || anAction == @selector(gpgAuthenticate:)) {
		id target = [self _gpgMessageViewerAccessoryViewOwner];

		if (target && [target respondsToSelector:anAction]) {
			return [target gpgValidateAction:anAction];
		}
	}

	return NO;
}

- (BOOL)validateMenuItem:(id <NSMenuItem>)menuItem {
	SEL anAction = [menuItem action];

	if (anAction == @selector(gpgDecrypt:) || anAction == @selector(gpgAuthenticate:)) {
		return [self gpgValidateAction:anAction];
	}

	return [super validateMenuItem:menuItem];
}
/*
 * - (void)viewSource:fp12
 * {
 *  NSLog(@"WILL viewSource:%@", fp12);
 *  [super viewSource:fp12];
 *  NSLog(@"DID viewSource:");
 * }
 *
 * - (void)reloadCurrentMessage
 * {
 *  NSLog(@"WILL reloadCurrentMessage");
 *  [super reloadCurrentMessage];
 *  NSLog(@"DID reloadCurrentMessage");
 * }
 */
#ifdef PANTHER
- (void)setMessage:fp8 headerOrder:fp12 {
	[self gpgSetMessageWasInFactSigned:NO];
	[self gpgSetMessageHasBeenDecrypted:NO];
	[super setMessage:fp8 headerOrder:fp12];
}

- (void)_setMessage:fp8 headerOrder:fp12 {
	[self gpgSetMessageWasInFactSigned:NO];
	[self gpgSetMessageHasBeenDecrypted:NO];
	[super _setMessage:fp8 headerOrder:fp12];
}
#else
- (void)setMessage:fp12 {
//    NSLog(@"WILL setMessage:%@", fp12);
	[self gpgSetMessageWasInFactSigned:NO];
	[self gpgSetMessageHasBeenDecrypted:NO];
	[super setMessage:fp12];
//    NSLog(@"DID setMessage:");
}
/*
 * - (void)_setMessage:fp12
 * {
 * //    NSLog(@"WILL _setMessage:%@", fp12);
 *  [super _setMessage:fp12];
 * //    NSLog(@"DID _setMessage:");
 * }
 */
#endif
- (void)_gpgAddAccessoryView:(NSView *)accessoryView {
	NSRect aRect;
	NSRect originalRect;
	float aHeight;

#ifdef PANTHER
#if 0
	// Works only for MIME signed, because Mail thinks it's (S/MIME) signed
	certificateView = accessoryView;
#else
	NSView *resizedView = [[contentContainerView subviews] objectAtIndex:0];
	NSView *currentBannerView = nil;

	if ([[contentContainerView subviews] count] > 1) {
		currentBannerView = [[contentContainerView subviews] objectAtIndex:1];
	}
	originalRect = aRect = [resizedView frame];
	aHeight = NSHeight([accessoryView frame]);
	aRect.origin.y = NSMaxY(aRect) - aHeight;
	if (currentBannerView) {
		aRect.origin.y += NSHeight([currentBannerView frame]);
		[currentBannerView setFrameOrigin:NSMakePoint(NSMinX([currentBannerView frame]), NSMinY([currentBannerView frame]) - aHeight)];
		[currentBannerView setNeedsDisplay:YES];
	}
	originalRect.size.height -= aHeight;
	aRect.size.height = aHeight;
	[accessoryView setFrame:aRect];
	[[resizedView superview] addSubview:accessoryView];
	[resizedView setFrame:originalRect];
#endif /* if 0 */
#else
	NSView *resizedView = _currentView;                 // [[self textView] enclosingScrollView];//(NSView *)messageScroll;
	NSView *currentBannerView = junkMailView;

	originalRect = aRect = [resizedView frame];
	aHeight = NSHeight([accessoryView frame]);
	aRect.origin.y = NSMaxY(aRect) - aHeight;
	if ([currentBannerView window] != nil) {
		aRect.origin.y += NSHeight([currentBannerView frame]);
		[currentBannerView setFrameOrigin:NSMakePoint(NSMinX([currentBannerView frame]), NSMinY([currentBannerView frame]) - aHeight)];
		[currentBannerView setNeedsDisplay:YES];
	}
	originalRect.size.height -= aHeight;
	aRect.size.height = aHeight;
	[accessoryView setFrame:aRect];
	[[resizedView superview] addSubview:accessoryView];
	[resizedView setFrame:originalRect];
#endif /* ifdef PANTHER */
}

- (void)_gpgRemoveAccessoryView:(NSView *)accessoryView redisplay:(BOOL)flag {
	NSRect originalRect;

#ifdef PANTHER
#if 0
	// Works only for MIME signed, because Mail thinks it's (S/MIME) signed
#else
	NSView *resizedView = [[contentContainerView subviews] objectAtIndex:0];
	NSView *currentBannerView = nil;

	NSAssert([accessoryView ancestorSharedWithView:resizedView] != nil, @"Trying to remove unattached view!");
	if ([[contentContainerView subviews] count] > 2) {
		currentBannerView = [[contentContainerView subviews] objectAtIndex:2];
		if (currentBannerView == accessoryView) {
			currentBannerView = [[contentContainerView subviews] objectAtIndex:1];
		}
	}
	originalRect = [resizedView frame];
	originalRect.size.height += NSHeight([accessoryView frame]);
	if (flag) {
		[accessoryView removeFromSuperview];
	} else {
		[accessoryView removeFromSuperviewWithoutNeedingDisplay];
	}
	if (currentBannerView) {
		[currentBannerView setFrameOrigin:NSMakePoint(NSMinX([currentBannerView frame]), NSMinY([currentBannerView frame]) + NSHeight([accessoryView frame]))];
		[currentBannerView setNeedsDisplay:YES];
	}
	[resizedView setFrame:originalRect];
#endif /* if 0 */
#else
	NSView *resizedView = _currentView;                 // [[self textView] enclosingScrollView];//(NSView *)messageScroll;
	NSView *currentBannerView = junkMailView;

	NSAssert([accessoryView ancestorSharedWithView:resizedView] != nil, @"Trying to remove unattached view!");
	originalRect = [resizedView frame];
	originalRect.size.height += NSHeight([accessoryView frame]);
	if (flag) {
		[accessoryView removeFromSuperview];
	} else {
		[accessoryView removeFromSuperviewWithoutNeedingDisplay];
	}
	if ([currentBannerView window] != nil) {
		[currentBannerView setFrameOrigin:NSMakePoint(NSMinX([currentBannerView frame]), NSMinY([currentBannerView frame]) + NSHeight([accessoryView frame]))];
		[currentBannerView setNeedsDisplay:YES];
	}
	[resizedView setFrame:originalRect];
#endif /* ifdef PANTHER */
}
/*
 * - (GPGMessageViewerAccessoryViewOwner *) _gpgExistingMessageViewerAccessoryViewOwner
 * {
 *  if(_accessoryViewOwnerPerViewer != NULL)
 *      return NSMapGet(_accessoryViewOwnerPerViewer, self);
 *  else
 *      return nil;
 * }
 */
- (GPGMessageViewerAccessoryViewOwner *)_gpgMessageViewerAccessoryViewOwner {
	// WARNING: this limits us to 1 accessoryView per viewer
	GPGMessageViewerAccessoryViewOwner *accessoryViewOwner = [[self gpgExtraIVars] objectForKey:@"messageViewerAccessoryViewOwner"];

	if (accessoryViewOwner == nil) {
		accessoryViewOwner = [[GPGMessageViewerAccessoryViewOwner alloc] initWithDelegate:self];
		[[self gpgExtraIVars] setObject:accessoryViewOwner forKey:@"messageViewerAccessoryViewOwner"];
		[accessoryViewOwner release];
	}

	return accessoryViewOwner;
}

- (BOOL)_gpgBannerIsShown {
	return [[[self _gpgMessageViewerAccessoryViewOwner] view] superview] != nil;
}

- (void)_gpgShowBannerWithType:(int)bannerType {
	GPGMessageViewerAccessoryViewOwner *anOwner = nil;

	if (![self _gpgBannerIsShown]) {
		anOwner = [self _gpgMessageViewerAccessoryViewOwner];
		[anOwner setBannerType:bannerType];
		[self _gpgAddAccessoryView:[anOwner view]];
	} else {
		anOwner = [self _gpgMessageViewerAccessoryViewOwner];
		if ([anOwner bannerType] != bannerType) {
			[self _gpgRemoveAccessoryView:[anOwner view] redisplay:NO];
			[anOwner setBannerType:bannerType];
			[self _gpgAddAccessoryView:[anOwner view]];
		}
	}
//    [anOwner setMessage:[self message]];
}

- (void)gpgShowPGPSignatureBanner {
	// gpgMessageWasInFactSigned: special case where message has been encrypted and signed in one operation
	[self _gpgShowBannerWithType:([self gpgMessageWasInFactSigned] ? gpgDecryptedSignatureInfoBanner:gpgAuthenticationBanner)];
}

- (void)gpgShowPGPEncryptedBanner {
	// gpgMessageHasBeenDecrypted: special case where message has been encrypted
	[self _gpgShowBannerWithType:([self gpgMessageHasBeenDecrypted] ? gpgDecryptedInfoBanner:gpgDecryptionBanner)];
}

- (void)gpgHideBanner {
	if ([self _gpgBannerIsShown]) {
		GPGMessageViewerAccessoryViewOwner *anOwner = [self _gpgMessageViewerAccessoryViewOwner];

		[self _gpgRemoveAccessoryView:[anOwner view] redisplay:YES];
//        [anOwner setMessage:nil];
	}
}

- (void)gpgAccessoryViewOwner:(GPGMessageViewerAccessoryViewOwner *)owner replaceViewWithView:(NSView *)view {
	NSAssert([self _gpgBannerIsShown], @"### GPGMail: banner should already be visible");
	[self _gpgRemoveAccessoryView:[owner view] redisplay:NO];
	[self _gpgAddAccessoryView:view];
}

- (void)gpgAccessoryViewOwner:(GPGMessageViewerAccessoryViewOwner *)owner showStatusMessage:(NSString *)message {
	if ([[[[self textView] window] delegate] respondsToSelector:@selector(showStatusMessage:)]) {
		// Delegate can be a MessageViewer, or a MessageEditor (for standalone viewers!)
		[[[[self textView] window] delegate] showStatusMessage:message];
	}
}

- (void)gpgAccessoryViewOwner:(GPGMessageViewerAccessoryViewOwner *)owner displayMessage:(Message *)message isSigned:(BOOL)isSigned {
#ifdef PANTHER
#if 1
	// Works, but headers are not up-to-date
	// [inViewer clearCache];
// /////////////////////    [self setMessage:message headerOrder:[[self viewingState] headerOrder]]; // If this line was commented out, no header would appear at all!
//  [inViewer _setMessage:decodedMessage headerOrder:[[inViewer viewingState] headerOrder]];
//  [inViewer _fetchContentsForMessage:decodedMessage fromStore:[decodedMessage messageStore] withViewingState:[inViewer viewingState]];
//  [inViewer viewerPreferencesChanged:nil];
//  [inViewer _updateDisplay];

	MessageViewingState *viewingState = [NSClassFromString (@"MessageHeaderDisplay") copyViewingState:[self viewingState /*ForMessage:[self message]*/]];
	[viewingState setHeaderAttributedString:[[message headers] attributedStringShowingHeaderDetailLevel:[self headerDetailLevel]]];
	NSLog(@"HeaderAttributedString = %@", [viewingState headerAttributedString]);
	if (/*[message numberOfAttachments]*/ [[[message messageBody] attachments] count] == 0) {           // numberOfAttachments not up-to-date! Wrapper's
		[viewingState setAttachmentsDescription:nil];
	} else {
		[viewingState setAttachmentsDescription:[NSClassFromString (@"MessageHeaderDisplay") formattedAttachmentsSizeForMessage:message]];
	}
	NSLog(@"AttachmentsDescription = %@", [viewingState attachmentsDescription]);
	[viewingState setValue:[message messageBody] forKey:@"mimeBody"];
	[self cacheViewingState:viewingState forMessage:message];
	[self setMessage:message headerOrder:[viewingState headerOrder]];
#else
//  id  viewingState = [NSClassFromString(@"MessageHeaderDisplay") copyViewingState:[inViewer viewingState]];
//  id  viewingState = [[inViewer viewingState] retain];

//  [inViewer->headerDisplay displayAttributedString:[MessageHeaderDisplay copyHeadersForMessage:decodedMessage viewingState:viewingState]];
//  [inViewer setMessage:decodedMessage headerOrder:[viewingState headerOrder]];
//  inViewer->_message = [decodedMessage retain];
//  inViewer->textDisplay->messageBody = [decodedMessage messageBody];
//  inViewer->textDisplay->needsSetUp = YES;
	[inViewer->headerDisplay setUp];
//  [inViewer->headerDisplay display:[[decodedMessage headers] attributedStringShowingHeaderDetailLevel:[inViewer headerDetailLevel]]];
	[inViewer->headerDisplay displayAttributedString:[[decodedMessage headers] attributedStringShowingHeaderDetailLevel:[inViewer headerDetailLevel]]];
//  [inViewer->textDisplay displayAttributedString:[decodedMessage attributedString]];
//  [MessageHeaderDisplay setUpEncryptionAndSignatureImageForMessage:decodedMessage viewingState:viewingState];
//  [viewingState release];
//  inViewer->_viewingState = viewingState;
//  [inViewer setMostRecentHeaderOrder:[viewingState headerOrder]];
//  [viewingState release];
#endif /* if 1 */
#else
	[self setMessage:message];
#endif /* ifdef PANTHER */
#ifndef PANTHER
	[self gpgSetMessageWasInFactSigned:isSigned];
	[self gpgSetMessageHasBeenDecrypted:YES];
#endif
	// Now update messageView content
	// If we want to add a fade-out effect, we'll need to wait to the fade-out effect
	// being done before we call [viewer _loadMessageIntoTextView].
	// Fade-out effect is launched by [viewer fadeToEmpty]
	[self reloadCurrentMessage];
#ifdef PANTHER
	[self gpgSetMessageWasInFactSigned:isSigned];
	[self gpgSetMessageHasBeenDecrypted:YES];
#endif
	/*    if([[message messageBody] isHTML]){
	 *  _messageWasInFactSigned = isSigned;
	 *  _messageHasBeenDecrypted = YES;
	 *  [self showFirstAlternative:nil];
	 * } DOES NOTHING... */
	// Will post MessageWillBeDisplayed notification; we need to call this method anyway,
	// to be sure that URLs are parsed by textView and clickable
}

- (Message *)gpgMessageForAccessoryViewOwner:(GPGMessageViewerAccessoryViewOwner *)owner {
	return [self message];
}

@end
