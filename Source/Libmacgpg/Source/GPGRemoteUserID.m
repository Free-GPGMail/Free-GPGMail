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

#import "GPGRemoteUserID.h"


@interface GPGRemoteUserID ()

@property (nonatomic, retain) NSDate *creationDate;
@property (nonatomic, retain) NSDate *expirationDate;

@end


@implementation GPGRemoteUserID
@synthesize userIDDescription, name, email, comment, creationDate, expirationDate;


+ (id)userIDWithListing:(NSString *)listing {
	return [[[self alloc] initWithListing:listing] autorelease];
}

- (id)initWithListing:(NSString *)listing {
	if (self = [super init]) {
		NSArray *splitedLine = [listing componentsSeparatedByString:@":"];
		
		if (splitedLine.count < 2) {
			[self release];
			return nil;
		}
		
		
		NSString *decodedString = [splitedLine[1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		
		if (!decodedString) {
			int encodings[] = {NSISOLatin1StringEncoding, NSISOLatin2StringEncoding, NSASCIIStringEncoding, 0};
			int i = 0;
			
			while (encodings[i]) {
				decodedString = [splitedLine[1] stringByReplacingPercentEscapesUsingEncoding:encodings[i]];
				if (decodedString) {
					break;
				}
				i++;
			}
		}
		
		self.userIDDescription = decodedString;
		
		if (splitedLine.count >= 3) {
			self.creationDate = [NSDate dateWithGPGString:splitedLine[2]];
		}
		if (splitedLine.count >= 4) {
			self.expirationDate = [NSDate dateWithGPGString:splitedLine[3]];
		}
	}
	return self;	
}

- (void)setUserIDDescription:(NSString *)value {
	if (value != userIDDescription) {
		[userIDDescription release];
		userIDDescription = [value retain];
		
		NSDictionary *dict = [value splittedUserIDDescription];
		self.name = dict[@"name"];
		self.email = dict[@"email"];
		self.comment = dict[@"comment"];
	}
}

-(NSImage *)image {
	return nil;
}

- (void)dealloc {
	self.userIDDescription = nil;
	self.name = nil;
	self.email = nil;
	self.comment = nil;
	self.creationDate = nil;
	self.expirationDate = nil;
	[super dealloc];
}



@end
