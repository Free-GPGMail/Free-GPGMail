/*
 Copyright © Roman Zechmeister und Lukas Pitschl (@lukele), 2017
 
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

@class GPGKey, NSImage, GPGUserIDSignature;


@protocol GPGUserIDProtocol <NSObject>
@property (nonatomic, readonly) NSString *userIDDescription;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *email;
@property (nonatomic, readonly) NSString *comment;
@property (nonatomic, readonly) NSImage *image;
@end


@interface GPGUserID : NSObject <GPGUserIDProtocol> {
	NSString *_userIDDescription;
	NSString *_name;
	NSString *_email;
	NSString *_comment;
	NSString *_hashID;
	NSImage *_image;
	NSDate *_creationDate;
	NSDate *_expirationDate;
	GPGValidity _validity;
	
	GPGKey *_primaryKey;
	NSArray *_signatures;
	GPGUserIDSignature *_revocationSignature;
	
}

- (instancetype)init;
- (instancetype)initWithUserIDDescription:(NSString *)userIDDescription;

@property (nonatomic, readonly) NSString *userIDDescription;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *email;
@property (nonatomic, readonly) NSString *comment;
@property (nonatomic, readonly) NSString *hashID;
@property (nonatomic, readonly) NSImage *image;
@property (nonatomic, readonly) NSDate *creationDate;
@property (nonatomic, readonly) NSDate *expirationDate;
@property (nonatomic, readonly) GPGValidity validity;

@property (nonatomic, readonly) NSArray *signatures;
@property (nonatomic, readonly) GPGUserIDSignature *selfSignature;
@property (nonatomic, readonly) GPGUserIDSignature *revocationSignature;
@property (nonatomic, readonly) GPGKey *primaryKey;

@property (nonatomic, readonly) BOOL mdcSupport;
@property (nonatomic, readonly) BOOL isUat;

@end

