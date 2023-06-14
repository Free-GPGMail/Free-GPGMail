//
//  GMSupportPlanWindowController.m
//  GPGMail
//
//  Created by Lukas Pitschl on 20.09.18.
//

#import <Foundation/Foundation.h>
#import "MailApp.h"

#import "GMSupportPlanAssistantWindowController.h"
#import "DSClickableURLTextField.h"
#import "NSAttributedString+LOKit.h"

#import "GPGMailBundle.h"

#import "GMSupportPlanManager.h"
#import "GMSupportPlan.h"

NSString * const kGMSupportPlanAssistantActivationInformationEmailKey = @"GMSupportPlanAssistantActivationInformationEmail";
NSString * const kGMSupportPlanAssistantActivationInformationActivationCodeKey = @"GMSupportPlanAssistantActivationInformationActivationCode";

typedef enum {
    GMSupportPlanPaddleErrorCodeNetworkError = 99,
    GMSupportPlanPaddleErrorCodeActivationCodeNotFound = 100,
    GMSupportPlanPaddleErrorCodeActivationCodeAlreadyUsed = 104,
    GMSupportPlanServiceErrorCodeSupportPlanDisabled = 105
} GMSupportPlanPaddleErrorCodes;

@interface GMSupportPlanAssistantViewController ()

@property (nonatomic, strong) IBOutlet NSTextField *headerTextField;
@property (nonatomic, strong) IBOutlet NSTextField *subHeaderTextField;
@property (nonatomic, strong) IBOutlet DSClickableURLTextField *detailsTextField;

@property (nonatomic, strong) IBOutlet NSStackView *stackView;
@property (nonatomic, strong) IBOutlet NSStackView *subStackView;

@property (nonatomic, strong) IBOutlet NSView *activationCodeView;
@property (nonatomic, strong) IBOutlet NSTextField *emailLabel;
@property (nonatomic, strong) IBOutlet NSTextField *licenseLabel;
@property (nonatomic, strong) IBOutlet NSTextField *emailTextField;
@property (nonatomic, strong) IBOutlet NSTextField *licenseTextField;

@property (nonatomic, strong) IBOutlet NSView *infoTextView;
@property (nonatomic, strong) IBOutlet NSTextField *infoTextLabel;

@property (nonatomic, strong) IBOutlet NSTextField *grayInfoTextField;

@property (nonatomic, strong) IBOutlet NSView *dontAskAgainView;
@property (nonatomic, strong) IBOutlet NSButton *dontAskAgainCheckBox;

@property (nonatomic, strong) IBOutlet NSView *progressView;
@property (nonatomic, strong) IBOutlet NSProgressIndicator *progressIndicator;
@property (nonatomic, strong) IBOutlet NSTextField *progressTextField;

@property (nonatomic, strong) IBOutlet NSButton *continueButton;
@property (nonatomic, strong) IBOutlet NSButton *cancelButton;

@property (nonatomic, strong) IBOutlet NSView *horizontalLine;

- (void)restorePreviousState;

@end

@interface NSColor (Add)

+ (NSColor *)linkColor;

@end

@interface GMSupportPlanAssistantWindowController () <NSWindowDelegate>

@end

@implementation GMSupportPlanAssistantWindowController

- (instancetype)init
{
    self = [super init];
    if (self) {
    }
    return self;
}

- (NSNibName)windowNibName {
    return @"GMSupportPlanAssistantWindow";
}

- (NSBundle *)windowNibBundle {
    return [GPGMailBundle bundle];
}


- (void)windowDidLoad {
    [super windowDidLoad];
    
    [[self window] setDelegate:self];
}


#pragma mark - NSWindowDelegate

- (BOOL)windowShouldClose:(id)sender {
    return [(GMSupportPlanAssistantViewController *)[[self window] contentViewController] windowShouldClose:sender];
}

- (void)cancel:(id)sender {
    // This method is called when the user hits ESC.
    if([self windowShouldClose:sender]) {
        [self close];
    }
}

- (void)windowWillClose:(__unused NSNotification *)notification
{
     if ([[self delegate] respondsToSelector:@selector(supportPlanAssistantDidClose:)])
    {
        [[self delegate] supportPlanAssistantDidClose:self];
    }
}

- (void)showActivationError:(NSDictionary *)error {
    // This error is shown, if the local input validation did fail.
	// This happen, when the entered code has the wrong length or an invalid email was entered.
    NSAlert *alert = [GPGMailBundle customAlert];
    alert.informativeText = [error allValues][0];
    alert.messageText = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_FAILED_TITLE"]; // "Support Plan Activation Failed"
    [alert beginSheetModalForWindow:[self window] completionHandler:^(NSModalResponse __unused returnCode) {
    }];
}

