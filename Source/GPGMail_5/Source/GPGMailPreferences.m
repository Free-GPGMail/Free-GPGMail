/* GPGMailPreferences.m created by dave on Thu 29-Jun-2000 */

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

#import "GPGMailPreferences.h"
#import "GPGMailBundle.h"

#import <pwd.h>

#import "MFMailAccount.h"
#import "MFRemoteStoreAccount.h"
#import "MailApp.h"

#import "GMSupportPlanManager.h"
#import "GMSupportPlan.h"

#define localized(key) [GPGMailBundle localizedStringForKey:key]

NSString *SUEnableAutomaticChecksKey = @"SUEnableAutomaticChecks";
NSString *SUScheduledCheckIntervalKey = @"SUScheduledCheckInterval";

@interface GPGMailPreferences ()

@property (nonatomic, weak) IBOutlet NSTextField *registrationDescriptionTextField;
@property (nonatomic, weak) IBOutlet NSTextField *activationCodeTextField;
@property (nonatomic, weak) IBOutlet NSButton *activateButton;
@property (nonatomic, weak) IBOutlet NSButton *deactivateButton;
@property (nonatomic, weak) IBOutlet NSButton *learnMoreButton;
@property (nonatomic, weak) IBOutlet NSButton *reportProblemButton;
@property (nonatomic, weak) IBOutlet NSButton *switchSupportPlanButton;
@property (nonatomic, weak) IBOutlet NSTextField *supportPlanTitleField;
@property (nonatomic, assign) BOOL preferencesDidLoad;

@end

@implementation GPGMailPreferences

- (id)init {
    if((self = [super init])) {
        _preferencesDidLoad = NO;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateSupportPlanSection:) name:@"GMSupportPlanStateChangeNotification" object:nil];
    }
    return self;
}

- (GPGMailBundle *)bundle {
	return [GPGMailBundle sharedInstance];
}

- (NSString *)copyright {
	return [[GPGMailBundle bundle] infoDictionary][@"NSHumanReadableCopyright"];
}

- (NSAttributedString *)credits {
	NSBundle *mailBundle = [GPGMailBundle bundle];
	NSAttributedString *credits = [[NSAttributedString alloc] initWithURL:[mailBundle URLForResource:@"Credits" withExtension:@"rtf"] documentAttributes:nil];

	return credits;
}

- (NSAttributedString *)websiteLink {
	NSMutableParagraphStyle *pStyle = [[NSMutableParagraphStyle alloc] init];

	[pStyle setAlignment:NSRightTextAlignment];

	NSDictionary *attributes = @{NSParagraphStyleAttributeName: pStyle,
								NSLinkAttributeName: @"https://github.com/Free-GPGMail/Free-GPGMail/",
								NSForegroundColorAttributeName: [NSColor blueColor],
								NSFontAttributeName: [NSFont fontWithName:@"Lucida Grande" size:9],
								NSUnderlineStyleAttributeName: @1};

	return [[NSAttributedString alloc] initWithString:@"https://github.com/Free-GPGMail/Free-GPGMail" attributes:attributes];
}


- (NSString *)versionDescription {
	return [NSString stringWithFormat:localized(@"VERSION: %@"), [self.bundle version]];
}

- (NSAttributedString *)buildNumberDescription {
	NSString *string = [NSString stringWithFormat:@"Build: %@", [GPGMailBundle bundleVersion]];
	NSDictionary *attributes = @{NSForegroundColorAttributeName: [NSColor grayColor], NSFontAttributeName: [NSFont systemFontOfSize:11]};

	return [[NSAttributedString alloc] initWithString:string attributes:attributes];
}

- (void)updateSupportPlanSection:(NSNotification *)notification {
    // Check if the outlets are set, otherwise it means that
    // the preferences are not currently being presented and so
    // there's no need to change the state.
    if(_activationCodeTextField != nil) {
        [self willBeDisplayed];
    }
}

