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
#if !__has_feature(objc_arc)
#error This files requires ARC.
#endif

#import "GPGRemoteKey.h"
#import "GPGRemoteUserID.h"

@interface GPGRemoteKey ()

@property (nonatomic) GPGPublicKeyAlgorithm algorithm;
@property (nonatomic) NSUInteger length;
@property (nonatomic) BOOL expired;
@property (nonatomic) BOOL revoked;
@property (nonatomic) BOOL fromVKS;
@property (nonatomic, strong) NSString *fingerprint;
@property (nonatomic, strong) NSDate *creationDate;
@property (nonatomic, strong) NSDate *expirationDate;
@property (nonatomic, strong) NSArray *userIDs;

@end


@implementation GPGRemoteKey


+ (NSArray <GPGRemoteKey *> *)keysWithListing:(NSString *)listing fromVKS:(BOOL)fromVKS {
	NSArray<NSString *> *lines = [listing componentsSeparatedByString:@"\n"];
	NSMutableArray *keys = [NSMutableArray new];
	NSRange range;
	range.location = NSNotFound;
	NSUInteger i = 0, count = lines.count;
	
	
	for (; i < count; i++) {
		if ([lines[i] hasPrefix:@"pub:"]) {
			if (range.location != NSNotFound) {
				range.length = i - range.location;
				[keys addObject:[self keyWithListing:[lines subarrayWithRange:range] fromVKS:fromVKS]];
			}
			range.location = i;
		}
	}
	if (range.location != NSNotFound) {
		range.length = i - range.location;
		[keys addObject:[self keyWithListing:[lines subarrayWithRange:range] fromVKS:fromVKS]];
	}
	
	return keys;
}
+ (NSArray <GPGRemoteKey *> *)keysWithListing:(NSString *)listing {
	return [self keysWithListing:listing fromVKS:NO];
}

+ (id)keyWithListing:(NSArray *)listing {
	return [[self alloc] initWithListing:listing fromVKS:NO];
}
+ (id)keyWithListing:(NSArray *)listing fromVKS:(BOOL)fromVKS {
	return [[self alloc] initWithListing:listing fromVKS:fromVKS];
}

- (id)initWithListing:(NSArray<NSString *> *)listing fromVKS:(BOOL)fromVKS {
	if ((self = [super init]) == nil) {
		return nil;
	}
	
	NSArray<NSString *> *splitedLine = [listing[0] componentsSeparatedByString:@":"];
	
	self.fingerprint = splitedLine[1];
	self.algorithm = splitedLine[2].intValue;
	self.length = splitedLine[3].integerValue;
	
	self.creationDate = [NSDate dateWithGPGString:splitedLine[4]];
	self.expirationDate = [NSDate dateWithGPGString:splitedLine[5]];
	if (_expirationDate && !_expired) {
		self.expired = [[NSDate date] isGreaterThanOrEqualTo:_expirationDate];
	}

	if (splitedLine[6].length > 0) {
		if ([splitedLine[6] isEqualToString:@"r"]) {
			self.revoked = YES;
		} else {
			GPGDebugLog(@"Uknown flag: %@", listing[0]);
		}
	}
	
	NSUInteger i = 1, c = [listing count];
	NSMutableArray *theUserIDs = [NSMutableArray arrayWithCapacity:c - 1];
	for (; i < c; i++) {
		GPGRemoteUserID *tempUserID = [GPGRemoteUserID userIDWithListing:listing[i]];
		if (tempUserID) {
			[theUserIDs addObject:tempUserID]; 
		}
	}
	self.userIDs = theUserIDs;
	self.fromVKS = fromVKS;
	
	
	return self;	
}
- (id)initWithListing:(NSArray<NSString *> *)listing {
	return [self initWithListing:listing fromVKS:NO];
}

- (NSString *)keyID {
	return self.fingerprint.shortKeyID;
}

- (NSUInteger)hash {
	return [_fingerprint hash];
}
- (BOOL)isEqual:(id)anObject {
	return [_fingerprint isEqualToString:[anObject description]];
}
- (NSString *)description {
	return _fingerprint;
}


@end
