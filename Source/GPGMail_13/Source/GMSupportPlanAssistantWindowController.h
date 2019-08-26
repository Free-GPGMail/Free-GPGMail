//
//  GMSupportPlanWindowController.h
//  GPGMail
//
//  Created by Lukas Pitschl on 20.09.18.
//

#import <AppKit/AppKit.h>

typedef enum : NSUInteger {
    GMSupportPlanViewControllerStateUninitialized,
    GMSupportPlanViewControllerStateBuy,
    GMSupportPlanViewControllerStateActivating,
    GMSupportPlanViewControllerStateThanks
} GMSupportPlanAssistantViewControllerState;

typedef enum : NSUInteger {
    GMSupportPlanAssistantBuyActivateButtonStateBuy,
    GMSupportPlanAssistantBuyActivateButtonStateActivate
} GMSupportPlanAssistantBuyActivateButtonState;



@protocol GMSupportPlanAssistantDelegate <NSObject>

- (void)supportPlanAssistant:(NSWindowController *)windowController email:(NSString *)email activationCode:(NSString *)activationCode;
- (void)supportPlanAssistantDidClose:(NSWindowController *)windowController;
- (void)closeSupportPlanAssistant:(NSWindowController *)windowController;
- (void)supportPlanAssistantShouldStartTrial:(NSWindowController *)windowController;
- (NSDictionary *)contractInformation;
- (NSDictionary *)supportPlanInformationForAutomaticActivationWithSupportPlanAssistant:(NSWindowController *)windowController;

@end

@interface GMSupportPlanAssistantWindowController : NSWindowController
@property (nonatomic, weak) id<GMSupportPlanAssistantDelegate> delegate;
@property (nonatomic, copy) NSDictionary *supportPlanInformation;
- (void)showActivationError;
- (void)activationDidCompleteWithSuccess;
- (void)activationDidFailWithError:(NSError *)error;
- (instancetype)initWithSupportPlanActivationInformation:(NSDictionary *)supportPlanInformation;
- (void)performAutomaticSupportPlanActivationWithActivationCode:(NSString *)activationCode email:(NSString *)email;

@end

@interface GMSupportPlanAssistantViewController : NSViewController
@property (weak) id<GMSupportPlanAssistantDelegate> delegate;
@property (nonatomic) GMSupportPlanAssistantViewControllerState state;

@property (nonatomic) NSString *email;
@property (nonatomic) NSString *activationCode;

- (void)performAutomaticSupportPlanActivationWithActivationCode:(NSString *)activationCode email:(NSString *)email;

@end

