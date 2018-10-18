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

#import "GPGRemoteKey.h"
#import "GPGRemoteUserID.h"

@interface GPGRemoteKey ()

@property (nonatomic) GPGPublicKeyAlgorithm algorithm;
@property (nonatomic) NSUInteger length;
@property (nonatomic) BOOL expired;
@property (nonatomic) BOOL revoked;
@property (nonatomic, retain) NSString *fingerprint;
@property (nonatomic, retain) NSDate *creationDate;
@property (nonatomic, retain) NSDate *expirationDate;
@property (nonatomic, retain) NSArray *userIDs;

@end


@implementation GPGRemoteKey
@synthesize fingerprint, algorithm, length, creationDate, expirationDate, expired, revoked, userIDs;



+ (NSArray <GPGRemoteKey *> *)keysWithListing:(NSString *)listing {
	NSArray *lines = [listing componentsSeparatedByString:@"\n"];
	NSMutableArray *keys = [NSMutableArray array];
	NSRange range;
	range.location = NSNotFound;
	NSUInteger i = 0, count = [lines count];
	
	
	for (; i < count; i++) {
		if ([[lines objectAtIndex:i] hasPrefix:@"pub:"]) {
			if (range.location != NSNotFound) {
				range.length = i - range.location;
				[keys addObject:[self keyWithListing:[lines subarrayWithRange:range]]];
			}
			range.location = i;
		}
	}
	if (range.location != NSNotFound) {
		range.length = i - range.location;
		[keys addObject:[self keyWithListing:[lines subarrayWithRange:range]]];
	}
	
	return keys;
}

+ (id)keyWithListing:(NSArray *)listing {
	return [[[self alloc] initWithListing:listing] autorelease];
}

- (id)initWithListing:(NSArray *)listing {
	if ((self = [super init]) == nil) {
		return nil;
	}
	
	NSArray *splitedLine = [[listing objectAtIndex:0] componentsSeparatedByString:@":"];
	
	self.fingerprint = splitedLine[1];
	self.algorithm = [[splitedLine objectAtIndex:2] intValue];
	self.length = [[splitedLine objectAtIndex:3] integerValue];
	
	self.creationDate = [NSDate dateWithGPGString:[splitedLine objectAtIndex:4]];
	self.expirationDate = [NSDate dateWithGPGString:[splitedLine objectAtIndex:5]];
	if (expirationDate && !expired) {
		self.expired = [[NSDate date] isGreaterThanOrEqualTo:expirationDate];
	}

	if ([[splitedLine objectAtIndex:6] length] > 0) {
		if ([[splitedLine objectAtIndex:6] isEqualToString:@"r"]) {
			self.revoked = YES;
		} else {
			GPGDebugLog(@"Uknown flag: %@", [listing objectAtIndex:0]);
		}
	}
	
	NSUInteger i = 1, c = [listing count];
	NSMutableArray *theUserIDs = [NSMutableArray arrayWithCapacity:c - 1];
	for (; i < c; i++) {
		GPGRemoteUserID *tempUserID = [GPGRemoteUserID userIDWithListing:[listing objectAtIndex:i]];
		if (tempUserID) {
			[theUserIDs addObject:tempUserID]; 
		}
	}
	self.userIDs = theUserIDs;
	
	
	return self;	
}

- (NSString *)keyID {
	return self.fingerprint.shortKeyID;
}

- (void)dealloc {
	[fingerprint release];
	[creationDate release];
	[expirationDate release];
	[userIDs release];
	[super dealloc];
}

- (NSUInteger)hash {
	return [fingerprint hash];
}
- (BOOL)isEqual:(id)anObject {
	return [fingerprint isEqualToString:[anObject description]];
}
- (NSString *)description {
	return [[fingerprint retain] autorelease];
}


@end