- (NSAttributedString *)activationCodeFieldDescription {
    // The activation code field in most cases will only display
    // the activation code, unless a previous GPG Mail Support Plan
    // activation is detected which is not valid for the current version.
    NSMutableAttributedString *description = [NSMutableAttributedString new];

    GMSupportPlanManager *supportPlanManager = [[GPGMailBundle sharedInstance] supportPlanManager];
    GMSupportPlan *supportPlan = [supportPlanManager supportPlan];
    NSString *version = [supportPlanManager applicationVersion];
    self.supportPlanTitleField.stringValue = @"Free-GPGMail without activation";

    // If a valid support plan for a previous version is available, show the old activation code.
    BOOL anyValidSupportPlan = ([supportPlanManager supportPlanIsActive] && ![supportPlan isKindOfTrial]) || [supportPlanManager shouldPromptUserForUpgrade];
    GMSupportPlan *previousSupportPlan = [supportPlanManager supportPlanForPreviousVersion];

    if(!anyValidSupportPlan) {
        return (NSAttributedString *)description;
    }

    // True if the support plan is valid for this version and not a trial.
    BOOL validSupportPlanExists = [supportPlanManager supportPlanIsActive] && ![supportPlan isKindOfTrial];

    NSString *activationCode = validSupportPlanExists ? [supportPlan activationCode] : [previousSupportPlan activationCode];

    NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    [style setParagraphSpacing:4];
    NSDictionary *formattingAttributes = @{
        NSParagraphStyleAttributeName: style,
        NSFontAttributeName: [NSFont systemFontOfSize:[NSFont smallSystemFontSize]],
        NSForegroundColorAttributeName: [NSColor controlTextColor]
    };

    NSMutableString *activationCodeAndCoveredVersionsText = [NSMutableString new];
    [activationCodeAndCoveredVersionsText appendString:[NSString stringWithFormat:@"%@: %@", localized(@"PREFERENCES_SUPPORT_PLAN_STATE_ACTIVATION_CODE_TITLE"), activationCode]];
    NSArray *eligibleVersions = validSupportPlanExists ? [supportPlan eligibleVersions] : [previousSupportPlan eligibleVersions];
    [activationCodeAndCoveredVersionsText appendString:@"\n"];
    [activationCodeAndCoveredVersionsText appendString:[self coveredVersionsTextForVersions:eligibleVersions]];
    NSAttributedString *code = [[NSAttributedString alloc] initWithString:activationCodeAndCoveredVersionsText attributes:formattingAttributes];
    [description appendAttributedString:code];

    if(validSupportPlanExists) {
        return description;
    }

    // Add space between covered version and rest.
    [description appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n" attributes:formattingAttributes]];

    // If no support plan exists that covers this version but only a previous version,
    // display detailed information about possible options.
    NSString *modeDescription = [self modeDescription];

    NSMutableParagraphStyle *paddingStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    [paddingStyle setParagraphSpacingBefore:14];
    [paddingStyle setParagraphSpacing:4];
    NSMutableAttributedString *decryptOnlyMode = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n", modeDescription] attributes:formattingAttributes];
    [decryptOnlyMode addAttribute:NSParagraphStyleAttributeName value:paddingStyle range:NSMakeRange(0, [decryptOnlyMode length])];
    [decryptOnlyMode addAttribute:NSFontAttributeName value:[NSFont boldSystemFontOfSize:[NSFont smallSystemFontSize]] range:NSMakeRange(0, [decryptOnlyMode length])];
    [description appendAttributedString:decryptOnlyMode];

    // Add some padding bottom using a paragraph style's spacing property.
    paddingStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    [paddingStyle setParagraphSpacing:0];
    NSString *explanationString = [[NSString stringWithFormat:localized(@"PREFERENCES_SUPPORT_PLAN_STATE_INVALID_NOT_COVERED_VERSION_DETECTED_DESCRIPTION_DYNAMIC"), [GPGMailBundle productNameForVersion:[supportPlanManager applicationVersion]]] stringByAppendingString:@"\n"];
    NSMutableAttributedString *explanation = [[NSMutableAttributedString alloc] initWithString:explanationString attributes:formattingAttributes]; // @"Your current support plan is not valid for this version of GPG Mail. You can either choose to 'Upgrade' it or 'Switch Support Plan' If you have a different valid one for GPG Mail 4.\n"
    // Font of size 1 is necessary, since line height
    [explanation addAttribute:NSParagraphStyleAttributeName value:paddingStyle range:NSMakeRange(0, [explanation length])];
    [explanation addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:1.0] range:NSMakeRange([explanation length] - 1, 1)];
    [description appendAttributedString:explanation];

    return (NSAttributedString *)description;
}

