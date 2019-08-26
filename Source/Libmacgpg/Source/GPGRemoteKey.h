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


@interface GPGRemoteKey : NSObject

@property (nonatomic, readonly) GPGPublicKeyAlgorithm algorithm;
@property (nonatomic, readonly) NSUInteger length;
@property (nonatomic, readonly) BOOL expired;
@property (nonatomic, readonly) BOOL revoked;
@property (nonatomic, readonly) BOOL fromVKS;
@property (nonatomic, readonly, strong) NSString *fingerprint;
@property (nonatomic, readonly, strong) NSString *keyID;
@property (nonatomic, readonly, strong) NSDate *creationDate;
@property (nonatomic, readonly, strong) NSDate *expirationDate;
@property (nonatomic, readonly, strong) NSArray *userIDs;


+ (NSArray<GPGRemoteKey *> *)keysWithListing:(NSString *)listing fromVKS:(BOOL)fromVKS;
+ (NSArray<GPGRemoteKey *> *)keysWithListing:(NSString *)listing;
+ (id)keyWithListing:(NSArray *)listing fromVKS:(BOOL)fromVKS;
+ (id)keyWithListing:(NSArray *)listing;
- (id)initWithListing:(NSArray *)listing fromVKS:(BOOL)fromVKS;
- (id)initWithListing:(NSArray *)listing;

@end
