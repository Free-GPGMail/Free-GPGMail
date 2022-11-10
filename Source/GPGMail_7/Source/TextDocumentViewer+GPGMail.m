/* TextDocumentViewer+GPGMail.m created by stephane on Tue 04-Jul-2000 */

/*
 *	Copyright GPGMail Project Team (gpgtools-devel@lists.gpgtools.org), 2000-2011
 *	(see LICENSE.txt file for license information)
 */

#import "TextDocumentViewer+GPGMail.h"
#import "GPGMessageViewerAccessoryViewOwner.h"
#import "GPGMailBundle.h"
#import <MessageViewer+GPGMail.h>
#import <Message+GPGMail.h>
#import <AppKit/AppKit.h>
#import "GPGMailPatching.h"
#import <MessageHeaderDisplay.h>
#import <TextDocumentViewer.h>
#import <MessageBody.h>
#import <MessageHeaders.h>


@interface TextDocumentViewer (GPGMailPrivate)
- (BOOL)_gpgBannerIsShown;
@end


@implementation TextDocumentViewer (GPGMail)

static NSMapTable       * _extraIVars = NULL;
static NSLock *_extraIVarsLock = nil;

// Posing no longer works correctly on 10.3, that's why we only overload single methods
static IMP _updateDisplay_IMP = NULL;
static IMP dealloc_IMP = NULL;
static IMP validateMenuItem_IMP = NULL;
static IMP setMessage_IMP = NULL;

+ (void)load {
	_extraIVars = NSCreateMapTableWithZone(NSObjectMapKeyCallBacks, NSObjectMapValueCallBacks, 3, [self zone]);
	_extraIVarsLock = [[NSLock alloc] init];
	_updateDisplay_IMP = GPGMail_ReplaceImpOfInstanceSelectorOfClassWithImpOfInstanceSelectorOfClass(@selector(_updateDisplay), [self class], @selector(gpg__updateDisplay), [self class]);
	dealloc_IMP = GPGMail_ReplaceImpOfInstanceSelectorOfClassWithImpOfInstanceSelectorOfClass(@selector(dealloc), [self class], @selector(gpg_dealloc), [self class]);
	validateMenuItem_IMP = GPGMail_ReplaceImpOfInstanceSelectorOfClassWithImpOfInstanceSelectorOfClass(@selector(validateMenuItem:), [self class], @selector(gpg_validateMenuItem:), [self class]);
	setMessage_IMP = GPGMail_ReplaceImpOfInstanceSelectorOfClassWithImpOfInstanceSelectorOfClass(@selector(setMessage:), [self class], @selector(gpg_setMessage:), [self class]);
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
	NSNumber *aBoolValue = [[self gpgExtraIVars] objectForKey:@"messageWasInFactSigned"];

	return (aBoolValue != nil ? [aBoolValue boolValue] : NO);
}

- (void)gpgSetMessageWasInFactSigned:(BOOL)flag {
	[[self gpgExtraIVars] setObject:[NSNumber numberWithBool:flag] forKey:@"messageWasInFactSigned"];
}

- (BOOL)gpgMessageHasBeenDecrypted {
	NSNumber *aBoolValue = [[self gpgExtraIVars] objectForKey:@"messageHasBeenDecrypted"];

	return (aBoolValue != nil ? [aBoolValue boolValue] : NO);
}

- (void)gpgSetMessageHasBeenDecrypted:(BOOL)flag {
	[[self gpgExtraIVars] setObject:[NSNumber numberWithBool:flag] forKey:@"messageHasBeenDecrypted"];
}

- (BOOL)gpgMessageReadStatusHasChanged {
	NSNumber *aBoolValue = [[self gpgExtraIVars] objectForKey:@"messageReadStatusHasChanged"];

	return (aBoolValue != nil ? [aBoolValue boolValue] : NO);
}

- (void)gpgSetMessageReadStatusHasChanged:(BOOL)flag {
	[[self gpgExtraIVars] setObject:[NSNumber numberWithBool:flag] forKey:@"messageReadStatusHasChanged"];
}

- (BOOL)gpgDoNotResetFlags {
	NSNumber *aBoolValue = [[self gpgExtraIVars] objectForKey:@"doNotResetFlags"];

	return (aBoolValue != nil ? [aBoolValue boolValue] : NO);
}

- (void)gpgSetDoNotResetFlags:(BOOL)flag {
	[[self gpgExtraIVars] setObject:[NSNumber numberWithBool:flag] forKey:@"doNotResetFlags"];
}

