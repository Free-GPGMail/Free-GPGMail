//
//  GMSupportPlanManager.h
//  GPGMail
//
//  Created by Lukas Pitschl on 23.10.19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class GMSupportPlan;

typedef void (^gmsp_api_handler_t)(GMSupportPlan * __nullable supportPlan, NSDictionary * __nullable result, NSError * __nullable error);

typedef enum {
    GMSupportPlanManagerUpgradeStateVersionUnknown,
    GMSupportPlanManagerUpgradeStateVersionSupported,
    GMSupportPlanManagerUpgradeStateUpgradeFromVersion3ToVersion4,
    GMSupportPlanManagerUpgradeStateUpgradeOrKeepVersion3
} GMSupportPlanManagerUpgradeState;

typedef enum {
    GMSupportPlanStateInactive = 0,
    GMSupportPlanStateTrial = 2090,
    GMSupportPlanStateTrialExpired = 3020,
    GMSupportPlanStateActive = 4000,
    GMSupportPlanStateTimedExpired = 4040
} GMSupportPlanState;

typedef enum {
    GMSupportPlanAPIErrorServerError = 10,
    GMSupportPlanAPIErrorNetworkError = 99,
    GMSupportPlanAPIErrorActivationCodeNotFound = 100,
    GMSupportPlanAPIErrorActivationCodeAlreadyUsed = 104,
    GMSupportPlanAPIErrorUpgradeURLVolume = 165
} GMSupportPlanAPIError;

@interface GMSupportPlanManager : NSObject {
    NSURL *_endpointURL;
    NSURL *_activationURL;
    NSString *_applicationID;
    NSString *_applicationVersion;
    NSDictionary *_applicationInfo;
}

- (instancetype)initWithApplicationID:(NSString *)applicationID applicationInfo:(NSDictionary *)applicationInfo;
- (instancetype)initWithApplicationID:(NSString *)applicationID applicationInfo:(NSDictionary *)applicationInfo fromSharedAccess:(BOOL)fromSharedAccess;
- (BOOL)supportPlanIsActive;
- (NSNumber *)remainingTrialDays;
- (NSString *)currentEmail;
- (NSString *)currentActivationCode;

- (NSString *)applicationVersion;
- (BOOL)version:(NSString *)version1 isNewerThanVersion:(NSString *)version2;

- (void)startTrialWithCompletionHandler:(gmsp_api_handler_t __nullable)completionHandler;
- (void)activateSupportPlanWithActivationCode:(NSString *)activationCode email:(NSString *)email completionHandler:(gmsp_api_handler_t)completionHandler;
- (void)deactivateWithCompletionHandler:(gmsp_api_handler_t)completionHandler;
- (void)deactivateWithCompletionHandler:(gmsp_api_handler_t)completionHandler ignoreServerResponse:(BOOL)ignoreServerResponse;
- (void)fetchUpgradeURLWithCompletionHandler:(gmsp_api_handler_t)completionHandler;
- (void)migratePaddleActivationWithCompletionHandler:(gmsp_api_handler_t)completionHandler;

- (BOOL)shouldPromptUserForUpgrade;
- (GMSupportPlanManagerUpgradeState)upgradeState;
- (GMSupportPlan *)supportPlanForPreviousVersion;

- (NSDictionary *)legacySupportPlanInformation;

- (BOOL)isEligibleForApp:(NSString *)app;


- (BOOL)shouldPresentActivationDialog;
- (GMSupportPlanState)supportPlanState;

+ (NSString *)shouldNeverAskAgainForUpgradeVersion;
+ (void)setShouldNeverAskAgainForUpgradeVersion:(NSString * __nullable)version;;

+ (NSString *)alwaysLoadVersion;
+ (void)setAlwaysLoadVersion:(NSString * __nullable)version;
+ (NSString *)alwaysLoadVersionSharedAccess;
+ (void)setAlwaysLoadVersionForSharedAccess:(NSString *)version;

- (void)resetLastDateOfAllEvents;

- (BOOL)isMultiUser;
- (BOOL)installFallbackTrial;

- (NSString *)applicationVersion;
- (BOOL)version:(NSString *)version isNewerThanVersion:(NSString *)toVersion;

+ (NSString *)bundlesInstallationPath;
+ (NSString *)bundlesContainerPath;

#ifdef DEBUG
+ (NSDate *)currentDate;
#endif

@property (nonatomic, retain) GMSupportPlan *supportPlan;
@property (nonatomic, retain) NSArray <GMSupportPlan *> *validSupportPlans;



@end

NS_ASSUME_NONNULL_END
