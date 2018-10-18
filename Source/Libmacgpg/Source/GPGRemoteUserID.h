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

#import <Libmacgpg/GPGUserID.h>

@interface GPGRemoteUserID : NSObject <GPGUserIDProtocol> {
	NSString *userIDDescription;
	NSString *name;
	NSString *email;
	NSString *comment;
	NSDate *creationDate;
	NSDate *expirationDate;
}

@property (nonatomic, retain) NSString *userIDDescription;
@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain) NSString *email;
@property (nonatomic, retain) NSString *comment;
@property (nonatomic, readonly, retain) NSDate *creationDate;
@property (nonatomic, readonly, retain) NSDate *expirationDate;
@property (nonatomic, readonly) NSImage *image;


+ (id)userIDWithListing:(NSString *)listing;
- (id)initWithListing:(NSString *)listing;

@end