/*
 * - (void)_displayHTMLDocument:fp12
 * {
 *   NSLog(@"WILL _displayHTMLDocument:%@", fp12);
 *   [super _displayHTMLDocument:fp12];
 *   NSLog(@"DID _displayHTMLDocument:");
 * }
 *
 * - (void)displayAttributedString:fp12
 * {
 *   NSLog(@"WILL displayAttributedString:%@", fp12);
 *   [super displayAttributedString:fp12];
 *   NSLog(@"DID displayAttributedString:");
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

- (void)gpg__updateDisplay {
	GPGMailBundle *mailBundle = [GPGMailBundle sharedInstance];
	Message *aMessage = [self message];
	BOOL shouldAuthenticate = NO;
	BOOL shouldDecrypt = NO;
	BOOL compareFlags = ([aMessage messageStore] != nil && ([mailBundle decryptsOnlyUnreadMessagesAutomatically] || [mailBundle authenticatesOnlyUnreadMessagesAutomatically]));
	BOOL readStatusChanged = NO;

	//    NSView          *originalCertifBanner = [certificateView retain];

	[[self gpgMessageViewerAccessoryViewOwner] messageChanged:aMessage];
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
	} else if ([aMessage gpgIsEncrypted]) {             // Do not get cached status from accessoryViewOwner, because it is not yet up-to-date!
		[self gpgShowPGPEncryptedBanner];
		if ([mailBundle decryptsMessagesAutomatically]) {
			shouldDecrypt = YES;
		}
	} else if ([aMessage gpgHasSignature]) {            // Do not get cached status from accessoryViewOwner, because it is not yet up-to-date!
		if ([mailBundle authenticatesMessagesAutomatically]) {
			[self gpgShowPGPSignatureBanner];
			shouldAuthenticate = YES;
		} else {
			[self gpgShowPGPSignatureBanner];
		}
	} else if ([self gpgMessageWasInFactSigned]) {
		[self gpgShowPGPSignatureBanner];
		if (/*![self gpgDoNotResetFlags]*/ YES) {
			[self gpgSetMessageWasInFactSigned:NO];
			[self gpgSetMessageHasBeenDecrypted:NO];
		}
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

	_updateDisplay_IMP(self, _cmd);             // Call original implementation

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

- (void)gpg_dealloc {
	id originalSelf = self;

	dealloc_IMP(self, _cmd);             // Call original implementation; warning: will call -gpgExtraIVars!
	[_extraIVarsLock lock];
	NSMapRemove(_extraIVars, [NSValue valueWithNonretainedObject:originalSelf]);
	[_extraIVarsLock unlock];
}

- (void)gpgForwardAction:(SEL)action from:(id)sender {
	id target = [self gpgMessageViewerAccessoryViewOwner];

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
		id target = [self gpgMessageViewerAccessoryViewOwner];

		if (target && [target respondsToSelector:anAction]) {
			return [target gpgValidateAction:anAction];
		}
	}

	return NO;
}

- (BOOL)gpg_validateMenuItem:(id <NSMenuItem>)menuItem {
	SEL anAction = [menuItem action];

	if (anAction == @selector(gpgDecrypt:) || anAction == @selector(gpgAuthenticate:)) {
		return [self gpgValidateAction:anAction];
	}

	return !!validateMenuItem_IMP(self, _cmd, menuItem);             // Call original implementation
}
/*
 * - (void)viewSource:fp12
 * {
 *   NSLog(@"WILL viewSource:%@", fp12);
 *   [super viewSource:fp12];
 *   NSLog(@"DID viewSource:");
 * }
 *
 * - (void)reloadCurrentMessage
 * {
 *   NSLog(@"WILL reloadCurrentMessage");
 *   [super reloadCurrentMessage];
 *   NSLog(@"DID reloadCurrentMessage");
 * }
 */
- (void)gpg_setMessage:fp12 {
	//    NSLog(@"WILL setMessage:%@", fp12);
	[self gpgSetMessageWasInFactSigned:NO];
	[self gpgSetMessageHasBeenDecrypted:NO];
	if (fp12 == nil) {
		[[self gpgMessageViewerAccessoryViewOwner] messageChanged:nil];
	}
	setMessage_IMP(self, _cmd, fp12);             // Call original implementation
}
/*
 * - (void)_setMessage:fp12
 * {
 *   //    NSLog(@"WILL _setMessage:%@", fp12);
 *   [super _setMessage:fp12];
 *   //    NSLog(@"DID _setMessage:");
 * }
 */

- (void)_gpgAddAccessoryView:(NSView *)accessoryView {
	NSRect aRect;
	NSRect originalRect;
	float aHeight;
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
}

