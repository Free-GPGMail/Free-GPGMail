#import <Foundation/Foundation.h>
#import "Libmacgpg.h"


extern NSString *testKey;
extern NSString *testKey2;
extern NSString *testSubkey;
extern NSString *unitTestHome;

extern GPGController *gpgc;
extern GPGKeyManager *manager;


@interface GPGUnitTest : NSObject

+ (void)setUpTestDirectory;
+ (NSData *)dataForResource:(NSString *)name;
+ (GPGStream *)streamForResource:(NSString *)name;

@end
