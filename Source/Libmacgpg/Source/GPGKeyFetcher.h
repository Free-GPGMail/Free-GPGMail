
@interface GPGKeyFetcher : NSObject <NSURLConnectionDelegate, NSURLConnectionDataDelegate> {
	NSCache *cache;
	NSURLSession *session;
}


/*
 * Returns the de-armored key-data for the specified mail address from a keyserver.
 *
 */
- (void)fetchKeyForMailAddress:(NSString *)mailAddress block:(void (^)(NSData *data, NSString *verifiedMail, NSError *error))block;

@end
