//
//  GPGVerifyingKeyserver.h
//  Libmacgpg
//
//  Created by Mento on 24.06.19.
//

#import <Libmacgpg/GPGRemotekey.h>

// Callbacks for the different methods. If error is set, all other arguments are nil.
typedef void (^GPGVKSUploadCallback)(NSArray *fingerprints, NSDictionary<NSString *, NSString *> *status, NSString *token, NSError *error);
typedef void (^GPGVKSSearchCallback)(NSArray<GPGRemoteKey *> *foundKeys, NSError *error);
typedef void (^GPGVKSDownloadCallback)(NSData *keyData, NSError *error);


// Possible states of an userIDs on the server.
extern NSString * const GPGVKSStateUnpublished;
extern NSString * const GPGVKSStatePending;
extern NSString * const GPGVKSStatePublished;
extern NSString * const GPGVKSStateRevoked;


@interface GPGVerifyingKeyserver : NSObject
@property (strong, nonatomic) NSString *keyserver; // Default keyserver is @"https://keys.openpgp.org".
@property (nonatomic) NSUInteger timeout; // Default timeout is 20 seconds.


/**
 * Upload a key to the keyserver.
 *
 * @param armored contains a single ASCII-armored key. (If more the one key is passed, the email verification will not work)
 * @param callback is called when the upload has finished or failed
 */

- (void)uploadKey:(NSString *)armored callback:(GPGVKSUploadCallback)callback;


/**
 * Request the server to verify some email-addresses.
 *
 * @param emailAddresses is a list of email-addresses to verify
 * @param token is the token returned by the callback from -uploadKey:callback:
 * @param callback is called when the request has finished or failed
 */
- (void)requestVerification:(NSArray *)emailAddresses token:(NSString *)token callback:(GPGVKSUploadCallback)callback;


/**
 * Searches for one or more keys on the server.
 *
 * @param searchTerms is a list of e-mail-addresses, fingerprints or keyIDs.
 * @param callback is called when the search has finished or failed
 */
- (void)searchKeys:(NSArray *)searchTerms callback:(GPGVKSSearchCallback)callback;


/**
 * Downloads for one or more keys from the server.
 *
 * @param identifiers is a list of e-mail-addresses, fingerprints or keyIDs.
 * @param callback is called when the search has finished or failed
 */
- (void)downloadKeys:(NSArray *)identifiers callback:(GPGVKSDownloadCallback)callback;


@end