- (NSString *)coveredVersionsTextForVersions:(NSArray *)versions {
    NSMutableArray *coveredVersions = [NSMutableArray new];
    for(NSString *tempVersion in versions) {
        [coveredVersions addObject:[NSString stringWithFormat:@"%@.x", tempVersion]];
    }
    NSString *coveredVersionsText = [NSString stringWithFormat:@"%@: %@", localized(@"PREFERENCES_SUPPORT_PLAN_STATE_COVERED_VERSIONS_TITLE"),
    [coveredVersions componentsJoinedByString:@", "]];

    return coveredVersionsText;
}

- (NSString *)modeDescription {
    GMSupportPlanManager *supportPlanManager = [[GPGMailBundle sharedInstance] supportPlanManager];

    NSString *description = localized(@"PREFERENCES_SUPPORT_PLAN_STATE_DECRYPT_ONLY_DESCRIPTION"); // @"Decrypt Only Mode";
    if([[supportPlanManager supportPlan] isKindOfTrial]) {
        NSNumber *remainingDays = [supportPlanManager remainingTrialDays];
        if([remainingDays integerValue] <= 0) {
            description = localized(@"PREFERENCES_SUPPORT_PLAN_STATE_DECRYPT_ONLY_TRIAL_EXPIRED_DESCRIPTION"); // @"Decrypt Only Mode - Trial expired";
        }
        else {
            description = [NSString stringWithFormat:localized(@"PREFERENCES_SUPPORT_PLAN_STATE_DECRYPT_ONLY_TRIAL_DAYS_REMAINING_DESCRIPTION"), remainingDays]; // @"Trial Mode - %@ days remaining"
        }
    }

    return description;
}

- (NSString *)registrationDescription {
    GMSupportPlanManager *supportPlanManager = [[GPGMailBundle sharedInstance] supportPlanManager];

    // The easiest state is to have a valid support plan or a valid previous support plan.
    if(([supportPlanManager supportPlanIsActive] && ![[supportPlanManager supportPlan] isKindOfTrial]) || [supportPlanManager shouldPromptUserForUpgrade]) {
        GMSupportPlan *previousSupportPlan = [supportPlanManager supportPlanForPreviousVersion];
        NSString *email = [supportPlanManager supportPlanIsActive] && ![[supportPlanManager supportPlan] isKindOfTrial] ? [supportPlanManager currentEmail] : [previousSupportPlan email];
        return [NSString stringWithFormat:@"%@: %@", localized(@"PREFERENCES_SUPPORT_PLAN_STATE_REGISTERED_TO"), email];
    }

    if(![supportPlanManager supportPlan] || (![supportPlanManager supportPlanIsActive] && [supportPlanManager supportPlanState] != GMSupportPlanStateTrialExpired)) {
        return localized(@"PREFERENCES_SUPPORT_PLAN_STATE_DECRYPT_ONLY_DESCRIPTION");
    }

    GMSupportPlan *supportPlan = [supportPlanManager supportPlan];
    GMSupportPlanType type = [supportPlan type];

    if([supportPlan isKindOfTrial]) {
        return [self modeDescription];
    }
    else if(type == GMSupportPlanTypeTime) {
        NSString *formattedDate = [NSDateFormatter localizedStringFromDate:[supportPlan expirationDate] dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterNoStyle];

        return [NSString stringWithFormat:@"%@ - valid until %@", [NSString stringWithFormat:@"%@: %@", localized(@"PREFERENCES_SUPPORT_PLAN_STATE_REGISTERED_TO"), [supportPlanManager currentEmail]], formattedDate];
    }

    return [NSString stringWithFormat:@"%@: %@", localized(@"PREFERENCES_SUPPORT_PLAN_STATE_REGISTERED_TO"), [supportPlanManager currentEmail]];
}

