/* GPGTaskHelper.h created by Lukas Pitschl (@lukele) on Thu 02-Jun-2012 */

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

/**
 GPGTaskHelper configures and launches a GPG 2 process.
 If it's used in a sandboxed environment which doesn't allow
 to directly launch sub-processes using NSTask, it automatically
 connects to the GPGTaskHelper XPC Services which then executes
 the GPG 2 process.
 
 Pinentry pass entry is handled directly, other status messages
 from GPG 2 are forwarded to the processStatus handler.
 
 Progress can be observed by setting up the progressHandler.
*/

#import <Foundation/Foundation.h>
#import "GPGGlobals.h"
#import "JailfreeProtocol.h"

@class GPGStream, GPGTaskHelperXPC;

typedef NSData *  (^lp_process_status_t)(NSString *keyword, NSString *value);
typedef void (^lp_progress_handler_t)(NSUInteger processedBytes, NSUInteger totalBytes);

#define GPG_STATUS_PREFIX @"[GNUPG:] "

#define GPGTASKHELPER_DISPATCH_TIMEOUT_ALMOST_INSTANTLY NSEC_PER_SEC / ((long long)1.6) // Should be 625ms (decrease to 500ms after further testing.).
#define GPGTASKHELPER_DISPATCH_TIMEOUT_QUICKLY NSEC_PER_SEC * 5
#define GPGTASKHELPER_DISPATCH_TIMEOUT_LOADS_OF_DATA NSEC_PER_SEC * 60 * 40

// Define DISPATCH_TIME_FOREVER if not available e.g., on 10.6
#ifndef DISPATCH_TIME_FOREVER
#define DISPATCH_TIME_FOREVER ~0ull
#endif

#if defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1080
@interface GPGTaskHelper : NSObject <Jail> {
#else
@interface GPGTaskHelper: NSObject {
#endif
    GPGStream *_inData;
	BOOL _closeInput;
    NSUInteger _totalInData;
    NSArray *_arguments;
    NSDictionary *_environmentVariables;
    GPGStream *_output;
    NSData *_status;
    NSData *_errors;
    NSData *_attributes;
    NSUInteger _exitStatus;
    NSTask *_task;
    lp_process_status_t _processStatus;
    BOOL _readAttributes;
    NSDictionary *_userIDHint;
    NSDictionary *_needPassphraseInfo;
    lp_progress_handler_t _progressHandler;
    NSMutableDictionary *_processedBytesMap;
    NSUInteger _processedBytes;
	BOOL _pinentryCancelled;
    BOOL _cancelled;
    BOOL _checkForSandbox;
#if defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1080
    NSXPCConnection *_sandboxHelper;
#endif
	NSUInteger _timeout;
}

@property (nonatomic, retain) GPGStream *inData;
@property (nonatomic) BOOL closeInput;
@property (nonatomic, copy) NSArray *arguments;
@property (nonatomic, copy) NSDictionary *environmentVariables;
@property (nonatomic, retain) GPGStream *output;
@property (nonatomic, assign) NSUInteger exitStatus;
@property (nonatomic, copy) lp_process_status_t processStatus;
@property (nonatomic, retain, readonly) NSData *status;
@property (nonatomic, retain, readonly) NSData *errors;
@property (nonatomic, retain, readonly) NSData *attributes;
@property (nonatomic, assign) BOOL readAttributes;
@property (nonatomic, copy) lp_progress_handler_t progressHandler;
@property (nonatomic, assign) BOOL checkForSandbox;
@property (nonatomic, assign) NSUInteger timeout;
@property (nonatomic, assign, readonly) BOOL completed;

    
- (int)processIdentifier;
/**
 Configure a new GPG 2 process and pass all command line arguments
 which should be passed to the process.
 */
- (id)initWithArguments:(NSArray *)arguments;

/**
 Launch the GPG 2 process and block till the process finished.
 Returns the exitcode.
 */
- (NSUInteger)run;

/**
 Allows to directly interact with the GPG 2 process via the
 command pipe.
 */
- (void)respond:(id)response;

/**
 A dictionary including all the gathered information.
 */
- (NSDictionary *)copyResult;

- (void)cancel;

/**
 Launch any task. (In sandbox, the task needs to be signed with GPGTools certificate).
 */
+ (BOOL)launchGeneralTask:(NSString *)path withArguments:(NSArray *)arguments wait:(BOOL)wait;

+ (NSString *)gpgAgentSocket;
+ (BOOL)isPassphraseInGPGAgentCache:(id)key;
	
+ (NSDictionary *)statusCodes;


/**
 Opens GPG Suite Preferences.
 */
+ (BOOL)showGPGSuitePreferencesWithArguments:(NSDictionary *)arguments;
	
/**
 Get the arguments, passed to GPG Suite Preferences via temp file.
 Removes the file after reading, so call it once and store it's return value, if needed later.
 Do not call this from inside the sandbox.
 */
+ (NSDictionary *)readGPGSuitePreferencesArguments;


@end

@interface NSTask (GPGThreadSafeWait)
- (void)threadSafeWaitUntilExit;
@end
