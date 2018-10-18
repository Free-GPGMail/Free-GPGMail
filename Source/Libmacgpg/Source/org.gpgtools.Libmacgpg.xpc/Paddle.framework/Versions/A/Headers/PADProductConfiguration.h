//
//  PADProductConfiguration.h
//  Paddle
//
//  Created by Paddle on 09/10/2017.
//  Introduced in v4.0.
//  Copyright © 2018 Paddle. All rights reserved.
//

@import Foundation;

/**
 * @brief The following constants describe the possible types of trial of a product.
 */
typedef NS_ENUM(NSInteger, PADProductTrialType) {
    /**
     * @brief Specifies that the product has no trial and that we should not track the trial start
     * date.
     */
    PADProductTrialNone,

    /**
     * @brief Specifies that the product trial should continue regardless of trial start date.
     */
    PADProductTrialUnlimited,

    /**
     * @brief Specifies that the product trial is limited to a fixed number of days.
     */
    PADProductTrialTimeLimited,
};

/**
 * @discussion PADProductConfiguration represents the configuration of
 * a product for the first launch of the app, before we are able to retrieve
 * the remote configuration of the product.
 */
@interface PADProductConfiguration : NSObject

/**
 * @brief Initialise a new product configuration object with the product and vendor name.
 */
+ (instancetype)configuration:(nonnull NSString *)productName
                   vendorName:(nonnull NSString *)vendorName;

/**
 * @discussion The name of the product. This property is typically shown to users of the application.
 */
@property (copy, nonnull) NSString *productName;

/**
 * @discussion The name of the seller. This property is typically shown to users of the application.
 */
@property (copy, nonnull) NSString *vendorName;

/**
 * @discussion Specifies whether the product has a trial. If it does, we will track the start date of the trial
 * and report the number of days remaining in the trial period.
 * @discussion The type of trial as defined on the Paddle dashboard takes predence over this setting. This allows
 * for early-access products to be released with an unlimited trial and then later changed to time-limited trial.
 * @discussion By default the trial type is NONE.
 */
@property PADProductTrialType trialType;

/**
 * @brief The maximum length of the product trial.
 * @discussion The trial length only takes effect for products with time-limited trials.
 */
@property (nonatomic, nullable) NSNumber *trialLength;

/**
 * @brief Specifies the text displayed to the user of the application, explaining the trial policy of the product.
 * @discussion The trial text only takes effect for products with a trial, either limited or unlimited.
 */
@property (copy, nullable) NSString *trialText;

/**
 * @brief The local file path of the product image. The image size must be at least 154x154 pixels.
 * @discussion When trying to display an image for the product, the local file path will be
 * loaded first. This order ensures that the user is shown a product image as soon as possible.
 * If the image URL has been retrieved from the remote configuration, then the image URL is
 * loaded next to provide an up to date version of the product image.
 */
@property (copy, nullable) NSString *imagePath;

/**
 * @discussion The base price of the product before any sales.
 */
@property (nonatomic, nullable) NSNumber *price;

/**
 * @brief The currency of the product.
 * @discussion The currency should be in the ISO 4217 format.
 */
@property (copy, nullable) NSString *currency;

@end