- (void)activationDidCompleteWithSuccessForSupportPlan:(GMSupportPlan *)supportPlan {
    GMSupportPlanAssistantViewController *viewController = [self contentViewController];
    GMSupportPlanManager *supportPlanManager = [viewController supportPlanManager];

    // It is possible that fetching the trial information did succeed, but the
    // trial is expired.
    [viewController hideLoadingSpinner];
    if([supportPlan isKindOfTrial] && [supportPlan isExpired]) {
        [viewController setState:GMSupportPlanViewControllerStateBuy forceUpdate:YES];
        NSAlert *alert = [GPGMailBundle customAlert];
        alert.messageText = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_TRIAL_NO_NEW_TRIAL_ALLOWED_TITLE"];
        alert.informativeText = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_TRIAL_NO_NEW_TRIAL_ALLOWED_MESSAGE"];

        [alert beginSheetModalForWindow:[self window] completionHandler:^(NSModalResponse returnCode) {

        }];
        return;
    }

    // If the support plan is for a newer version, propose to restart Mail.
    if([supportPlanManager version:[supportPlan newestEligibleVersion] isNewerThanVersion:[supportPlanManager applicationVersion]]) {
        NSAlert *alert = [GPGMailBundle customAlert];
        alert.messageText = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_SUPPORT_PLAN_FOR_NEWER_VERSION_DETECTED_TITLE"];
        alert.informativeText = [NSString stringWithFormat:[GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_SUPPORT_PLAN_FOR_NEWER_VERSION_DETECTED_MESSAGE"], [GPGMailBundle productNameForVersion:[supportPlan newestEligibleVersion]], [GPGMailBundle productNameForVersion:[supportPlan newestEligibleVersion]]];
        [alert addButtonWithTitle:[GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_SUPPORT_PLAN_FOR_NEWER_VERSION_DETECTED_BUTTON_RESTART"]];
        [alert addButtonWithTitle:[GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_SUPPORT_PLAN_FOR_NEWER_VERSION_DETECTED_BUTTON_CANCEL"]];
        [alert beginSheetModalForWindow:[self window] completionHandler:^(NSModalResponse __unused returnCode) {
            [[self delegate] closeSupportPlanAssistant:[[self window] windowController]];
            if(returnCode == NSAlertFirstButtonReturn) {
                [(MailApp *)[NSClassFromString(@"MailApp") sharedApplication] quitAndRelaunchWithAdditionalArguments:nil];
            }
        }];
        return;
    }

    // It is possible that the activation did succeed, yet the support plan
    // is not valid for the current version. In that case, show the upgrade or keep dialog.
    if([supportPlan isValidExcludingAppName] && ![supportPlan isValid]) {
        [viewController setState:GMSupportPlanViewControllerStateInfo];
    }
    else {
        [viewController setState:GMSupportPlanViewControllerStateThanks];
    }
}

- (void)activationDidFailWithError:(NSError *)error {
    [(GMSupportPlanAssistantViewController *)[[self window] contentViewController] restorePreviousState];
    NSAlert *alert = [GPGMailBundle customAlert];

    BOOL closeWindow = NO;
    NSString *title = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_FAILED_TITLE"];

    if(error.code == GMSupportPlanPaddleErrorCodeNetworkError) {
        title = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_UNABLE_TO_CONNECT_TO_API_TRIAL_TITLE"];
        NSMutableString *errorDescription = [NSMutableString new];
        if([error.userInfo[@"is_trial"] boolValue]) {
            [errorDescription appendFormat:@"%@\n", [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_UNABLE_TO_CONNECT_TO_API_TRIAL_MESSAGE"]];
        }
        else {
            [errorDescription appendFormat:@"%@\n", [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_UNABLE_TO_CONNECT_TO_API_MESSAGE"]];
        }
        [errorDescription appendFormat:@"\n%@", [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_CONFIGURE_FIREWALL_MESSAGE"]];
        alert.informativeText = errorDescription;
    }
    else if(error.code == GMSupportPlanPaddleErrorCodeActivationCodeNotFound) {
        title = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_FAILED_CODE_INVALID_TITLE"];
        alert.informativeText = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_FAILED_CODE_INVALID"]; // "The entered activation code is invalid.\nPlease contact us at business@gpgtools.org if you are sure that you have entered your code correctly."
    }
    else if(error.code == GMSupportPlanPaddleErrorCodeActivationCodeAlreadyUsed) {
        title = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_FAILED_TOO_MANY_ACTIVATIONS_TITLE"];
        alert.informativeText = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_FAILED_TOO_MANY_ACTIVATIONS"]; // "We are very sorry to inform you that you have exceeded the allowed number of activations.\nPlease contact us at business@gpgtools.org, if you believe that you should still have activations left."
    }
    else if(error.code == GMSupportPlanServiceErrorCodeSupportPlanDisabled) {
        title = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_FAILED_SUPPORT_PLAN_DISABLED_TITLE"];
        alert.informativeText = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_FAILED_SUPPORT_PLAN_DISABLED"];
    }
    else {
        title = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_FAILED_GENERAL_ERROR_TITLE"];
        alert.informativeText = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_FAILED_GENERAL_ERROR"]; // "Unfortunately an unknown error has occurred. Please retry later or use 'System Preferences › GPG Suite › Send Report' to contact us"
    }

    if([error.userInfo[@"is_trial"] boolValue]) {
        [[[GPGMailBundle sharedInstance] supportPlanManager] installFallbackTrial];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"GMSupportPlanStateChangeNotification" object:self];
        if([[[GPGMailBundle sharedInstance] supportPlanManager] supportPlanIsActive]) {
            alert.informativeText = [alert.informativeText stringByAppendingFormat:[GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_UNABLE_TO_CONNECT_TO_API_TRIAL_FALLBACK_MESSAGE"], [[[GPGMailBundle sharedInstance] supportPlanManager] remainingTrialDays]];
            closeWindow = YES;
        }
    }

    alert.messageText = title; // "Support Plan Activation Failed"
    [alert beginSheetModalForWindow:[self window] completionHandler:^(NSModalResponse returnCode) {
        if(self.closeWindowAfterError || closeWindow) {
            [[self delegate] closeSupportPlanAssistant:self];
        }
    }];
}

- (void)performAutomaticSupportPlanActivationWithActivationCode:(NSString *)activationCode email:(NSString *)email {
    GMSupportPlanAssistantViewController *supportPlanAssistantViewController = (GMSupportPlanAssistantViewController *)[self contentViewController];
    [supportPlanAssistantViewController performAutomaticSupportPlanActivationWithActivationCode:activationCode email:email];
    return;
}

- (instancetype)initWithSupportPlanManager:(GMSupportPlanManager *)supportPlanManager {
    self = [super init];
    if(self) {
//        _supportPlanManager = supportPlanManager;
    }
    return self;
}

@end


@implementation GMSupportPlanAssistantViewController

- (NSNibName)nibName {
    return @"GMSupportPlanAssistantView";
}

- (NSBundle *)nibBundle {
    return [GPGMailBundle bundle];
}

- (void)overridePreviousState:(GMSupportPlanAssistantViewControllerState)state {
    _previousState = state;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _previousState = GMSupportPlanViewControllerStateUninitialized;

    GMSupportPlanAssistantViewControllerState currentState = GMSupportPlanViewControllerStateBuy;

    // By default the current status of the support plan is always checked first.
    // If however the user chose to switch support plan, there's no need to check
    // the current status.
    if(self.initialDialogType != GMSupportPlanAssistantDialogTypeSwitchSupportPlan) {
        GMSupportPlanManagerUpgradeState upgradeState = [self.supportPlanManager upgradeState];

        if(upgradeState == GMSupportPlanManagerUpgradeStateUpgradeOrKeepVersion3 || upgradeState == GMSupportPlanManagerUpgradeStateUpgradeFromVersion3ToVersion4) {
            currentState = GMSupportPlanViewControllerStateCheckingSupportPlanStatus;
        }
    }


    [self setState:currentState];

    if(currentState == GMSupportPlanViewControllerStateCheckingSupportPlanStatus) {
        [self.supportPlanManager migratePaddleActivationWithCompletionHandler:^(GMSupportPlan * _Nullable supportPlan, __unused NSDictionary * _Nullable result, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if([supportPlan isValid]) {
                    [self setState:GMSupportPlanViewControllerStateThanks];
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"GMSupportPlanStateChangeNotification" object:[GPGMailBundle sharedInstance]];
                }
                else {
                    [self setState:GMSupportPlanViewControllerStateInfo];
                }
            });
        }];
    }

}

- (GMSupportPlanAssistantDialogType)dialogTypeWithStateHint:(GMSupportPlanAssistantViewControllerState)state {
    if(state == GMSupportPlanViewControllerStateBuy) {
        // If a previous support plan exists, instead of the activation screen,
        // display a custom switch support plan screen.
        if(self.initialDialogType == GMSupportPlanAssistantDialogTypeSwitchSupportPlan) {
			return GMSupportPlanAssistantDialogTypeSwitchSupportPlan;
		}
        if(![self.supportPlanManager supportPlanIsActive]) {
            return [self.supportPlanManager supportPlanState] == GMSupportPlanStateTrialExpired ? GMSupportPlanAssistantDialogTypeTrialExpired : GMSupportPlanAssistantDialogTypeInactive;
        }
        if([self.supportPlanManager supportPlanState] == GMSupportPlanStateTrial) {
            return [[self.supportPlanManager supportPlan] isAboutToExpire] ? GMSupportPlanAssistantDialogTypeTrialAboutToExpire : GMSupportPlanAssistantDialogTypeTrial;
        }
    }

    return GMSupportPlanAssistantDialogTypeInactive;
}

- (NSString *)compatibilityInfoText {
    return [self compatibilityInfoTextForVersion:[self.supportPlanManager applicationVersion]];
}

- (NSString *)compatibilityInfoTextLongVersionWithPreviousVersion:(NSString *)previousVersion {
    NSMutableArray *compatibilityTextParts = [NSMutableArray new];
    [compatibilityTextParts addObject:[self compatibilityInfoText]];
    if(previousVersion) {
        [compatibilityTextParts addObject:[self compatibilityInfoTextForVersion:previousVersion]];
    }
    [compatibilityTextParts addObject:[GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_DIALOG_VERSION_COMPATIBILITY_NO_GUARANTEE_INFO"]];
    return [compatibilityTextParts componentsJoinedByString:@" "];
}

- (NSString *)compatibilityInfoTextForVersion:(NSString *)version {
    NSDictionary *osNames = @{
        @"10.13": @"High Sierra", @"10.14": @"Mojave",
        @"10.15": @"Catalina", @"11.0": @"Big Sur", @"12.0": @"Monterey"};
	// Adjust for new versions.
    NSDictionary *versionInfo = @{
        @"3": @[@"10.14", @"10.13"],
        @"4": @[@"10.15", @"10.14", @"10.13"],
        @"5": @[@"11.0", @"10.15", @"10.14"],
        @"6": @[@"12.0"]
    };

    NSMutableArray *compatibilityTextParts = [NSMutableArray new];
    for(NSString *currentVersion in versionInfo[version]) {
        [compatibilityTextParts addObject:osNames[currentVersion]];
    }
    NSString *compatibilityOSText = [compatibilityTextParts componentsJoinedByString:@", "];

    NSString *compatibilityInfo = [NSString stringWithFormat:[GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_DIALOG_VERSION_DYNAMIC_COMPATIBILITY_INFO"], [self productNameForVersion:version], [@"macOS " stringByAppendingString:compatibilityOSText]];

    return compatibilityInfo;
}

- (NSString *)productNameForVersion:(NSString *)version {
    return [GPGMailBundle productNameForVersion:version];
}

- (NSString *)productName {
    return [self productNameForVersion:[self.supportPlanManager applicationVersion]];
}

- (NSString *)introText {
    NSString *introText = [NSString stringWithFormat:[GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_DIALOG_HEADER_WELCOME_DYNAMIC"], [self productName]];
    return introText;
}

- (NSString *)coveredVersionsForPreviousSupportPlanText {
    GMSupportPlan *previousSupportPlan = [self.supportPlanManager supportPlanForPreviousVersion];
    NSMutableArray *parts = [NSMutableArray new];
    for(NSString *version in [previousSupportPlan eligibleVersions]) {
        [parts addObject:[NSString stringWithFormat:@"%@", [self productNameForVersion:version]]];
    }

    return [parts componentsJoinedByString:@", "];
}

- (void)configureTextForState:(GMSupportPlanAssistantViewControllerState)state {
    GMSupportPlanManager *supportPlanManager = self.supportPlanManager;

    NSString *continueButtonTitle = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_DIALOG_BUTTON_BUY"]; // "Buy Now";
    NSInteger continueButtonTag = GMSupportPlanAssistantBuyActivateButtonStateBuy;

    if(state == GMSupportPlanViewControllerStateBuy) {
        NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSColor linkColor], NSForegroundColorAttributeName,
                                    [NSURL URLWithString:@"https://gpgtools.org/buy-support-plan"], NSLinkAttributeName,
                                    nil];

        self.grayInfoTextField.stringValue = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_DIALOG_LOCATE_ACTIVATION_CODE"];
        self.grayInfoTextField.stringValue = [self.grayInfoTextField.stringValue stringByAppendingFormat:@"\n\n%@", [self compatibilityInfoTextLongVersionWithPreviousVersion:nil]];
        self.headerTextField.stringValue = [self introText];

        NSNumber *remainingTrialDays = [supportPlanManager remainingTrialDays];
        BOOL trialStarted = YES;
        if(!remainingTrialDays) {
            remainingTrialDays = @(30);
            trialStarted = NO;
        }

        NSTextField *alreadyHaveSupportPlanInfo = nil;

        GMSupportPlanAssistantDialogType dialogType = [self dialogTypeWithStateHint:GMSupportPlanViewControllerStateBuy];
        if(dialogType == GMSupportPlanAssistantDialogTypeTrialExpired || dialogType == GMSupportPlanAssistantDialogTypeTrialAboutToExpire || dialogType == GMSupportPlanAssistantDialogTypeTrial) {
            self.headerTextField.stringValue = [NSString stringWithFormat:[GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_DIALOG_HEADER_TRIAL"], [self productName]];
        }
        if(dialogType == GMSupportPlanAssistantDialogTypeTrialExpired) {
            self.subHeaderTextField.stringValue = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_DIALOG_SUBHEADER_TRIAL_EXPIRED"];

            self.detailsTextField.stringValue = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_DIALOG_TRIAL_EXPIRED_DETAILS_TEXT"];
            self.infoTextLabel.hidden = NO;
            alreadyHaveSupportPlanInfo = self.infoTextLabel;
        }
        else if(dialogType == GMSupportPlanAssistantDialogTypeTrialAboutToExpire) {
            NSString *format = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_DIALOG_TRIAL_ABOUT_TO_EXPIRE_SUBHEADER"];
            self.subHeaderTextField.stringValue = [NSString stringWithFormat:format, remainingTrialDays];
            self.detailsTextField.stringValue = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_DIALOG_TRIAL_ABOUT_TO_EXPIRE_DETAILS_TEXT"];
            alreadyHaveSupportPlanInfo = self.infoTextLabel;
        }
        else if(dialogType == GMSupportPlanAssistantDialogTypeTrial) {
            NSString *format = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_DIALOG_TRIAL_CONTINUE_SUBHEADER"];
            self.subHeaderTextField.stringValue = [NSString stringWithFormat:format, remainingTrialDays];
            alreadyHaveSupportPlanInfo = self.detailsTextField;
        }
        else if(dialogType == GMSupportPlanAssistantDialogTypeInactive) {
            NSString *format = format = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_DIALOG_INACTIVE_SUBHEADER"]; // "You can test GPG Mail free for %@ more days.\nSecure your emails now!"
            self.subHeaderTextField.stringValue = [NSString stringWithFormat:format, remainingTrialDays];
            alreadyHaveSupportPlanInfo = self.detailsTextField;
        }
        else if(dialogType == GMSupportPlanAssistantDialogTypeSwitchSupportPlan) {
            self.headerTextField.stringValue = [self productName];
            self.subHeaderTextField.stringValue = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_DIALOG_SUBHEADER_SWITCH_PLAN"];
            self.detailsTextField.stringValue = [NSString stringWithFormat:[GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_DIALOG_SWITCH_PLAN_DETAILS_TEXT_DYNAMIC"], [self coveredVersionsForPreviousSupportPlanText], [self productName]];
            self.infoTextLabel.hidden = YES;
            self.grayInfoTextField.stringValue = [self compatibilityInfoTextLongVersionWithPreviousVersion:nil];
            alreadyHaveSupportPlanInfo = nil;
            // By default disable the button.
            self.continueButton.enabled = NO;
            continueButtonTitle = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_DIALOG_BUTTON_ACTIVATE"]; // "Activate"
            continueButtonTag = GMSupportPlanAssistantBuyActivateButtonStateActivate;
        }

        alreadyHaveSupportPlanInfo.attributedStringValue = ({
            [NSAttributedString lo_attributedStringWithBaseAttributes:nil
                                                   argumentAttributes:attributes
                                                         formatString:
             [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_DIALOG_PURCHASED_ALREADY_MESSAGE"], // "If you have already purchased a support plan, activate it now and enjoy GPG Mail!"
             [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_DIALOG_PURCHASED_ALREADY_HYPERLINK_PART"], // "support plan"
             nil];
        });
        alreadyHaveSupportPlanInfo.hidden = NO;

        self.continueButton.title = continueButtonTitle;
        self.continueButton.tag = continueButtonTag;

        if(dialogType == GMSupportPlanAssistantDialogTypeTrialExpired || dialogType == GMSupportPlanAssistantDialogTypeSwitchSupportPlan) {
            self.cancelButton.tag = GMSupportPlanAssistantButtonActionClose;
            self.cancelButton.title = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_DIALOG_BUTTON_CLOSE"];
        }
        else if(dialogType == GMSupportPlanAssistantDialogTypeTrial || dialogType == GMSupportPlanAssistantDialogTypeTrialAboutToExpire) {
            self.cancelButton.title = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_DIALOG_BUTTON_CONTINUE_TRIAL"]; // "Continue Trial"
            self.cancelButton.tag = GMSupportPlanAssistantButtonActionContinueTrial;
        }
        else {
            self.cancelButton.title = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_DIALOG_BUTTON_START_TRIAL"]; // "Start Trial"
            self.cancelButton.tag = GMSupportPlanAssistantButtonActionStartTrial;
        }

        self.emailLabel.stringValue = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_DIALOG_EMAIL_LABEL"]; // "Email"
        self.licenseLabel.stringValue = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_DIALOG_ACTIVATION_CODE_LABEL"]; // "Activation Code"
        self.progressTextField.stringValue = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_DIALOG_PROGRESS_TEXT"]; // "Activating your copy of GPG Mail"
    }
    else if(state == GMSupportPlanViewControllerStateInfo || state == GMSupportPlanViewControllerStateCheckingSupportPlanStatus) {
        GMSupportPlanManagerUpgradeState upgradeState = [supportPlanManager upgradeState];
        GMSupportPlanState supportPlanState = [supportPlanManager supportPlanState];

        self.headerTextField.stringValue = [self introText];
        self.infoTextLabel.hidden = NO;
        if(upgradeState == GMSupportPlanManagerUpgradeStateUpgradeFromVersion3ToVersion4) {
            self.subHeaderTextField.stringValue = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_UPGRADE_DIALOG_SUBHEADER"];

            self.progressTextField.stringValue = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_DIALOG_PROGRESS_TEXT"]; // "Activating your copy of GPG Mail"
            //self.dontAskAgainCheckBox.title = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_DONT_ASK_AGAIN"]; // "Don't ask again"
            //self.showDontAskAgain = YES;
            // Bug #1101: Upgrade request message of GPG Mail 6 wrongly references macOS Big Sur
            //
            // Instead of hard coding the macOS name use `+[GPGMailBundle latestSupportedMacOSVersion]` which
            // is adjusted for new macOS versions.
            self.detailsTextField.stringValue = [NSString stringWithFormat:[GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_UPGRADE_DIALOG_UPGRADE_REQUIRED_TITLE"], [self productName], [GPGMailBundle latestSupportedMacOSVersion]];
            self.infoTextLabel.stringValue = [NSString stringWithFormat:[GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_UPGRADE_DIALOG_UPGRADE_REQUIRED_EXPLANATION"], @"30%"];
            if(supportPlanState != GMSupportPlanStateTrialExpired) {
                self.infoTextLabel.stringValue = [[self.infoTextLabel.stringValue stringByAppendingString:@"\n\n"] stringByAppendingFormat:[GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_UPGRADE_DIALOG_UPGRADE_REQUIRED_START_TRIAL_EXPLANATION"], @"30"];
            }
            self.grayInfoTextField.stringValue = [self compatibilityInfoTextLongVersionWithPreviousVersion:nil];

            self.continueButton.title = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_UPGRADE_DIALOG_UPGRADE_BUTTON_UPGRADE"];
            self.continueButton.tag = GMSupportPlanAssistantBuyActivateButtonStateUpgrade;
            self.continueButton.enabled = YES;
            BOOL trialStarted = NO;
            if([supportPlanManager supportPlan] && [supportPlanManager remainingTrialDays] != nil) {
                trialStarted = YES;
            }

            if(supportPlanState == GMSupportPlanStateTrialExpired) {
                self.cancelButton.title = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_DIALOG_BUTTON_CLOSE"];
                self.cancelButton.tag = GMSupportPlanAssistantButtonActionCloseWithWarning;
            }
            else {
                self.cancelButton.title = trialStarted ? [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_DIALOG_BUTTON_CONTINUE_TRIAL"] : [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_DIALOG_BUTTON_START_TRIAL"]; // "Continue Trial"
                self.cancelButton.tag = trialStarted ? GMSupportPlanAssistantButtonActionContinueTrial : GMSupportPlanAssistantButtonActionStartTrial;
            }
        }
        else {
            self.progressTextField.stringValue = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_DIALOG_PROGRESS_TEXT"]; // "Activating your copy of GPG Mail"
            self.dontAskAgainCheckBox.title = @"Don't ask me again"; // TODO: [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_DONT_ASK_AGAIN"]; // "Don't ask again"
            self.showDontAskAgain = YES;
            self.detailsTextField.stringValue = [NSString stringWithFormat:[GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_UPGRADE_DIALOG_UPGRADE_OR_KEEP_TITLE"], [self productName]];
            self.subHeaderTextField.stringValue = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_UPGRADE_DIALOG_SUBHEADER"];
            NSString *previousVersion = [[self.supportPlanManager supportPlanForPreviousVersion] newestEligibleVersion];
            NSString *previousProductName = [self productNameForVersion:previousVersion];
            self.infoTextLabel.stringValue = [NSString stringWithFormat:[GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_UPGRADE_DIALOG_UPGRADE_OR_KEEP_EXPLANATION"], previousProductName, [GPGMailBundle latestSupportedMacOSVersion], @"30%", previousProductName];
            self.grayInfoTextField.stringValue = [self compatibilityInfoTextLongVersionWithPreviousVersion:previousVersion];

            // TODO: Make sure to check that the keep version is compatible with this system.
            self.cancelButton.title = [NSString stringWithFormat:[GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_UPGRADE_DIALOG_UPGRADE_OR_KEEP_BUTTON_KEEP"], previousProductName];
            self.cancelButton.tag = GMSupportPlanAssistantButtonActionKeepVersion3;

            self.continueButton.title = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_UPGRADE_DIALOG_UPGRADE_BUTTON_UPGRADE"];
            self.continueButton.tag = GMSupportPlanAssistantButtonActionUpgrade;
            self.continueButton.enabled = YES;
        }

        if(state == GMSupportPlanViewControllerStateCheckingSupportPlanStatus) {
            NSString *previousVersion = [[self.supportPlanManager supportPlanForPreviousVersion] newestEligibleVersion];
            NSString *previousProductName = [self productNameForVersion:previousVersion];
            self.detailsTextField.stringValue = [NSString stringWithFormat:[GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_STATUS_UPDATE_DIALOG_EXPLANATION_TITLE"], previousProductName, [self productName]];
            self.progressTextField.stringValue = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_STATUS_UPDATE_DIALOG_PROGRESS_TEXT"];
        }
    }

    if(state == GMSupportPlanViewControllerStateThanks) {
        self.headerTextField.stringValue = [self introText];

        NSString *previousVersion = [[self.supportPlanManager supportPlanForPreviousVersion] newestEligibleVersion];
        NSString *previousProductName = [self productNameForVersion:previousVersion];
        self.grayInfoTextField.stringValue = [self compatibilityInfoTextLongVersionWithPreviousVersion:previousVersion];

        if([supportPlanManager supportPlanState] == GMSupportPlanStateTrial) {
            self.subHeaderTextField.stringValue = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_THANKS_DIALOG_TRIAL_SUBHEADER"];
            self.detailsTextField.stringValue = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_THANKS_DIALOG_TRIAL_SUCCESS_MESSAGE"];
        }
        else {
            self.subHeaderTextField.stringValue = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_THANKS_DIALOG_SUBHEADER"];
            self.detailsTextField.stringValue = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_THANKS_DIALOG_SUCCESS_MESSAGE"];
            NSDictionary *meta = [[supportPlanManager supportPlan] metadata];
            NSDictionary *effu = [meta valueForKey:@"effu"];
            if(effu && effu[@"purchase_date"] != nil && [effu[@"eligible"] boolValue]) {
                NSString *effuText = [NSString stringWithFormat:[GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_THANKS_DIALOG_EFFU_MESSAGE_DYNAMIC"], previousProductName, [self productName]];
                self.detailsTextField.stringValue = [NSString stringWithFormat:@"%@\n\n%@", effuText, self.detailsTextField.stringValue];
            }
        }
        _continueButton.title = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_DIALOG_BUTTON_CLOSE"];
        _continueButton.tag = GMSupportPlanAssistantButtonActionClose;
        _continueButton.enabled = YES;
    }
}

- (void)setState:(GMSupportPlanAssistantViewControllerState)state forceUpdate:(BOOL)forceUpdate {
    if (_state != state || forceUpdate) {
        GMSupportPlanState supportPlanState = [[self supportPlanManager] supportPlanState];
        GMSupportPlanAssistantViewControllerState lastPreviousState = _previousState;

        // The activating state doesn't influence text, so it can be ignored.
        _previousState = _state;

        _state = state;

        // Only update the texts belonging to the current state, if there was a
        // proper code change.
        if(state != lastPreviousState || forceUpdate) {
            [self configureTextForState:state];
        }

        if(state == GMSupportPlanViewControllerStateCheckingSupportPlanStatus) {
            [_stackView setDetachesHiddenViews:YES];
            [_subStackView setVisibilityPriority:NSStackViewVisibilityPriorityMustHold forView:_progressView];

            [_subStackView setVisibilityPriority:NSStackViewVisibilityPriorityNotVisible forView:_dontAskAgainView];
            [_subStackView setVisibilityPriority:NSStackViewVisibilityPriorityNotVisible forView:[_grayInfoTextField superview]];
            [_stackView setVisibilityPriority:NSStackViewVisibilityPriorityNotVisible forView:_activationCodeView];
            [_stackView setVisibilityPriority:NSStackViewVisibilityPriorityNotVisible forView:_infoTextView];

            _horizontalLine.hidden = YES;
            _continueButton.hidden = YES;
            _cancelButton.hidden = YES;
        }
        else if(state == GMSupportPlanViewControllerStateInfo) {
            [_subStackView setDetachesHiddenViews:NO];
            [_subStackView setVisibilityPriority:NSStackViewVisibilityPriorityMustHold forView:_progressView];

            [_subStackView setVisibilityPriority:NSStackViewVisibilityPriorityMustHold forView:[_grayInfoTextField superview]];
            [_grayInfoTextField superview].hidden = NO;
            _grayInfoTextField.hidden = NO;

            [_stackView setVisibilityPriority:NSStackViewVisibilityPriorityNotVisible forView:_activationCodeView];
            [_stackView setVisibilityPriority:NSStackViewVisibilityPriorityMustHold forView:_infoTextView];
            [_subStackView setVisibilityPriority:NSStackViewVisibilityPriorityNotVisible forView:_dontAskAgainView];
            _dontAskAgainView.hidden = YES;

            _horizontalLine.hidden = NO;
            _continueButton.hidden = NO;
            _cancelButton.hidden = NO;
        }
        else if(state == GMSupportPlanViewControllerStateThanks) {
            [_stackView setDetachesHiddenViews:YES];
            [_subStackView setVisibilityPriority:NSStackViewVisibilityPriorityNotVisible forView:_progressView];

            [_subStackView setVisibilityPriority:NSStackViewVisibilityPriorityNotVisible forView:_dontAskAgainView];
            [_subStackView setVisibilityPriority:NSStackViewVisibilityPriorityMustHold forView:[_grayInfoTextField superview]];
            [_grayInfoTextField superview].hidden = NO;
            _grayInfoTextField.hidden = NO;

            [_stackView setVisibilityPriority:NSStackViewVisibilityPriorityNotVisible forView:_activationCodeView];
            [_stackView setVisibilityPriority:NSStackViewVisibilityPriorityNotVisible forView:_infoTextView];

            _horizontalLine.hidden = NO;
            _continueButton.hidden = NO;
            _continueButton.enabled = YES;
            _cancelButton.hidden = YES;
        }
        else {
            [_subStackView setVisibilityPriority:NSStackViewVisibilityPriorityNotVisible forView:_dontAskAgainView];
            if((supportPlanState == GMSupportPlanStateTrialExpired || [[[self supportPlanManager] supportPlan] isAboutToExpire]) && ![self.supportPlanManager shouldPromptUserForUpgrade]) {
                [_stackView setVisibilityPriority:NSStackViewVisibilityPriorityMustHold forView:_infoTextView];
            }
            else {
                [_stackView setVisibilityPriority:NSStackViewVisibilityPriorityNotVisible forView:_infoTextView];
            }

            [_subStackView setVisibilityPriority:NSStackViewVisibilityPriorityMustHold forView:_progressView];
            [_stackView setVisibilityPriority:NSStackViewVisibilityPriorityMustHold forView:_activationCodeView];
        }



        _emailTextField.enabled = (state == GMSupportPlanViewControllerStateBuy);
        _licenseTextField.enabled = (state == GMSupportPlanViewControllerStateBuy);
        _emailTextField.editable = (state == GMSupportPlanViewControllerStateBuy);
        _licenseTextField.editable = (state == GMSupportPlanViewControllerStateBuy);
        _progressView.hidden = (state != GMSupportPlanViewControllerStateActivating && state != GMSupportPlanViewControllerStateCheckingSupportPlanStatus);

        if (state == GMSupportPlanViewControllerStateActivating || state == GMSupportPlanViewControllerStateCheckingSupportPlanStatus) {
            [_progressIndicator startAnimation:nil];
        } else {
            [_progressIndicator stopAnimation:nil];
        }
        _continueButton.enabled = (state == GMSupportPlanViewControllerStateBuy || state == GMSupportPlanViewControllerStateInfo || state == GMSupportPlanViewControllerStateThanks);
        // If the user wants to switch support plan, the button will be activated, once they entered
        // proper support plan details.
        if(self.initialDialogType == GMSupportPlanAssistantDialogTypeSwitchSupportPlan) {
            if(state != GMSupportPlanViewControllerStateThanks) {
                _continueButton.enabled = NO;
            }
        }
        if(state == GMSupportPlanViewControllerStateCheckingSupportPlanStatus) {
            _cancelButton.enabled = NO;
        }
        else {
            _cancelButton.enabled = YES;
        }
    }
}

- (void)setState:(GMSupportPlanAssistantViewControllerState)state {
    [self setState:state forceUpdate:NO];
}

- (void)setShowDontAskAgain:(BOOL)showDontAskAgain {
	if (_showDontAskAgain != showDontAskAgain) {
		_showDontAskAgain = showDontAskAgain;
		
//        if (showDontAskAgain && _state == GMSupportPlanViewControllerStateInfo) {
//            [_subStackView setVisibilityPriority:NSStackViewVisibilityPriorityMustHold forView:_dontAskAgainView];
//        } else {
//            [_subStackView setVisibilityPriority:NSStackViewVisibilityPriorityNotVisible forView:_dontAskAgainView];
//        }
	}
}

- (void)setEmail:(NSString *)email {
    if(![email length]) {
        
    }
    if(_email != email) {
        _email = email;
        [self updateBuyButton];
    }
}

- (void)setActivationCode:(NSString *)activationCode {
    if(![activationCode length]) {
        
    }
    if(_activationCode != activationCode) {
        _activationCode = activationCode;
        [self updateBuyButton];
    }
}

- (void)updateBuyButton {
    GMSupportPlanAssistantBuyActivateButtonState wantsState = [self.activationCode length] || [self.email length] || self.initialDialogType == GMSupportPlanAssistantDialogTypeSwitchSupportPlan ? GMSupportPlanAssistantBuyActivateButtonStateActivate : GMSupportPlanAssistantBuyActivateButtonStateBuy;

    if(wantsState == GMSupportPlanAssistantBuyActivateButtonStateBuy) {
        _continueButton.title = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_DIALOG_BUTTON_BUY"]; // "Buy Now"
        _continueButton.tag = GMSupportPlanAssistantBuyActivateButtonStateBuy;
        _continueButton.enabled = YES;
    }
    else {
        _continueButton.title = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_DIALOG_BUTTON_ACTIVATE"]; // "Activate"
        _continueButton.tag = GMSupportPlanAssistantBuyActivateButtonStateActivate;
        _continueButton.enabled = [self.activationCode length] || [self.email length] ? YES : NO;
    }
}

- (IBAction)activate:(NSButton *)sender {
    if(sender.tag == GMSupportPlanAssistantButtonActionClose) {
        [[self delegate] closeSupportPlanAssistant:[[[self view] window] windowController]];
        return;
    }
    if([(NSButton *)sender tag] == GMSupportPlanAssistantBuyActivateButtonStateUpgrade) {
        if([[self supportPlanManager] isMultiUser]) {
            [self showUpgradeURLFetchOperationFailedAlertForError:[NSError errorWithDomain:@"org.gpgtools.gpgmail" code:GMSupportPlanAPIErrorUpgradeURLVolume userInfo:nil]];
            return;
        }
        [self showLoadingSpinnerWithMessage:[GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_UPGRADE_DIALOG_FETCHING_UPGRADE_URL_PROGRESS_TEXT"] disableButtons:@[_continueButton, _cancelButton]];

        [self.supportPlanManager fetchUpgradeURLWithCompletionHandler:^(
         GMSupportPlan * __nullable __unused supportPlan, NSDictionary * __nullable result, NSError * __nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self hideLoadingSpinnerAndReenableButtons:@[_continueButton, _cancelButton]];
                if(error) {
                    [self showUpgradeURLFetchOperationFailedAlertForError:error];
                    return;
                }
                NSString *upgradeURL = result[@"url"];
                if([upgradeURL length]) {
                    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:upgradeURL]];
                }
                [self hideLoadingSpinnerAndReenableButtons:@[_continueButton, _cancelButton]];
                [[self delegate] closeSupportPlanAssistant:[[[self view] window] windowController]];
            });
        }];
    }
    else if([(NSButton *)sender tag] == GMSupportPlanAssistantBuyActivateButtonStateBuy) {
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://gpgtools.org/buy-support-plan"]];
    }
    else {
        NSString *email = [self whitespaceStripped:[self.email copy]];
        NSString *activationCode = [self whitespaceStripped:[self.activationCode copy]];
        if(email && self.emailTextField.stringValue != email) {
            self.emailTextField.stringValue = email;
        }
        if(activationCode && self.licenseTextField.stringValue != activationCode) {
            self.licenseTextField.stringValue = activationCode;
        }

        NSDictionary *activationInformation = @{
            kGMSupportPlanAssistantActivationInformationEmailKey: email == nil ? @"" : email,
            kGMSupportPlanAssistantActivationInformationActivationCodeKey: activationCode == nil ? @"" : activationCode
        };

        NSDictionary __autoreleasing *error = nil;
        if(![self validateActivationInformation:activationInformation error:&error]) {
            [(GMSupportPlanAssistantWindowController *)[[[self view] window] windowController] showActivationError:error];
        }
        else {
            // Unset initial dialog type, since otherwise the continue button is deactivated, once the state
            // changes again.
            self.initialDialogType = GMSupportPlanAssistantDialogTypeInactive;

            [self setState:GMSupportPlanViewControllerStateActivating];
            [[self delegate] supportPlanAssistant:[[[self view] window] windowController]
                                            email:email
                                   activationCode:activationCode];
        }
    }
}

- (NSString *)whitespaceStripped:(NSString *)value {
    NSCharacterSet *whitespaceSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    return [value stringByTrimmingCharactersInSet:whitespaceSet];
}

- (void)showUpgradeURLFetchOperationFailedAlertForError:(NSError *)error {
    NSAlert *alert = [GPGMailBundle customAlert];

    if(error.code == GMSupportPlanAPIErrorUpgradeURLVolume) {
        alert.messageText = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_UPGRADE_DIALOG_ERROR_ALERT_VOLUME_TITLE"];
        alert.informativeText = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_UPGRADE_DIALOG_ERROR_ALERT_VOLUME_MESSAGE"];
    }
    else {
        alert.messageText = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_UPGRADE_DIALOG_ERROR_ALERT_SERVER_TITLE"];
        alert.informativeText = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_UPGRADE_DIALOG_ERROR_ALERT_SERVER_MESSAGE"];
    }

    [alert beginSheetModalForWindow:[[self view] window] completionHandler:^(NSModalResponse returnCode) {
        if(error.code != GMSupportPlanAPIErrorUpgradeURLVolume) {
            [[self delegate] closeSupportPlanAssistant:[[[self view] window] windowController]];
        }
    }];
}

- (void)showLoadingSpinnerWithMessage:(NSString *)message disableButtons:(NSArray <NSButton *> *)buttons {
    if([buttons count]) {
        for(NSButton *button in buttons) {
            button.enabled = NO;
        }
    }
    _progressView.hidden = NO;
    _progressTextField.stringValue = message;
    [_progressIndicator startAnimation:nil];
}

- (void)hideLoadingSpinnerAndReenableButtons:(NSArray <NSButton *> *)buttons {
    if([buttons count]) {
        for(NSButton *button in buttons) {
            button.enabled = YES;
        }
    }

    [_progressIndicator stopAnimation:nil];
    _progressView.hidden = YES;
}

- (void)hideLoadingSpinner {
    [self hideLoadingSpinnerAndReenableButtons:@[_cancelButton, _continueButton]];
}

- (BOOL)validateActivationInformation:(NSDictionary *)activationInformation error:(NSDictionary **)error {
    // Check email for not-empty and @ sign.
    NSMutableDictionary *validationError = [NSMutableDictionary new];
    NSString *email = activationInformation[kGMSupportPlanAssistantActivationInformationEmailKey];
    NSString *activationCode = activationInformation[kGMSupportPlanAssistantActivationInformationActivationCodeKey];
    if([email length] <= 5 || [email rangeOfString:@"@"].location == NSNotFound) {
        validationError[kGMSupportPlanAssistantActivationInformationEmailKey] = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_FAILED_INPUT_EMAIL_INVALID"];
    }
    else if([activationCode length] <= 20 || [self.activationCode length] >= 44 + 10) {
        validationError[kGMSupportPlanAssistantActivationInformationActivationCodeKey] = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_FAILED_INPUT_INVALID"];
    }

    BOOL valid = YES;
    if([[validationError allKeys] count] > 0) {
        valid = NO;
        *error = [validationError copy];
    }

    return valid;
}

- (void)cancelOperation:(id)sender {
    if([self windowShouldClose:sender]) {
        [(NSWindowController * )[[[self view] window] windowController] close];
    }
}

- (IBAction)performSecondaryAction:(NSButton *)sender {
    // TODO: What to do on ESC click. ESC calls cancel:
    if(sender.tag == GMSupportPlanAssistantButtonActionKeepVersion3) {
        [self showKeepExplanationDialogAndRelaunchMail];
        return;
    }
    else if(sender.tag == GMSupportPlanAssistantButtonActionCloseWithWarning) {
        [self windowShouldClose:sender];
        return;
    }
    else if(sender.tag == GMSupportPlanAssistantButtonActionClose || sender.tag == GMSupportPlanAssistantButtonActionContinueTrial) {
        [[self delegate] closeSupportPlanAssistant:[[[self view] window] windowController]];
        return;
    }
    else if(sender.tag == GMSupportPlanAssistantButtonActionStartTrial) {
        //[self setState:GMSupportPlanViewControllerStateActivatingTrial];
        [self showLoadingSpinnerWithMessage:[GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_DIALOG_START_TRIAL_PROGRESS_TEXT"] disableButtons:@[_cancelButton, _continueButton]];
        [[self delegate] supportPlanAssistantShouldStartTrial:[[[self view] window] windowController]];
        return;
    }
}

- (void)performAutomaticSupportPlanActivationWithActivationCode:(NSString *)activationCode email:(NSString *)email {
    if([[self supportPlanManager] supportPlanIsActive] && ![[[self supportPlanManager] supportPlan] isKindOfTrial]) {
        // Support plan is already activated so the information for automatic information can be removed.
        // Otherwise the thanks dialog would be displayed at every startup.
        [[GPGMailBundle sharedInstance] removeSupportPlanInformationForAutomaticActivation];
        [self setState:GMSupportPlanViewControllerStateThanks];
        return;
    }

    self.email = email;
    self.activationCode = activationCode;
    [self activate:_continueButton];
}

- (void)showAlreadyActivatedAlert {
    NSAlert *alert = [GPGMailBundle customAlert];
    alert.messageText = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_DIALOG_ERROR_ALERT_ACTIVATED_TITLE"];
    alert.informativeText = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_DIALOG_ERROR_ALERT_ACTIVATED_MESSAGE"];
    [alert beginSheetModalForWindow:[[self view] window] completionHandler:^(NSModalResponse returnCode) {
        [[self delegate] closeSupportPlanAssistant:[[[self view] window] windowController]];
    }];
}

- (void)restorePreviousState {
    [self setState:_previousState];
}

- (void)showKeepExplanationDialogAndRelaunchMail {
    NSString *previousVersion = [[self.supportPlanManager supportPlanForPreviousVersion] newestEligibleVersion];
    [GMSupportPlanManager setAlwaysLoadVersion:previousVersion];
    [[self supportPlanManager] resetLastDateOfAllEvents];

    NSAlert *alert = [GPGMailBundle customAlert];
    alert.messageText = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_DIALOG_ALERT_RESTARTING_TITLE"];
    alert.informativeText = [NSString stringWithFormat:[GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_ACTIVATION_DIALOG_ALERT_RESTARTING_MESSAGE"], [self productNameForVersion:previousVersion], [self productName]];
    [alert beginSheetModalForWindow:[[self view] window] completionHandler:^(NSModalResponse returnCode) {
        [[self delegate] closeSupportPlanAssistant:[[[self view] window] windowController]];
        [(MailApp *)[NSClassFromString(@"MailApp") sharedApplication] quitAndRelaunchWithAdditionalArguments:nil];
    }];
}

- (BOOL)windowShouldClose:(id)sender {
    GMSupportPlanManager *supportPlanManager = self.supportPlanManager;
    GMSupportPlanState supportPlanState = [supportPlanManager supportPlanState];
    if([[supportPlanManager supportPlan] isValid]) {
        return YES;
    }

    if(supportPlanState == GMSupportPlanStateTrialExpired || supportPlanState == GMSupportPlanStateInactive) {
        NSAlert *alert = [GPGMailBundle customAlert];
        if(supportPlanState == GMSupportPlanStateInactive) {
            alert.messageText = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_WINDOW_CLOSE_ALERT_INACTIVE_TITLE"];
            alert.informativeText = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_WINDOW_CLOSE_ALERT_INACTIVE_MESSAGE"];
        }
        else {
            alert.messageText = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_WINDOW_CLOSE_ALERT_TRIAL_EXPIRED_TITLE"];
            alert.informativeText = [GPGMailBundle localizedStringForKey:@"SUPPORT_PLAN_NEW_WINDOW_CLOSE_ALERT_TRIAL_EXPIRED_MESSAGE"];;
        }
        [alert beginSheetModalForWindow:[[self view] window] completionHandler:^(NSModalResponse returnCode) {
            [[self delegate] closeSupportPlanAssistant:[[[self view] window] windowController]];
        }];
        return NO;
    }

    return YES;
}

@end
