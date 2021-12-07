//
//  GMSupportPlan.m
//  GPGMail
//
//  Created by Lukas Pitschl on 23.10.19.
//

#include <CommonCrypto/CommonDigest.h>

#import "GMSupportPlanManager.h"
#import "GMSupportPlan.h"
#import "GMDevice.h"

typedef enum {
    GMSupportPlanSignatureStatusUnknown,
    GMSupportPlanSignatureStatusValid,
    GMSupportPlanSignatureStatusInvalid
} GMSupportPlanSignatureStatus;

@interface GMSupportPlan ()

@property (nonatomic, copy, readonly) NSData *publicCertificate;
@property (nonatomic, copy) NSDictionary *applicationInfo;
@property (nonatomic, retain) GMDevice *currentDevice;
@property (atomic, assign) GMSupportPlanSignatureStatus signatureStatus;

@end

NSString * const GMSupportPlanTypeValueTrial = @"trial";
NSString * const GMSupportPlanTypeValueFallbackTrial = @"fallbacktrial";
NSString * const GMSupportPlanTypeValueStatic = @"static";
NSString * const GMSupportPlanTypeValueTime = @"time";

NSString * const GMSupportPlanRefreshTypeRegular = @"regular";
NSString * const GMSupportPlanRefreshTypeOffline = @"offline";

NSString * const GMSupportPlanVersionPrefix = @"org.free-gpgmail.gpgmail";

@implementation GMSupportPlan

- (instancetype)initWithDictionary:(NSDictionary *)dictionary applicationID:(NSString *)applicationID applicationInfo:(NSDictionary *)applicationInfo publicCertificate:(NSString *)certificate {
    if((self = [super init])) {
        _activation = [[dictionary valueForKey:@"activation"] copy];
        _metadata = [[dictionary valueForKey:@"meta"] copy];
        // Certificate use # in case of // since otherwise macro expansion doesn't work properly.
        certificate = [certificate stringByReplacingOccurrencesOfString:@"#" withString:@"//"];
        _publicCertificate = [[NSData alloc] initWithBase64EncodedString:certificate options:NSDataBase64DecodingIgnoreUnknownCharacters];
        _applicationID = [applicationID copy];
        _applicationInfo = [applicationInfo copy];
        _signatureStatus = 0;
        _currentDevice = [GMDevice currentDeviceWithApplicationInfo:applicationInfo];
        _eligibleVersions = @[ @"99.99" ];
        _newestEligibleVersion = @"99.99";


        _offline = [_activation[@"offline"] boolValue];
    }

    return self;
}

- (BOOL)saveToURL:(NSURL *)url error:(NSError __autoreleasing **)error {
    NSData *data = [self asData];
    return [data writeToFile:[url path] options:NSDataWritingAtomic error:error];
}

- (NSData *)asData {
    NSMutableDictionary *json = [NSMutableDictionary dictionary];
    json[@"activation"] = _activation;
    json[@"meta"] = _metadata;

    NSData *data = [NSJSONSerialization dataWithJSONObject:json options:0 error:nil];
    return data;
}

- (nullable NSDateInterval *)validityInterval {
    // 2020-01-01
    NSInteger issued = 1577833200;
    NSDate *issuedDate = [NSDate dateWithTimeIntervalSince1970:issued];

    return [[NSDateInterval alloc] initWithStartDate:issuedDate endDate:[self expirationDate]];
}

- (NSDate *)expirationDate {
    // 2099-01-01
    return [NSDate dateWithTimeIntervalSince1970: 4070905200];
}

- (NSTimeInterval)remainingTimeInterval {
    return 999999999;
}

- (BOOL)isValid {
    return YES;
}

- (BOOL)isValidExcludingAppName {
    return YES;
}

- (BOOL)isValidForAppName:(NSString *)appName {
    return YES;
}

- (void)validateSignature {
    self.signatureStatus = GMSupportPlanSignatureStatusValid;
    return;
}

- (BOOL)isSignatureValid {
    return YES;
}

- (BOOL)isAppNameValid {
    return YES;
}

- (BOOL)isEligibleForAppWithName:(NSString *)appName {
    return YES;
}

- (BOOL)isDeviceValid {
    return YES;
}

- (NSString *)deviceID {
    return self.activation[@"udid"];
}

- (NSArray *)eligibleVersions {
    return _eligibleVersions;
}

- (NSString *)newestEligibleVersion {
    return _newestEligibleVersion;
}

- (BOOL)isExpired {
    return NO;
}

- (NSString *)appName {
    return self.activation[@"app"];
}

- (GMSupportPlanType)type {
    return GMSupportPlanTypeStatic;
}

- (BOOL)isKindOfTrial {
    return NO;
}

- (BOOL)isAboutToExpire {
    return NO;
}

- (NSDate *)lastUpdate {
    return nil;
}

- (NSDate *)refreshUntil {
    return nil;
}

- (NSString *)refreshType {
    return GMSupportPlanRefreshTypeOffline;
}

- (NSString *)activationCode {
    return self.activation[@"activation_code"];
}

- (NSString *)email {
    return self.activation[@"email"];
}

- (BOOL)isMultiUser {
    return NO;
}

- (NSString *)description {
    NSMutableString *summary = [NSMutableString new];
    NSMutableArray *eligibleVersions = [NSMutableArray new];
    for(NSString *eligibleVersion in [self.activation[@"eligible_apps"] allValues]) {
        NSString *version = [eligibleVersion stringByReplacingOccurrencesOfString:@"org.free-gpgmail.gpgmail" withString:@""];
        if(![version length]) {
            version = @"3";
        }
        [eligibleVersions addObject:version];
    }

    [summary appendFormat:@"<%@ %p> {\n\teligible-versions: %@,\n\ttype: %@,\n\temail: %@,\n\tcode: %@,\n\tvalid until: %@,\n\tudid: %@\n}", NSStringFromClass([self class]), self, [[self eligibleVersions] componentsJoinedByString:@","], [self descriptionForType:[self type]], [self email], [self activationCode], [self expirationDate] ? [self expirationDate] : @"no expiration", [self deviceID]];
    return summary;
}

- (NSString *)descriptionForType:(GMSupportPlanType)type {
    if(type == GMSupportPlanTypeTime) {
        return @"time-limited";
    }
    if(type == GMSupportPlanTypeTrial) {
        return @"trial";
    }
    if(type == GMSupportPlanTypeFallbackTrial) {
        return @"offline-trial";
    }
    if(type == GMSupportPlanTypeStatic) {
        return @"static";
    }

    return @"none";
}

@end
