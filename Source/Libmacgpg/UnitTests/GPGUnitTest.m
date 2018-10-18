#import "GPGUnitTest.h"

NSString *testKey = @"77270A31BEE39087C6B7E771F988A4590DB03A7D";
NSString *testKey2 = @"672730F976B5D34B21FE47EBFFF63006274090B4";
NSString *testSubkey = @"30BD46FC8599CB334466CFC5526B09F10AA3DA82";
NSString *unitTestHome = @"/tmp/Libmacgpg_UnitTest";
GPGController *gpgc = nil;
GPGKeyManager *manager = nil;



@implementation GPGUnitTest

+ (void)setUpTestDirectory {
	static BOOL didSetUp = NO;
	
	if (!didSetUp) {
		didSetUp = YES;
		
		NSFileManager *fileManager = [NSFileManager defaultManager];
		BOOL isDirectory;
		
		if ([fileManager fileExistsAtPath:unitTestHome isDirectory:&isDirectory] && isDirectory) {
			[fileManager removeItemAtPath:unitTestHome error:nil];
		}
		[fileManager createDirectoryAtPath:unitTestHome withIntermediateDirectories:NO attributes:nil error:nil];
		
		
		manager = [GPGKeyManager sharedInstance];
		manager.homedir = unitTestHome;
		
		gpgc = [[GPGController alloc] init];
		gpgc.gpgHome = unitTestHome;
		gpgc.passphrase = @"123";
		
		NSData *data = [self dataForResource:@"OpenPGP.asc"];
		[gpgc importFromData:data fullImport:TRUE];
	}
}

+ (NSData *)dataForResource:(NSString *)name {
	NSBundle *unitTestBundle = [NSBundle bundleForClass:[self class]];
	NSString *path = [unitTestBundle pathForResource:name ofType:@""];
	NSData *data = [NSData dataWithContentsOfFile:path];
	if (!data) {
		@throw [NSException exceptionWithName:@"ApplicationException" reason:@"missing resource" userInfo:nil];
	}
	return data;
}

+ (GPGStream *)streamForResource:(NSString *)name {
	NSBundle *unitTestBundle = [NSBundle bundleForClass:[self class]];
	NSString *path = [unitTestBundle pathForResource:name ofType:@""];
	GPGFileStream *stream = [GPGFileStream fileStreamForReadingAtPath:path];
	if (!stream) {
		@throw [NSException exceptionWithName:@"ApplicationException" reason:@"missing resource" userInfo:nil];
	}
	return stream;
}


@end


