//
//  SignatureViewAppAppDelegate.m
//  SignatureViewApp
//
//  Created by Lukas Pitschl on 26.07.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "SignatureViewAppAppDelegate.h"
#import <Libmacgpg/Libmacgpg.h>
#import "SignatureView.h"

@implementation SignatureViewAppAppDelegate

@synthesize window = _window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    GPGController *gpgc = [[[GPGController alloc] init] autorelease];
    gpgc.verbose = YES;
    NSSet *keys = [gpgc allKeys];
    
    NSData *d1 = [NSData dataWithContentsOfFile:@"/Users/lukele/Desktop/hello.txt.asc"];
    NSData *d2 = [gpgc decryptData:d1];
    NSLog(@"Signatures: %@", [gpgc signatures]);
    
    NSLog(@"SignatureView: %@", [SignatureView class]);
    SignatureView *s = [SignatureView signatureView];
    NSLog(@"Signature view: %p", s);
    [s setKeyList:keys];
    [s setSignatures:[gpgc signatures]];
    [s run];
}

@end
