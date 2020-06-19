/*
 * Copyright (c) 2000-2011, GPGMail Project Team <gpgtools-devel@lists.gpgtools.org>
 * All rights reserved.
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of GPGMail Project Team nor the names of GPGMail
 *       contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE GPGMAIL PROJECT TEAM ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE GPGMAIL PROJECT TEAM BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Foundation/Foundation.h>

static void usage(const char *progname){
	fprintf(stderr, "%s: property-list file utility\n"
			"    -read plist key\n"
			"    -write plist key value\n"
			"    -delete plist key\n"
			, progname);
}

int main(int argc, char **argv){
	NSAutoreleasePool *localAP = [[NSAutoreleasePool alloc] init];
	NSArray *arguments = [[NSProcessInfo processInfo] arguments];
	BOOL displayUsage = NO;
	int terminationStatus = 0;
	NSString *operation;

	switch ([arguments count]) {
		case 4:
			operation = [arguments objectAtIndex:1];
			if ([operation isEqualToString:@"-read"]) {
				NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:[arguments objectAtIndex:2]];

				if (plist == nil) {
					terminationStatus = 1;
				} else {
					id value = [plist objectForKey:[arguments objectAtIndex:3]];

					if (value == nil) {
						terminationStatus = 1;
					} else {
						[(NSFileHandle *)[NSFileHandle fileHandleWithStandardOutput] writeData:[[value description] dataUsingEncoding:NSUTF8StringEncoding]];
					}
				}
			} else if ([operation isEqualToString:@"-delete"]) {
				NSString *filename = [arguments objectAtIndex:2];
				NSMutableDictionary *plist = [NSMutableDictionary dictionaryWithContentsOfFile:filename];

				if (plist == nil) {
					terminationStatus = 1;
				} else {
					// Deleting a value for a key that doesn't exist is not considered as an error
					[plist removeObjectForKey:[arguments objectAtIndex:3]];
					terminationStatus = ![plist writeToFile:filename atomically:YES];
				}
			} else {
				displayUsage = YES;
				terminationStatus = 1;
			}
			break;
		case 5:
			operation = [arguments objectAtIndex:1];
			if ([operation isEqualToString:@"-write"]) {
				NSString *filename = [arguments objectAtIndex:2];
				NSMutableDictionary *plist = [NSMutableDictionary dictionaryWithContentsOfFile:filename];

				if (plist == nil) {
					// Writing a key-value pair in a file that doesn't exist is not considered as an error
					// File will be created
					plist = [NSMutableDictionary dictionary];
				}
				// Value is written as a plist if possible, else as a string
				@try{
					id aPlist = [[arguments objectAtIndex:4] propertyList];

					[plist setObject:aPlist forKey:[arguments objectAtIndex:3]];
				}@catch (NSException *localException) {
					[plist setObject:[arguments objectAtIndex:4] forKey:[arguments objectAtIndex:3]];
				}
				terminationStatus = ![plist writeToFile:filename atomically:YES];
			} else {
				displayUsage = YES;
				terminationStatus = 1;
			}
			break;
		default:
			displayUsage = YES;
			terminationStatus = 1;
	}

	if (displayUsage) {
		usage([[arguments objectAtIndex:0] cString]);
	}

	[localAP release];
	exit(terminationStatus);
	return terminationStatus;
}
