//
//  PADLicenseMigrate.h
//  FIXME: explain purpose of file.
//
//  Created by Paddle on 01/09/2018.
//  Introduced in v4.0.
//  Copyright © 2018 Paddle. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * @discussion The following constants describe the possible product verification states.
 */
typedef NS_ENUM(NSInteger, PADExistingLicenseType) {
    /**
     * @discussion Specifies that the license is a standard user license
     */
    PADUserLicense,

    /**
     * @discussion Specifies that the license is a v3 style site license
     */
    PADSiteLicense
};

/**
 * @discussion The license migrate delegate is called when an existing v3 style license is found. Returning YES will allow the SDK to migrate this license to v4.
 */
@protocol PADLicenseMigrateDelegate <NSObject>

@optional

/**
 * @brief Should the product for ID be migrated from a v3 license to a v4 license
 *
 * @param productId An NSString containing the productId of the product license being migrated.
 * @param existingLicenseType a PADExistingLicenseType ENUM indicating the type of license trying to be migrated
 *
 * @return BOOL to indicate if the license should be migrated to v4
 */
- (BOOL)shouldMigrateExistingV3License:(nonnull NSString *)productId type:(PADExistingLicenseType)existingLicenseType;

/**
 * @brief The product for ID has been migrated from v3 to v4
 *
 * @param productId An NSString containing the productId of the product license that was migrated.
 * @param existingLicenseType a PADExistingLicenseType ENUM indicating the type of license migrated
 */
- (void)v3LicenseMigrated:(nonnull NSString *)productId type:(PADExistingLicenseType)existingLicenseType;

@end

@interface PADLicenseMigrate : NSObject

@property (weak, nullable) id<PADLicenseMigrateDelegate> delegate;

- (void)locateAndMigrateExistingV3License:(nonnull NSString *)productId;

@end