- (IBAction)activateSupportPlan:(NSButton *)sender {
	[[GPGMailBundle sharedInstance] startSupportContractWizard];
}
- (IBAction)deactivateSupportPlan:(NSButton *)sender {
	NSWindow *window = [[(MailApp *)[NSClassFromString(@"MailApp") sharedApplication] preferencesController] window];
	NSAlert *alert = [GPGMailBundle customAlert];
	alert.messageText = localized(@"SUPPORT_PLAN_DEACTIVATION_WARNING_TITLE");
	alert.informativeText = localized(@"SUPPORT_PLAN_DEACTIVATION_WARNING_MESSAGE");
	[alert addButtonWithTitle:localized(@"SUPPORT_PLAN_DEACTIVATION_WARNING_CANCEL")];
	[alert addButtonWithTitle:localized(@"SUPPORT_PLAN_DEACTIVATION_WARNING_CONFIRM")];

	[alert beginSheetModalForWindow:window completionHandler:^(NSModalResponse returnCode) {
		if (returnCode == NSAlertSecondButtonReturn) {
			[[GPGMailBundle sharedInstance] deactivateSupportContract];
		}
	}];
}
- (IBAction)switchSupportPlan:(__unused NSButton *)sender {
	[[GPGMailBundle sharedInstance] startSupportContractWizardToSwitchPlan];
}
- (IBAction)learnMore:(NSButton *)sender {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/Free-GPGMail/Free-GPGMail"]];
}




- (NSImage *)imageForPreferenceNamed:(NSString *)aName {
	return [NSImage imageNamed:@"GPGMail"];
}



- (IBAction)openSupport:(id)sender {
    BOOL success = NO;

	if (!success) {
		// Alternative if GPGPreferences could not be launched.
		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/Free-GPGMail/Free-GPGMail/issues"]];
	}
}
- (IBAction)openDonate:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/Free-GPGMail/Free-GPGMail"]];
}
- (IBAction)openKnowledgeBase:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/Free-GPGMail/Free-GPGMail/issues/"]];
}



- (IBAction)openGPGStatusHelp:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/Free-GPGMail/Free-GPGMail/issues/"]];
}


- (void)willBeDisplayed {
    GMSupportPlanManager *supportPlanManager = [[GPGMailBundle sharedInstance] supportPlanManager];
    BOOL previousSupportPlanExists = [supportPlanManager shouldPromptUserForUpgrade];
    if([[GPGMailBundle sharedInstance] hasActiveContract]) {
        GMSupportPlanState supportPlanState = [supportPlanManager supportPlanState];
        if(supportPlanState == GMSupportPlanStateTrial) {
            if(previousSupportPlanExists) {
                [self setState:GPGMailPreferencesSupportPlanStateOldActiveState forceUpdate:YES];
            }
            else {
                [self setState:GPGMailPreferencesSupportPlanStateTrialState forceUpdate:YES];
            }
        }
        else {
            [self setState:GPGMailPreferencesSupportPlanStateActiveState forceUpdate:YES];
        }
    }
    else {
        if(previousSupportPlanExists) {
            [self setState:GPGMailPreferencesSupportPlanStateOldActiveState forceUpdate:YES];
        }
        else {
            [self setState:GPGMailPreferencesSupportPlanStateTrialState forceUpdate:YES];
        }
    }
}

- (void)setState:(GPGMailPreferencesSupportPlanState)state forceUpdate:(BOOL)forceUpdate {
    if (_state != state || forceUpdate) {
        _state = state;

        _activationCodeTextField.hidden = (state != GPGMailPreferencesSupportPlanStateActiveState && state != GPGMailPreferencesSupportPlanStateOldActiveState);
        _reportProblemButton.hidden = (state != GPGMailPreferencesSupportPlanStateActiveState);
        _deactivateButton.hidden = (state != GPGMailPreferencesSupportPlanStateActiveState);
        _activateButton.hidden = (state == GPGMailPreferencesSupportPlanStateActiveState);
        _learnMoreButton.hidden = (state != GPGMailPreferencesSupportPlanStateTrialState);
		_switchSupportPlanButton.hidden = (state != GPGMailPreferencesSupportPlanStateOldActiveState);
        _activationCodeTextField.attributedStringValue = [self activationCodeFieldDescription];
        _activationCodeTextField.maximumNumberOfLines = 0;

        // Allow the activation code to be selected and copied.
        _activationCodeTextField.selectable = YES;
        _activationCodeTextField.allowsEditingTextAttributes = YES;

        if([[[GPGMailBundle sharedInstance] supportPlanManager] shouldPromptUserForUpgrade]) {
            _activateButton.title = localized(@"PREFERENCES_SUPPORT_PLAN_ACTION_BUTTON_UPGRADE_TITLE");
        }
        else {
            _activateButton.title = localized(@"PREFERENCES_SUPPORT_PLAN_ACTION_BUTTON_ACTIVATE_TITLE");
        }
        _switchSupportPlanButton.title = localized(@"PREFERENCES_SUPPORT_PLAN_ACTION_BUTTON_SWITCH_SUPPORT_PLAN_TITLE");
    }
    // When GPG Mail is deactivated, at first it is displayed that GPG Mail is now in read only mode.
    // But once the API call is completed a new trial activation might have been fetched.
    _registrationDescriptionTextField.hidden = NO;
    _registrationDescriptionTextField.stringValue = [self registrationDescription];
}

