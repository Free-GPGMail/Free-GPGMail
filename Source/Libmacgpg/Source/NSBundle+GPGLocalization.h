//
//  GPGLocalizationBundle.h
//  Libmacgpg
//
//  Created by Mento on 02.02.2017
//
//

#import <Foundation/Foundation.h>


@interface NSBundle (GPGLocalization)

/**
 * By default a sub-bundle only uses those localizations which are also in the main bundle.
 * Call this method on a sub-bundle to allow more localizations.
 */
- (void)useGPGLocalizations;
@end

