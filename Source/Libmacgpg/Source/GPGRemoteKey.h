/*
 Copyright © Roman Zechmeister, 2017
 
 Diese Datei ist Teil von Libmacgpg.
 
 Libmacgpg ist freie Software. Sie können es unter den Bedingungen 
 der GNU General Public License, wie von der Free Software Foundation 
 veröffentlicht, weitergeben und/oder modifizieren, entweder gemäß 
 Version 3 der Lizenz oder (nach Ihrer Option) jeder späteren Version.
 
 Die Veröffentlichung von Libmacgpg erfolgt in der Hoffnung, daß es Ihnen 
 von Nutzen sein wird, aber ohne irgendeine Garantie, sogar ohne die implizite 
 Garantie der Marktreife oder der Verwendbarkeit für einen bestimmten Zweck. 
 Details finden Sie in der GNU General Public License.
 
 Sie sollten ein Exemplar der GNU General Public License zusammen mit diesem 
 Programm erhalten haben. Falls nicht, siehe <http://www.gnu.org/licenses/>.
*/

#import <Libmacgpg/GPGGlobals.h>


@interface GPGRemoteKey : NSObject {
	NSString *fingerprint;
	GPGPublicKeyAlgorithm algorithm;
	NSUInteger length;
	NSDate *creationDate;
	NSDate *expirationDate;
	BOOL expired;
	BOOL revoked;
	NSArray *userIDs;
}

@property (nonatomic, readonly) GPGPublicKeyAlgorithm algorithm;
@property (nonatomic, readonly) NSUInteger length;
@property (nonatomic, readonly) BOOL expired;
@property (nonatomic, readonly) BOOL revoked;
@property (nonatomic, readonly, retain) NSString *fingerprint;
@property (nonatomic, readonly, retain) NSString *keyID;
@property (nonatomic, readonly, retain) NSDate *creationDate;
@property (nonatomic, readonly, retain) NSDate *expirationDate;
@property (nonatomic, readonly, retain) NSArray *userIDs;


+ (NSArray <GPGRemoteKey *> *)keysWithListing:(NSString *)listing;
+ (id)keyWithListing:(NSArray *)listing;
- (id)initWithListing:(NSArray *)listing;

@end
