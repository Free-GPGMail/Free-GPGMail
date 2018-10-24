//
//  GMSupportPlanWindowController.m
//  GPGMail
//
//  Created by Lukas Pitschl on 20.09.18.
//

#import <Foundation/Foundation.h>
#import "GMSupportPlanAssistantWindowController.h"
#import "DSClickableURLTextField.h"
#import "NSAttributedString+LOKit.h"

#import "GPGMailBundle.h"

typedef enum {
    GMSupportPlanPaddleErrorCodeNetworkError = 99,
    GMSupportPlanPaddleErrorCodeActivationCodeNotFound = 100,
    GMSupportPlanPaddleErrorCodeActivationCodeAlreadyUsed = 104
} GMSupportPlanPaddleErrorCodes;

@interface GMSupportPlanAssistantViewController ()

@property (nonatomic, weak) IBOutlet NSTextField *headerTextField;
@property (nonatomic, weak) IBOutlet NSTextField *subHeaderTextField;
@property (nonatomic, weak) IBOutlet DSClickableURLTextField *detailsTextField;

@property (nonatomic, weak) IBOutlet NSTextField *emailLabel;
@property (nonatomic, weak) IBOutlet NSTextField *licenseLabel;
@property (nonatomic, weak) IBOutlet NSTextField *emailTextField;
@property (nonatomic, weak) IBOutlet NSTextField *licenseTextField;

@property (nonatomic, weak) IBOutlet NSStackView *progressStackView;
@property (nonatomic, weak) IBOutlet NSProgressIndicator *progressIndicator;
@property (nonatomic, weak) IBOutlet NSTextField *progressTextField;

@property (nonatomic, weak) IBOutlet NSButton *continueButton;
@property (nonatomic, weak) IBOutlet NSButton *cancelButton;

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

- (void)windowWillClose:(NSNotification *)notification
{
    if ([[self delegate] respondsToSelector:@selector(supportPlanAssistantDidClose:)])
    {
        [[self delegate] supportPlanAssistantDidClose:self];
    }
}

- (void)showActivationError {
    NSAlert *alert = [NSAlert new];
    alert.informativeText = @"The entered activation code is invalid. Please check the entered information and try again.";
    alert.messageText = @"Support Plan Activation Failed";
    alert.icon = [NSImage imageNamed:@"GPGMail"];
    [alert beginSheetModalForWindow:[self window] completionHandler:^(NSModalResponse returnCode) {
        
    }];
}

- (void)activationDidCompleteWithSuccess {
    [(GMSupportPlanAssistantViewController *)[[self window] contentViewController] setState:GMSupportPlanViewControllerStateBuy];
    NSAlert *alert = [NSAlert new];
    alert.messageText = @"Support Plan Activation";
    alert.informativeText = @"Thank you for your support!\n\nWe hope you enjoy using GPG Mail. Should you have any questions, don't hesitate to contact us via \"Report Problem\" in Mail -> Preferences -> GPGMail";
    alert.icon = [NSImage imageNamed:@"GPGMail"];
    [alert beginSheetModalForWindow:[self window] completionHandler:^(NSModalResponse returnCode) {
        [[self delegate] closeSupportPlanAssistant:self];
    }];
}

- (void)activationDidFailWithError:(NSError *)error {
    [(GMSupportPlanAssistantViewController *)[[self window] contentViewController] setState:GMSupportPlanViewControllerStateBuy];
    NSAlert *alert = [NSAlert new];
    
    if(error.code == GMSupportPlanPaddleErrorCodeNetworkError) {
        alert.informativeText = @"We were unable to connect to the paddle.com API to verify your activation code.\nIf you are using any macOS firewall product (buil-in firewall, Little Snitch, etc.), please allow connections to paddle.com for the activation to complete. You can block any connections again once the activation is completed.\n\nPlease contact us at business@gpgtools.org if the problem persists.";
    }
    else if(error.code == GMSupportPlanPaddleErrorCodeActivationCodeNotFound) {
        alert.informativeText = @"The entered activation code is invalid.\nPlease contact us at business@gpgtools.org if you are sure that you have entered your code correctly.";
    }
    else if(error.code == GMSupportPlanPaddleErrorCodeActivationCodeAlreadyUsed) {
        alert.informativeText = @"We are very sorry to inform you that you have exceeded the allowed number of activations.\nPlease contact us at business@gpgtools.org, if you believe that you should still have activations left.";
    }
    else {
        alert.informativeText = @"Unfortunately an unknown error has occured. Please retry later or use 'System Preferences › GPG Suite › Report Problem' to contact us";
    }
    
    alert.messageText = @"Support Plan Activation Failed";
    alert.icon = [NSImage imageNamed:@"GPGMail"];
    [alert beginSheetModalForWindow:[self window] completionHandler:^(NSModalResponse returnCode) {
        
    }];
}