- (void)setState:(GPGMailPreferencesSupportPlanState)state {
    [self setState:state forceUpdate:NO];
}

- (NSImage *)gpgStatusImage {
	switch ([[GPGMailBundle sharedInstance] gpgStatus]) {
		case GPGErrorNotFound:
			return [NSImage imageNamed:NSImageNameStatusUnavailable];
		case GPGErrorNoError:
			return [NSImage imageNamed:NSImageNameStatusAvailable];
		default:
			return [NSImage imageNamed:NSImageNameStatusPartiallyAvailable];
	}
}
- (NSString *)gpgStatusToolTip {
	switch ([[GPGMailBundle sharedInstance] gpgStatus]) {
		case GPGErrorNotFound:
			return localized(@"GPG_STATUS_NOT_FOUND_TOOLTIP");
		case GPGErrorNoError:
			return nil;
		default:
			return localized(@"GPG_STATUS_OTHER_ERROR_TOOLTIP");
	}
}

- (NSString *)gpgStatusTitle {
    NSString *statusTitle = nil;
    switch ([[GPGMailBundle sharedInstance] gpgStatus]) {
		case GPGErrorNotFound:
			statusTitle = localized(@"GPG_STATUS_NOT_FOUND_TITLE");
            break;
		case GPGErrorNoError:
			statusTitle = localized(@"GPG_STATUS_NO_ERROR_TITLE");
            break;
        default:
			statusTitle = localized(@"GPG_STATUS_OTHER_ERROR_TITLE");
	}
    return statusTitle;
}

+ (NSSet*)keyPathsForValuesAffectingGpgStatusImage {
	return [NSSet setWithObject:@"bundle.gpgStatus"];
}
+ (NSSet*)keyPathsForValuesAffectingGpgStatusToolTip {
	return [NSSet setWithObject:@"bundle.gpgStatus"];
}
+ (NSSet*)keyPathsForValuesAffectingGpgStatusTitle {
	return [NSSet setWithObject:@"bundle.gpgStatus"];
}

- (GPGOptions *)options {
    return [GPGOptions sharedOptions];
}

- (BOOL)isResizable {
	return NO;
}

- (BOOL)validateEncryptDrafts:(NSNumber **)value error:(NSError **)error {
	if ([*value boolValue] == NO) {
		NSArray *accounts = (NSArray *)[MFMailAccount mailAccounts];
		for (id account in accounts) {
			if ([account respondsToSelector:@selector(storeDraftsOnServer)] && [account storeDraftsOnServer]) {

                NSWindow *window = [[(MailApp *)[NSClassFromString(@"MailApp") sharedApplication] preferencesController] window];

                NSAlert *unencryptedReplyAlert = [GPGMailBundle customAlert];
                unencryptedReplyAlert.messageText = localized(@"DISABLE_ENCRYPT_DRAFTS_TITLE");
                unencryptedReplyAlert.informativeText = localized(@"DISABLE_ENCRYPT_DRAFTS_MESSAGE");
                [unencryptedReplyAlert addButtonWithTitle:localized(@"DISABLE_ENCRYPT_DRAFTS_CANCEL")];
                [unencryptedReplyAlert addButtonWithTitle:localized(@"DISABLE_ENCRYPT_DRAFTS_CONFIRM")];

                [unencryptedReplyAlert beginSheetModalForWindow:window completionHandler:^(NSModalResponse returnCode) {
                    [NSApp stopModalWithCode:returnCode];
                }];

				if ([NSApp runModalForWindow:window] != NSAlertSecondButtonReturn) {
					*value = @(YES);
				}
				break;
			}
		}
	}
	return YES;
}

