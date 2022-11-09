/* NSBundle+Sandbox.h created by Lukas Pitschl (@lukele) on Sut 29-Sep-2012 */

/*
 * Copyright (c) 2000-2017, GPGTools Team <team@gpgtools.org>
 * All rights reserved.
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of GPGTools Project Team nor the names of GPGMail
 *       contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE GPGTools Project Team ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE GPGTools Project Team BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "NSBundle+Sandbox.h"

#import <Security/SecRequirement.h>
#import <objc/runtime.h>


@interface NSBundle (OBCodeSigningInfoPrivateMethods)
- (SecStaticCodeRef)ob_createStaticCode;
- (SecRequirementRef)ob_sandboxRequirement;
@end


@implementation NSBundle (OBCodeSigningInfo)

- (BOOL)ob_comesFromAppStore
{
    // Check existence of Mac App Store receipt
    NSURL *appStoreReceiptURL = [self appStoreReceiptURL];
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    BOOL appStoreReceiptExists = [fileManager fileExistsAtPath:[appStoreReceiptURL path]];
    [fileManager release];
    return appStoreReceiptExists;
}


- (BOOL)ob_isSandboxed
{
    BOOL isSandboxed = NO;
    if ([self ob_codeSignState] == OBCodeSignStateSignatureValid)
    {
        SecStaticCodeRef staticCode = [self ob_createStaticCode];
        SecRequirementRef sandboxRequirement = [self ob_sandboxRequirement];
        if (staticCode && sandboxRequirement) {
            OSStatus codeCheckResult = SecStaticCodeCheckValidityWithErrors(staticCode, kSecCSBasicValidateOnly, sandboxRequirement, NULL);
            if (codeCheckResult == errSecSuccess) {
                isSandboxed = YES;
            }
            CFRelease(staticCode);
        }
    }
    return isSandboxed;
}


- (OBCodeSignState)ob_codeSignState
{
    // Return cached value if it exists
    static const void *kOBCodeSignStateKey;
    NSNumber *resultStateNumber = objc_getAssociatedObject(self, kOBCodeSignStateKey);
    if (resultStateNumber) {
        return (OBCodeSignState)[resultStateNumber integerValue];
    }
    
    // Determine code sign status
    OBCodeSignState resultState = OBCodeSignStateError;
    SecStaticCodeRef staticCode = [self ob_createStaticCode];
    if (staticCode)
    {
        OSStatus signatureCheckResult = SecStaticCodeCheckValidityWithErrors(staticCode, kSecCSBasicValidateOnly, NULL, NULL);
        switch (signatureCheckResult) {
            case errSecSuccess: resultState = OBCodeSignStateSignatureValid; break;
            case errSecCSUnsigned: resultState = OBCodeSignStateUnsigned; break;
            case errSecCSSignatureFailed:
            case errSecCSSignatureInvalid:
                resultState = OBCodeSignStateSignatureInvalid;
                break;
            case errSecCSSignatureNotVerifiable: resultState = OBCodeSignStateSignatureNotVerifiable; break;
            case errSecCSSignatureUnsupported: resultState = OBCodeSignStateSignatureUnsupported; break;
            default: resultState = OBCodeSignStateError; break;
        }
        CFRelease(staticCode);
    }
    else
    {
        resultState = OBCodeSignStateError;
    }
    
    // Cache the result
    resultStateNumber = [NSNumber numberWithInteger:resultState];
    objc_setAssociatedObject(self, kOBCodeSignStateKey, resultStateNumber, OBJC_ASSOCIATION_RETAIN);
    
    return resultState;
}

- (BOOL)isValidSigned {
    SecRequirementRef requirement = nil;
    SecStaticCodeRef staticCode = nil;
	
    SecStaticCodeCreateWithPath((__bridge CFURLRef)[self bundleURL], kSecCSDefaultFlags, &staticCode);
    SecCSFlags validityFlags = kSecCSDefaultFlags | kSecCSCheckNestedCode | kSecCSCheckAllArchitectures | kSecCSEnforceRevocationChecks;
    // E2C077C85EC4024699920B3C206364F742CEC790 is the Developer ID Application expiring on 2027-02-01
    SecRequirementCreateWithString(CFSTR("anchor apple generic and ( cert leaf = H\"C21964B138DE0094F42CEDE7078C6F800BA5838B\" or cert leaf = H\"233B4E43187B51BF7D6711053DD652DDF54B43BE\" or cert leaf = H\"E2C077C85EC4024699920B3C206364F742CEC790\" ) "), kSecCSDefaultFlags, &requirement);
	
	OSStatus result = SecStaticCodeCheckValidity(staticCode, validityFlags, requirement);
    
    if (staticCode) CFRelease(staticCode);
    if (requirement) CFRelease(requirement);
    return result == noErr;
}


#pragma mark - Private helper methods

- (SecStaticCodeRef)ob_createStaticCode
{
    NSURL *bundleURL = [self bundleURL];
    SecStaticCodeRef staticCode = NULL;
    SecStaticCodeCreateWithPath(( CFURLRef)bundleURL, kSecCSDefaultFlags, &staticCode);
    return staticCode;
}

- (SecRequirementRef)ob_sandboxRequirement
{
    static SecRequirementRef sandboxRequirement = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SecRequirementCreateWithString(CFSTR("entitlement[\"com.apple.security.app-sandbox\"] exists"), kSecCSDefaultFlags, &sandboxRequirement);
    });
    return sandboxRequirement;
}

@end