- (void)_gpgRemoveAccessoryView:(NSView *)accessoryView redisplay:(BOOL)flag {
	NSRect originalRect;
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
}
/*
 * - (GPGMessageViewerAccessoryViewOwner *) _gpgExistingMessageViewerAccessoryViewOwner
 * {
 *   if(_accessoryViewOwnerPerViewer != NULL)
 *       return NSMapGet(_accessoryViewOwnerPerViewer, self);
 *   else
 *       return nil;
 * }
 */
- (GPGMessageViewerAccessoryViewOwner *)gpgMessageViewerAccessoryViewOwner {
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
	return [[[self gpgMessageViewerAccessoryViewOwner] view] superview] != nil;
}

- (void)_gpgShowBannerWithType:(int)bannerType {
	GPGMessageViewerAccessoryViewOwner *anOwner = nil;

	if (![self _gpgBannerIsShown]) {
		anOwner = [self gpgMessageViewerAccessoryViewOwner];
		[anOwner setBannerType:bannerType];
		[self _gpgAddAccessoryView:[anOwner view]];
	} else {
		anOwner = [self gpgMessageViewerAccessoryViewOwner];
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
		GPGMessageViewerAccessoryViewOwner *anOwner = [self gpgMessageViewerAccessoryViewOwner];

		[self _gpgRemoveAccessoryView:[anOwner view] redisplay:YES];
		//        [anOwner setMessage:nil];
	}
}

- (void)gpgAccessoryViewOwner:(GPGMessageViewerAccessoryViewOwner *)owner replaceViewWithView:(NSView *)view {
#if 1
	if (![self _gpgBannerIsShown]) {
		NSLog(@"### GPGMail: banner should already be visible");
	} else
#else
	NSAssert([self _gpgBannerIsShown], @"### GPGMail: banner should already be visible");
#endif
	{ [self _gpgRemoveAccessoryView:[owner view] redisplay:NO]; }
	[self _gpgAddAccessoryView:view];
}

- (void)gpgAccessoryViewOwner:(GPGMessageViewerAccessoryViewOwner *)owner showStatusMessage:(NSString *)message {
	if ([[[[self textView] window] delegate] respondsToSelector:@selector(showStatusMessage:)]) {
		// Delegate can be a MessageViewer, or a MessageEditor (for standalone viewers!)
		[[[[self textView] window] delegate] showStatusMessage:message];
#warning CHECK that it is not needed on 10.2
	}
}

- (void)gpgAccessoryViewOwner:(GPGMessageViewerAccessoryViewOwner *)owner displayMessage:(Message *)message isSigned:(BOOL)isSigned {
	[self setMessage:message];
	[self gpgSetMessageWasInFactSigned:isSigned];
	[self gpgSetMessageHasBeenDecrypted:YES];
	// Now update messageView content
	// If we want to add a fade-out effect, we'll need to wait to the fade-out effect
	// being done before we call [viewer _loadMessageIntoTextView].
	// Fade-out effect is launched by [viewer fadeToEmpty]
//    if([[message messageBody] isKindOfClass:[MimeBody class]])
//        [(MimeBody *)[message messageBody] setPreferredAlternative:0];
//    [self showFirstAlternative:nil];
	if ([[message messageBody] isHTML]) {
		[self gpgSetDoNotResetFlags:YES];
	}
	[self reloadCurrentMessage];
	/*    if([[message messageBody] isHTML]){
	 *  _messageWasInFactSigned = isSigned;
	 * _messageHasBeenDecrypted = YES;
	 * [self showFirstAlternative:nil];
	 * } DOES NOTHING... */
	// Will post MessageWillBeDisplayed notification; we need to call this method anyway,
	// to be sure that URLs are parsed by textView and clickable
}

- (void)gpg_showFirstAlternative:(id)sender {
	[self gpgSetDoNotResetFlags:YES];
	[self showFirstAlternative:sender];             // Performs -_updateDisplay invocation, delayed!
//    [self performSelector:@selector(gpg_resetFlags:) withObject:nil afterDelay:0.1];
}

- (void)gpg_resetFlags:(id)sender {
	[self gpgSetDoNotResetFlags:NO];
	[self gpgSetMessageWasInFactSigned:NO];
	[self gpgSetMessageHasBeenDecrypted:NO];
}

- (Message *)gpgMessageForAccessoryViewOwner:(GPGMessageViewerAccessoryViewOwner *)owner {
	return [self message];
}

- (Message *)gpgMessage {
	// On MacOS X, [self message] sometimes returns zombies!
#warning Is it still true on 10.1?
	return _message;
}

@end
