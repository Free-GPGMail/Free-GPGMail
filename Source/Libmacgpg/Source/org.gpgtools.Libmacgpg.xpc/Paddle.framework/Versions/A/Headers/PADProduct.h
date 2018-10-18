//
//  PADProduct.h
//  Paddle
//
//  Created by Paddle on 03/10/2017.
//  Introduced in v4.0.
//  Copyright © 2018 Paddle. All rights reserved.
//

@import Foundation;
#import "PADLicenseMigrate.h"
#import "PADProductConfiguration.h"

/**
 * @discussion The following constants describe the possible product verification states.
 */
typedef NS_ENUM(NSInteger, PADVerificationState) {
    /**
     * @discussion Specifies that the license did not pass verification.
     */
    PADVerificationUnverified,

    /**
     * @discussion Specifies that the license did pass verification.
     */
    PADVerificationVerified,

    /**
     * @discussion Specifies that we were unable to get a definitive verification result, typically because of poor network.
     */
    PADVerificationUnableToVerify
};

/**
 * @discussion The following constants describe the possible types of product that the SDK supports.
 */
typedef NS_ENUM(NSInteger, PADProductType) {
    /**
     * @discussion Specifies a product that is meant to be integrated with Paddle's SDKs.
     */
    PADProductTypeSDKProduct,

    /**
     * @discussion Specifies a product that has a parent SDK product.
     */
    PADProductTypeChildProduct,

    /**
     * @discussion Specifies a subscription product that is meant to be charged on a recurring basis.
     */
    PADProductTypeSubscriptionPlan,

    /**
     * @discussion Specifies a generic product that is purchased and fulfilled once but will not issue license keys.
     */
    PADProductTypeProduct
};

/**
 * @discussion The product delegate is called when the product has been updated with remote data. As the product
 * data is sometimes refreshed through Paddle's SDK methods, the product delegate ensures that you are always aware
 * of updates to the product data.
 */
@protocol PADProductDelegate <NSObject>

@optional

/**
 * @brief The product data has been updated with remote data.
 *
 * @param productDelta A dictionary of property names (NSString) to property changes. Each property change is a
 * dictionary with 2 keys: "old" matching the value before the property was updated and "new" matching the new
 * property value. Each property name matches a property of \c PADProduct.
 */
- (void)productDidUpdateRemotely:(nonnull NSDictionary *)productDelta;

/**
 * @brief Should the product for ID be migrated from a v3 license to a v4 license
 *
 * @param productId An NSString containing the productId of the product license being migrated.
 * @param existingLicenseType a PADExistingLicenseType ENUM indicating the type of license trying to be migrated
 *
 * @return BOOL to indicate if the license should be migrated to v4
 */
- (BOOL)shouldMigrateExistingV3License:(NSString *)productId type:(PADExistingLicenseType)existingLicenseType;

/**
 * @brief The product for ID has been migrated from v3 to v4
 *
 * @param productId An NSString containing the productId of the product license that was migrated.
 * @param existingLicenseType a PADExistingLicenseType ENUM indicating the type of license migrated
 */
- (void)v3LicenseMigrated:(NSString *)productId type:(PADExistingLicenseType)existingLicenseType;

@end

/**
 * @discussion A representation of a Paddle product or subscription including purchase, trial, and license information where applicable.
 *
 * @discussion PADProducts are passed to the checkout for purchasing and also contain methods for access control (i.e activation).
 *
 * @discussion PADProduct objects are not a live representation of a products current state and so if retained may not be accurate. It is suggested to request a new PADProduct object when needed and then discard.
 */

@interface PADProduct : NSObject <PADLicenseMigrateDelegate>

/**
 * @brief The delegate to be called when the product data is updated.
 * @see PADProductDelegate
 */
@property (weak, nullable) id<PADProductDelegate> delegate;

/**
 * @discussion The identifier of the product as set by the Paddle dashboard when the product was created.
 */
@property (copy, readonly, nonnull) NSString *productID;

/**
 * @discussion Specifies whether the product has been activated with a valid license.
 */
@property (readonly) BOOL activated;

/**
 * @discussion The name of the product as set in the Paddle dashboard or as specified by the product configuration.
 * This property is typically shown to users of the application.
 */
@property (copy, nullable, readonly) NSString *productName;

/**
 * @discussion The name of the seller as set in the Paddle dashboard or as specified by the product configuration.
 * This property is typically shown to users of the application.
 */
@property (copy, nullable, readonly) NSString *vendorName;

/**
 * @discussion Specifies the type of trial of the product. See PADProductTrialType for all possible types of trial.
 * @discussion The type of trial will be overwritten by the type of trial as set in the Paddle dashboard. This allows
 * for early-access products to be released with an unlimited trial and then later changed to time-limited trial.
 * @discussion By default the type of trial will be NONE.
 */