- (instancetype)initWithSupportPlanActivationInformation:(NSDictionary *)supportPlanInformation {
    self = [super init];
    if(self) {
        _supportPlanInformation = supportPlanInformation;
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

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setState:GMSupportPlanViewControllerStateBuy];
    
    NSDictionary *supportPlanInformation = [[self delegate] contractInformation];
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                [NSColor linkColor], NSForegroundColorAttributeName,
                                [NSURL URLWithString:@"https://gpgtools.org/buy-support-plan"], NSLinkAttributeName,
                                nil];
    
    NSNumber *remainingTrialDays = [supportPlanInformation valueForKey:@"ActivationRemainingTrialDays"];
    BOOL trialStarted = YES;
    if(!remainingTrialDays) {
        remainingTrialDays = @(30);
        trialStarted = NO;
    }
    
    if(trialStarted && [remainingTrialDays integerValue] <= 0) {
        self.subHeaderTextField.stringValue = [NSString stringWithFormat:@"Your free trial of GPG Mail has expired.\nPlease purchase our support plan to continue."];
    }
    else {
        self.subHeaderTextField.stringValue = [NSString stringWithFormat:@"You can test GPG Mail free for %@ %@days.\nSecure your emails now!", remainingTrialDays, trialStarted && [remainingTrialDays integerValue] != 30 ? @"more " : @""];
    }
    self.detailsTextField.attributedStringValue = ({
        [NSAttributedString lo_attributedStringWithBaseAttributes:nil
                                               argumentAttributes:attributes
                                                     formatString:
         NSLocalizedString(@"If you have already purchased a support plan, activate it now and enjoy GPG Mail!", @""),
         NSLocalizedString(@"support plan", @""),
         nil];
    });
    self.continueButton.title = @"Buy Now";
    self.continueButton.tag = GMSupportPlanAssistantBuyActivateButtonStateBuy;
    
    if(remainingTrialDays <= 0) {
        self.cancelButton.title = @"Close";
    }
    else {
        self.cancelButton.title = trialStarted ? @"Continue Trial" : @"Start Trial";
    }
}

- (void)setState:(GMSupportPlanAssistantViewControllerState)state {
    if (_state != state) {
        _state = state;
        
        _emailTextField.enabled = (state == GMSupportPlanViewControllerStateBuy);
        _licenseTextField.enabled = (state == GMSupportPlanViewControllerStateBuy);
        _emailTextField.editable = (state == GMSupportPlanViewControllerStateBuy);
        _licenseTextField.editable = (state == GMSupportPlanViewControllerStateBuy);
        _progressStackView.hidden = (state != GMSupportPlanViewControllerStateActivating);
        if (state == GMSupportPlanViewControllerStateActivating) {
            [_progressIndicator startAnimation:nil];
        } else {
            [_progressIndicator stopAnimation:nil];
        }
        _continueButton.enabled = (state == GMSupportPlanViewControllerStateBuy);
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
    GMSupportPlanAssistantBuyActivateButtonState wantsState = [self.activationCode length] || [self.email length] ? GMSupportPlanAssistantBuyActivateButtonStateActivate : GMSupportPlanAssistantBuyActivateButtonStateBuy;
    if(_continueButton.tag == wantsState) {
        return;
    }
    if(wantsState == GMSupportPlanAssistantBuyActivateButtonStateBuy) {
        _continueButton.title = @"Buy Now";
        _continueButton.tag = GMSupportPlanAssistantBuyActivateButtonStateBuy;
    }
    else {
        _continueButton.title = @"Activate";
        _continueButton.tag = GMSupportPlanAssistantBuyActivateButtonStateActivate;
    }
}

- (IBAction)activate:(id)sender {
    if([(NSButton *)sender tag] == GMSupportPlanAssistantBuyActivateButtonStateBuy) {
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://gpgtools.org/buy-support-plan"]];
    }
    else {
        if(self.email && self.emailTextField.stringValue != self.email) {
            self.emailTextField.stringValue = self.email;
        }
        if(self.activationCode && self.licenseTextField.stringValue != self.activationCode) {
            self.licenseTextField.stringValue = self.activationCode;
        }
        
        if(![self validateActivationInformation]) {
            [(GMSupportPlanAssistantWindowController *)[[[self view] window] windowController] showActivationError];
        }
        else {
            [self setState:GMSupportPlanViewControllerStateActivating];
            [[self delegate] supportPlanAssistant:[[[self view] window] windowController]
                                            email:self.email
                                   activationCode:self.activationCode];
        }
    }
}

- (BOOL)validateActivationInformation {
    if([self.activationCode length] <= 30 || [self.activationCode length] >= 44 + 10 || ![self.email length] || [self.email rangeOfString:@"@"].location == NSNotFound) {
        return NO;
    }
    return YES;
}

- (IBAction)cancel:(id)sender {
    NSDictionary *supportPlanInformation = [[self delegate] contractInformation];
    NSNumber *remainingTrialDays = [supportPlanInformation valueForKey:@"ActivationRemainingTrialDays"];
    // Take into consideration that no information about remaining trial days is available, the trial
    // hasn't been started yet.
    if(remainingTrialDays && [remainingTrialDays integerValue] <= 0) {
        NSAlert *alert = [NSAlert new];
        alert.messageText = @"GPG Mail Trial Expired";
        alert.informativeText = @"Without an active GPG Mail Support Plan you will still be able to read any of your encrypted emails. However, you will no longer be able to sign, encrypt or verify emails.";
        alert.icon = [NSImage imageNamed:@"GPGMail"];
        [alert beginSheetModalForWindow:[[self view] window] completionHandler:^(NSModalResponse returnCode) {
            [[self delegate] closeSupportPlanAssistant:[[[self view] window] windowController]];
        }];
    }
    else {
        [[self delegate] supportPlanAssistantShouldStartTrial:[[[self view] window] windowController]];
        [[self delegate] closeSupportPlanAssistant:[[[self view] window] windowController]];
    }
}

@end