- (BOOL)encryptDrafts {
	return [self.options boolForKey:@"OptionallyEncryptDrafts"];
}
- (void)setEncryptDrafts:(BOOL)value {
	[self.options setBool:value forKey:@"OptionallyEncryptDrafts"];
}


@end


@implementation NSButton_LinkCursor
- (void)resetCursorRects {
	[self addCursorRect:[self bounds] cursor:[NSCursor pointingHandCursor]];
}
@end

@implementation GMSpecialBox
- (void)showSpecial {
	return;
//	if (displayed || working) return;
//	working = YES;
//
//	if (!viewPositions) {
//		viewPositions = [[NSMapTable alloc] initWithKeyOptions:NSMapTableZeroingWeakMemory valueOptions:NSMapTableStrongMemory capacity:10];
//	}
//
//	NSSize size = self.bounds.size;
//	srandom((unsigned int)time(NULL));
//
//	webView = [[WebView alloc] initWithFrame:NSMakeRect(0, 0, size.width, size.height)];
//	webView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
//	webView.drawsBackground = NO;
//	webView.UIDelegate = self;
//	webView.editingDelegate = self;
//
//
//	[NSAnimationContext beginGrouping];
//	[[NSAnimationContext currentContext] setDuration:2.0f];
//	[NSAnimationContext currentContext].completionHandler = ^{
//		[self addSubview:webView];
//
//		[[webView mainFrame] loadRequest:[NSURLRequest requestWithURL:[[GPGMailBundle bundle] URLForResource:@"Special" withExtension:@"html"]]];
//		displayed = YES;
//		working = NO;
//	};
//
//	for (NSView *view in [self.contentView subviews]) {
//		NSRect frame = view.frame;
//
//		if (!positionsFilled) {
//			[viewPositions setObject:[NSValue valueWithRect:frame] forKey:view];
//		}
//
//		long angle = (random() % 360);
//
//		double x = (size.width + frame.size.width) / 2 * sin(angle * M_PI / 180) * 1.5;
//		double y = (size.height + frame.size.height) / 2 * cos(angle * M_PI / 180) * 1.5;
//
//		x += (size.width - frame.size.width) / 2;
//		y += (size.height - frame.size.height) / 2;
//
//		frame.origin.x = x;
//		frame.origin.y = y;
//
//		[(NSView *)[view animator] setFrame:frame];
//	}
//	positionsFilled = YES;
//	[NSAnimationContext endGrouping];
}
- (void)hideSpecial {
	if (!displayed || working) return;
	working = YES;

	for (NSView *view in viewPositions) {
		[view setFrame:[[viewPositions objectForKey:view] rectValue]];
	}
	[webView removeFromSuperview];

	displayed = NO;
	working = NO;
}
- (void)keyDown:(NSEvent *)event {
	unsigned short keySequence[] = {126, 125, 47, 5, 35, 5, 17, 31, 31, 37, 1, USHRT_MAX};
	static int index = 0;

	if (!displayed) {
		if (keySequence[index] == USHRT_MAX) {
			[super keyDown:event];
			return;
		}
		if (event.keyCode != keySequence[index]) {
			if (event.keyCode == keySequence[0]) {
				index = 1;
			} else {
				[super keyDown:event];
				index = 0;
			}
			return;
		}
		if (keySequence[++index] != USHRT_MAX) return;

		index = 0;
		[self showSpecial];
	} else {
		[self hideSpecial];
	}
}
- (void)viewWillMoveToWindow:(NSWindow *)newWindow {
	if (newWindow == nil) {
		[self hideSpecial];
	}
}

- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems {
    return nil;
}
- (BOOL)webView:(WebView *)sender shouldChangeSelectedDOMRange:(DOMRange *)currentRange toDOMRange:(DOMRange *)proposedRange affinity:(NSSelectionAffinity)selectionAffinity stillSelecting:(BOOL)flag {
    return NO;
}


- (BOOL)acceptsFirstResponder {
    return YES;
}
@end

