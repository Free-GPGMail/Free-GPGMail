//
//  GPGLocalizationBundle.m
//  Libmacgpg
//
//  Created by Mento on 02.02.2017
//
//

#import "NSBundle+GPGLocalization.h"
#import <objc/runtime.h>

@interface GPGLocalizationBundle : NSBundle
@end
@implementation GPGLocalizationBundle

/*
 * By default GPGMail is not able to use any localization nor present in Mail.app.
 * This method uses the ser preferred localization available in GPGMail, ignoring the default behavior.
 */
- (NSString *)localizedStringForKey:(NSString *)key value:(NSString *)value table:(NSString *)tableName {
	static dispatch_once_t onceToken;
	static NSBundle *localizationBundle = nil;
	dispatch_once(&onceToken, ^{
		NSArray *preferredLocalizations = [NSBundle preferredLocalizationsFromArray:[self localizations] forPreferences:nil];
		NSArray *usedLocalizations = [self preferredLocalizations];
		
		if (preferredLocalizations.count > 0 && usedLocalizations.count > 0 && ![preferredLocalizations[0] isEqualToString:usedLocalizations[0]]) {
			localizationBundle = [NSBundle bundleWithPath:[self pathForResource:preferredLocalizations[0] ofType:@"lproj"]];
		}
	});

	NSString *localizedString;
	if (localizationBundle) {
		localizedString = [localizationBundle localizedStringForKey:key value:value table:tableName];
	} else {
		localizedString = [super localizedStringForKey:key value:value table:tableName];
	}
	
	return localizedString;
}

@end

@implementation NSBundle (GPGLocalization)

- (void)useGPGLocalizations {
	object_setClass(self, [GPGLocalizationBundle class]);
}

@end