@property (readonly) PADProductTrialType trialType;

/**
 * @discussion Specifies the text displayed to the user of the application, explaining the trial policy of the product.
 * This property is typically set by either the product configuration or set in the Paddle dashboard.
 * @discussion The trial text only takes effect for products with a trial, either limited or unlimited.
 */
@property (copy, nullable, nonatomic) NSString *trialText;

/**
 * @discussion The date on which the user's trial began. This may be reset by calling resetTrial.
 * @discussion The trial start date is only recorded for products with a trial, either limited or unlimited.
 */
@property (nonatomic, readonly, nullable) NSDate *trialStartDate;

/**
 * @discussion The number of days remaining in the trial period. This number may be negative to indicate the number
 * of days past the trial period, e.g. -2 indicates that the trial passed 2 days ago.
 * @discussion The number of days remaining in the trial will be nil for products without a trial and products with
 * an unlimited trial.
 */
@property (nonatomic, readonly, nullable) NSNumber *trialDaysRemaining;

/**
 * @discussion The maximum length of the product trial as set in the Paddle dashboard or as specified by the product configuration.
 * @discussion The trial length only takes effect for products with time-limited trials.
 */
@property (nonatomic, readonly, nullable) NSNumber *trialLength;

/**
 * @discussion The license that was used to activate the product.
 */
@property (copy, readonly, nullable) NSString *licenseCode;

/**
 * @discussion The date on which the used license will expire, if it does at all.
 */
@property (nonatomic, readonly, nullable) NSDate *licenseExpiryDate;

/**
 * @discussion The email used to activate the product.
 */
@property (copy, readonly, nullable) NSString *activationEmail;

/**
 * @discussion The identifier of the product activation. The identifier is used during the deactivation process.
 */
@property (copy, readonly, nullable) NSString *activationID;

/**
 * @brief The last time we successfully refreshed the product data.
 */
@property (nonatomic, readonly, nullable) NSDate *lastRefreshDate;

/**
 * @discussion The date on which the product was activated.
 */
@property (nonatomic, readonly, nullable) NSDate *activationDate;

/**
 * @brief The last time we were asked to verify the product activation.
 * @discussion This property can be used to determine whether enough time has passed to
 * verify the product activation again.
 */
@property (nonatomic, readonly, nullable) NSDate *lastVerifyDate;

/**
 * @brief The last time we successfully verified the product activation.
 * @discussion This property is updated only if the the product activation has been verified
 * remotely. If the activation is unverified or unverifiable, this propery is not be updated.
 */
@property (nonatomic, readonly, nullable) NSDate *lastSuccessfulVerifiedDate;

/**
 * @discussion The price of the product without any sale adjustment, in the most appropriate currency.
 *
 * The base price may be nil if the product has not been released yet.
 */
@property (nonatomic, readonly, nullable) NSNumber *basePrice;

/**
 * @discussion The price of the product in the most appropriate currency including sale adjustment, if any.
 *
 * The current price may be nil if the product has not been released yet.
 */
@property (nonatomic, readonly, nullable) NSNumber *currentPrice;

/**
 * @discussion The percentage of the base price that has been discounted, if any.
 *
 * The discount percentage may be nil if the product has not been released yet.
 */
@property (nonatomic, readonly, nullable) NSNumber *discountPercent;

/**
 * @discussion The total discount of the product, in the most appropriate currency.
 *
 * The discount amount may be nil if the product has not been released yet.
 */
@property (copy, readonly, nonnull) NSString *discount;

/**
 * @brief The currency of the product.
 * @discussion The currency is in the ISO 4217 format. It is the most appropriate currency of the product,
 * as specified in the product configuration or as determined by the locale of the user.
 */
@property (copy, readonly, nullable) NSString *currency;

/**
 * @discussion Specifies whether the product is currently on sale.
 */
@property (readonly) BOOL onSale;

/**
 * @brief The local file path of the product image. The image size must be at least 154x154 pixels.
 * @discussion When trying to display an image for the product, the local file path will be
 * loaded first. This order ensures that the user is shown a product image as soon as possible.
 * The image URL is then loaded to provide an up to date version of the product image.
 */
@property (copy, nullable, nonatomic) NSString *imagePath;

/**
 * @brief The remote URL of the product image.
 * @discussion When trying to display an image for the product, the local file path will be
 * loaded first. This order ensures that the user is shown a product image as soon as possible.
 * The image URL is then loaded to provide an up to date version of the product image.
 */
@property (copy, nullable, readonly) NSString *imageUrl;

