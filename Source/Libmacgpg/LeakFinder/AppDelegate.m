//
//  AppDelegate.m
//  LeakFinder
//
//  Created by Lukas Pitschl on 23.04.13.
//
//

#import <Libmacgpg/Libmacgpg.h>
#import "AppDelegate.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// Insert code here to initialize your application
}

- (IBAction)doEncrypt:(id)sender {
	NSLog(@"Start round.");
	@autoreleasepool {
		NSData *inputData = [[NSData alloc] initWithContentsOfFile:@"/Users/lukele/Downloads/GPGTools-20130330-2.dmg"];
		GPGController *gc = [[GPGController alloc] init];
		[gc addSignerKey:@"E58271326F9F4937"];
		NSData *encryptedData = [gc processData:inputData withEncryptSignMode:GPGPublicKeyEncrypt recipients:@[@"E58271326F9F4937"] hiddenRecipients:nil];
		NSLog(@"encrypted data: %ld", (unsigned long)[encryptedData length]);
		NSData *decryptedData = [gc decryptData:encryptedData];
		NSLog(@"decrypted data: %ld", (unsigned long)[decryptedData length]);
	}
}

@end