/**
 * @discussion The type of the product as specified either in the product configuration or
 * in the Paddle dashboard.
 */
@property (nonatomic, readonly) PADProductType productType;

/**
 * @discussion Set to YES to allow users to pick to continue using this product in the product info UI after their time trial has expired
 */
@property (nonatomic) BOOL willContinueAtTrialEnd;

/**
 * @discussion If set to YES, when a trial has expired, using the product info Quit button will use exit(0); to force exit of your app
 */
@property (nonatomic) BOOL canForceExit;

/**
 * @discussion Initializes a PADProduct ready to be used in the SDK
 *
 * @param productID An NSString containing the productID you wish to prepare
 * @param productType A PADProductType value
 * @param configuration An optional PADProductConfiguration object containing default, or customized, values for the product
 *
 * @return PADProduct a PADProduct object initialized for your request productID
 */
- (nullable instancetype)initWithProductID:(nonnull NSString *)productID
                               productType:(PADProductType)productType
                             configuration:(nullable PADProductConfiguration *)configuration;

/**
 * @discussion Get a PADProduct object for an already initialized productID
 *
 * @param productID an NSString containing the productID you wish to get
 *
 * @return PADProduct a PADProduct object for your productID
 */
+ (nullable instancetype)initializedProductForID:(nullable NSString *)productID;

/**
 * @discussion Verify the activation for the current product
 * @discussion If no completion handler is given, then the error is passed to the delegate, if the delegate
 * is set and it responds to `paddleDidError:`.
 *
 * @param completion The completion handler to call when the verification has been completed.
 * This handler is executed on the main dispatch queue, but it may not be executed asynchronously.
 * The completion handler is given the verification state of the product and, if unable to verify, an error.
 */
- (void)verifyActivationWithCompletion:(nullable void (^)(PADVerificationState state, NSError *_Nullable error))completion;

/**
 * @discussion Destroy the activation for the current product locally. This will not deactivate an activation
 */
- (void)destroyActivation;

/**
 * @discussion Deactivate the activation for the current product
 * @discussion If no completion handler is given, then the error is passed to the delegate, if the delegate
 * is set and it responds to `paddleDidError:`.
 *
 * @param completion The completion handler to call when the deactivation has been completed.
 * This handler is executed on the main dispatch queue, but it may not be executed asynchronously.
 * The completion handler is given a BOOL to indicate if the deactivation was successful, and an error
 * if the deactivation was not successful.
 */
- (void)deactivateWithCompletion:(nullable void (^)(BOOL deactivated, NSError *_Nullable error))completion;

/**
 * @discussion Activate the current product
 * @discussion If no completion handler is given, then the error is passed to the delegate, if the delegate
 * is set and it responds to `paddleDidError:`.
 *
 * @param email An NSString containing the email address of the user for the activation
 * @param license an NSString containing the license code to be used for the activation
 * @param completion The completion handler to call when the product has been activated.
 * This handler is executed on the main dispatch queue, but it may not be executed asynchronously.
 * The completion handler is given a BOOL to indicate if the activation was successful and
 * an error if it was not successful.
 */
- (void)activateEmail:(NSString *)email
              license:(NSString *)license
           completion:(nullable void (^)(BOOL activated, NSError *_Nullable error))completion;

/**
 * @discussion Reset the trial for this product
 */
- (void)resetTrial;

/**
 * @discussion Expire the trial for this product
 */
- (void)expireTrial;

/**
 * @brief Refresh the locally stored data for the product from the vendor dashboard
 * @discussion If no completion handler is given, then the error is passed to the delegate, if the delegate
 * is set and it responds to \c paddleDidError:.
 * @discussion If the product is updated with the remote product data, the product delegate is called with the
 * changes to the product.
 *
 * @param completion The completion handler to call when the product data has been refreshed.
 * This handler is executed on the main dispatch queue, but it may not be executed asynchronously.
 * The handler is given the changes applied to the product
 * and an error if the refresh action failed. The product changes are represented as a dictionary of property names (\c NSString)
 * to property changes. Each property change is a dictionary with 2 keys: "old" matching the value before the
 * property was updated and "new" matching the new property value. Each property name matches a property of \c PADProduct.
 */
- (void)refresh:(nullable void (^)(NSDictionary *_Nullable productDelta, NSError *_Nullable error))completion;

/**
 * @discussion Is this product capable of being activated
 *
 * @return BOOL indicating if the product can be activated
 */
- (BOOL)canActivate;

/**
 * @discussion Is this product capable of being shown in a product access dialog
 *
 * @return BOOL indicating if the product can be shown in a product access dialog
 */
- (BOOL)canShowProductAccess;


@end
