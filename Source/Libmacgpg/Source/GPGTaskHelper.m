/* GPGTaskHelper created by Lukas Pitschl (@lukele) on Thu 02-Jun-2012 */

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

#import "GPGOptions.h"
#import "GPGGlobals.h"
#import "GPGTaskHelper.h"
#import "GPGMemoryStream.h"
#import "NSPipe+NoSigPipe.h"
#import "NSBundle+Sandbox.h"
#import "GPGException.h"
#import "JailfreeProtocol.h"
#if defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1080
#import "GPGTaskHelperXPC.h"
#endif
#import "GPGTask.h"
#import "GPGUTF8Argument.h"

#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>
#import <sys/stat.h>


static const NSUInteger kDataBufferSize = 65536; 
static NSString * const GPGPreferencesShowTabNotification = @"GPGPreferencesShowTabNotification";

typedef void (^basic_block_t)(void);

#pragma mark Helper methods
/**
 Helper method to run a block and intercept any exceptions.
 Copies the exceptions into the given blockException reference.
 */
void runBlockAndRecordExceptionSynchronizedWithHandlers(basic_block_t run_block, basic_block_t catch_block, basic_block_t finally_block, NSObject **lock, NSException **blockException) {
    
    @try {
        run_block();
    }
    @catch (NSException *exception) {
        @synchronized(*lock) {
            *blockException = [exception retain];
        }
        if(catch_block)
            catch_block();
    }
    @finally {
        if(finally_block)
            finally_block();
    }
}

void runBlockAndRecordExceptionSyncronized(basic_block_t run_block, NSObject **lock, NSException **blockException) {
    runBlockAndRecordExceptionSynchronizedWithHandlers(run_block, NULL, NULL, lock, blockException);
}

/**
 Runs a block within a sub autorelease pool.
 */
void withAutoreleasePool(basic_block_t block)
{
    NSAutoreleasePool *pool = nil;
    @try {
        pool = [[NSAutoreleasePool alloc] init];
        block();
    }
    @catch (NSException *exception) {
        @throw [exception retain];
    }
    @finally {
        [pool release];
    }
}

#pragma mark GPGTaskHelper

@interface GPGTaskHelper ()

@property (nonatomic, retain, readwrite) NSData *status;
@property (nonatomic, retain, readwrite) NSData *errors;
@property (nonatomic, retain, readwrite) NSData *attributes;
@property (nonatomic, retain, readonly) NSTask *task;
@property (nonatomic, retain) NSDictionary *userIDHint;
@property (nonatomic, retain) NSDictionary *needPassphraseInfo;

- (void)writeData:(GPGStream *)data pipe:(NSPipe *)pipe close:(BOOL)close;

@end

@implementation GPGTaskHelper

@synthesize inData = _inData, arguments = _arguments, output = _output, processStatus = _processStatus, task = _task,
exitStatus = _exitStatus, status = _status, errors = _errors, attributes = _attributes, readAttributes = _readAttributes,
progressHandler = _progressHandler, userIDHint = _userIDHint, needPassphraseInfo = _needPassphraseInfo,
checkForSandbox = _checkForSandbox, timeout = _timeout, environmentVariables=_environmentVariables,
closeInput = _closeInput;

+ (NSString *)findExecutableWithName:(NSString *)executable {
	NSString *foundPath;
	NSArray *searchPaths = [NSMutableArray arrayWithObjects:@"/usr/local/MacGPG2/bin", @"/usr/local/bin", @"/usr/local/MacGPG1/bin", @"/usr/bin", @"/bin", @"/opt/local/bin", @"/sw/bin", nil];
	
	foundPath = [self findExecutableWithName:executable atPaths:searchPaths];
	if (foundPath) {
		return foundPath;
	}
	
	NSString *envPATH = [[[NSProcessInfo processInfo] environment] objectForKey:@"PATH"];
	if (envPATH) {
		NSArray *newSearchPaths = [envPATH componentsSeparatedByString:@":"];
		foundPath = [self findExecutableWithName:executable atPaths:newSearchPaths];
		if (foundPath) {
			return foundPath;
		}		
	}
	
	return nil;
}
+ (NSString *)findExecutableWithName:(NSString *)executable atPaths:(NSArray *)paths {
	NSString *searchPath, *foundPath;
	for (searchPath in paths) {
		foundPath = [searchPath stringByAppendingPathComponent:executable];
		if ([[NSFileManager defaultManager] isExecutableFileAtPath:foundPath]) {
			return [foundPath stringByStandardizingPath];
		}
	}
	return nil;
}

+ (NSString *)GPGPath {
    static NSString *GPGPath = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        GPGPath = [GPGTaskHelper findExecutableWithName:@"gpg2"];
		if (!GPGPath) {
            GPGPath = [GPGTaskHelper findExecutableWithName:@"gpg"];
		}
        [GPGPath retain];
    });
	if (!GPGPath) {
		onceToken = 0;
	}
    return GPGPath;
}

- (id)initWithArguments:(NSArray *)arguments {
    self = [super init];
    if(self) {
        _arguments = [arguments copy];
        _processedBytesMap = [[NSMutableDictionary alloc] init];
	}
    return self;
}

- (NSUInteger)_run {
	NSString *statusFifoPath = nil;
	NSString *attributeFifoPath = nil;
	
    _task = [[NSTask alloc] init];
    _task.launchPath = [GPGTaskHelper GPGPath];
	
	
	
	NSMutableDictionary *environment = [[NSProcessInfo processInfo].environment.mutableCopy autorelease];
	[environment addEntriesFromDictionary:self.environmentVariables];
	_task.environment = environment;
	
	if (!_task.launchPath || ![[NSFileManager defaultManager] isExecutableFileAtPath:_task.launchPath]) {
        @throw [GPGException exceptionWithReason:@"GPG not found!" errorCode:GPGErrorNotFound];
	}
	
	
	
	// Create fifos for status-file and attribute-file.
	NSMutableArray<NSString *> *mutableArguments = self.arguments.mutableCopy;
	
	NSString *tempDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"org.gpgtools.libmacgpg"];
	NSError *error = nil;
	if (![[NSFileManager defaultManager] createDirectoryAtPath:tempDir withIntermediateDirectories:YES attributes:nil error:&error]) {
		[NSException raise:NSGenericException format:@"createDirectory failed: %@", error.localizedDescription];
	}
	
	NSUInteger index = [mutableArguments indexOfObject:GPGStatusFilePlaceholder];
	if (index != NSNotFound) {
		NSString *guid = [NSProcessInfo processInfo].globallyUniqueString ;
		NSString *fifoName = [NSString stringWithFormat:@"gpgtmp_%@.fifo", guid];
		statusFifoPath = [tempDir stringByAppendingPathComponent:fifoName];
		if (mkfifo(statusFifoPath.UTF8String, 0600) != 0) {
			[NSException raise:NSGenericException format:@"mkfifo failed: %s", strerror(errno)];
		}
		
		// Replace the placeholder with the real path.
		[mutableArguments replaceObjectAtIndex:index withObject:statusFifoPath];
	}
	
	index = [mutableArguments indexOfObject:GPGAttributeFilePlaceholder];
	if (index != NSNotFound) {
		NSString *guid = [NSProcessInfo processInfo].globallyUniqueString ;
		NSString *fifoName = [NSString stringWithFormat:@"gpgtmp_%@.fifo", guid];
		attributeFifoPath = [tempDir stringByAppendingPathComponent:fifoName];
		
		if (mkfifo(attributeFifoPath.UTF8String, 0600) != 0) {
			[NSException raise:NSGenericException format:@"mkfifo failed: %s", strerror(errno)];
		}
		
		// Replace the placeholder with the real path.
		[mutableArguments replaceObjectAtIndex:index withObject:attributeFifoPath];
	}
	
	// Convert all arguments to GPGUTF8Argument, so umlauts are correctly utf-8 encoded.
	NSUInteger count = mutableArguments.count;
	for (NSUInteger i = 0; i < count; i++) {
		GPGUTF8Argument *argument = [GPGUTF8Argument stringWithString:mutableArguments[i]];
		mutableArguments[i] = argument;
	}
	
	
	_task.arguments = mutableArguments;
	[mutableArguments release];

	

	_task.standardInput = [NSPipe pipe].noSIGPIPE;
	_task.standardOutput = [NSPipe pipe].noSIGPIPE;
	_task.standardError = [NSPipe pipe].noSIGPIPE;

	
    GPGDebugLog(@"$> %@ %@", _task.launchPath, [_task.arguments componentsJoinedByString:@" "]);
	[_task launch];

	
	_totalInData = self.inData.length;
	
    __block NSException *blockException = nil;
    __block NSData *stderrData = nil;
    __block NSData *statusData = nil;
    __block NSData *attributeData = nil;
    __block NSObject *lock = [[[NSObject alloc] init] autorelease];
	
	
	dispatch_queue_t queue = dispatch_queue_create("org.gpgtools.libmacgpg.gpgTaskHelper", DISPATCH_QUEUE_CONCURRENT);
	dispatch_group_t collectorGroup = dispatch_group_create();
	
	// The data is written to the pipe as soon as gpg issues the status
	// BEGIN_ENCRYPTION or BEGIN_SIGNING. See processStatus.
	// When we want to encrypt or sign, the data can't be written before the
	// BEGIN_ENCRYPTION or BEGIN_SIGNING status was issued, BUT
	// in every other case, gpg stalls till it received the data to decrypt.
	// So in that case, the data actually has to be written as the very first thing.
	NSArray *options = @[@"--encrypt", @"--sign", @"--clearsign", @"--detach-sign", @"--symmetric", @"-e", @"-s", @"-b", @"-c"];
	BOOL shouldWriteInput = ([self.arguments firstObjectCommonWithArray:options] == nil);
	
	if (!shouldWriteInput) {
		// If --passphrase-fd 0 is used, the data has to be written before any status
		// was issued, because gpg will wait until it gets the passphrase from stdin.
		index = [self.arguments indexOfObject:@"--passphrase-fd"];
		if (self.arguments.count >= index + 1) {
			shouldWriteInput = [self.arguments[index+1] isEqualToString:@"0"];
		}
	}
	if (shouldWriteInput) {
		dispatch_group_async(collectorGroup, queue, ^{
			runBlockAndRecordExceptionSyncronized(^{
				[self writeInputData];
			}, &lock, &blockException);
		});
	}
	
	
	dispatch_group_async(collectorGroup, queue, ^{
		runBlockAndRecordExceptionSyncronized(^{
			NSData *data;
			NSFileHandle *stdoutFH = [_task.standardOutput fileHandleForReading];
			while ((data = [stdoutFH readDataOfLength:kDataBufferSize]) && data.length > 0) {
				withAutoreleasePool(^{
					[self->_output writeData:data];
				});
			}
		}, &lock, &blockException);
	});
	
	dispatch_group_async(collectorGroup, queue, ^{
		runBlockAndRecordExceptionSyncronized(^{
			NSMutableData *mutableData = [NSMutableData data];
			NSData *data;
			NSFileHandle *stderrFH = [_task.standardError fileHandleForReading];
			while ((data = [stderrFH readDataOfLength:kDataBufferSize]) && data.length > 0) {
				[mutableData appendData:data];
			}
			// Needs to be retained to survive the block.
			stderrData = [mutableData copy];
		}, &lock, &blockException);
	});
	
	if (attributeFifoPath) {
		dispatch_group_async(collectorGroup, queue, ^{
			runBlockAndRecordExceptionSyncronized(^{
				NSMutableData *mutableData = [NSMutableData data];
				NSData *data;
				NSFileHandle *stderrFH = [NSFileHandle fileHandleForReadingAtPath:attributeFifoPath];
				while ((data = [stderrFH readDataOfLength:kDataBufferSize]) && data.length > 0) {
					[mutableData appendData:data];
				}
				// Needs to be retained to survive the block.
				attributeData = [mutableData copy];
			}, &lock, &blockException);
		});
	}

	if (statusFifoPath) {
		dispatch_group_async(collectorGroup, queue, ^{
			runBlockAndRecordExceptionSyncronized(^{
				statusData = [self readStatusFile:statusFifoPath];
				// Needs to be retained to survive the block.
				[statusData retain];
			}, &lock, &blockException);
		});
	}

	
	
	// Wait for all jobs to complete.
	dispatch_group_wait(collectorGroup, DISPATCH_TIME_FOREVER);
	
	dispatch_release(collectorGroup);
	dispatch_release(queue);

	[_task threadSafeWaitUntilExit];

	
	
	
	if (statusFifoPath) {
		[[NSFileManager defaultManager] removeItemAtPath:statusFifoPath error:nil];
	}
	if (attributeFifoPath) {
		[[NSFileManager defaultManager] removeItemAtPath:attributeFifoPath error:nil];
	}
	
    if (blockException && !_cancelled && !_pinentryCancelled) {
		[statusData release];
		[stderrData release];
		[attributeData release];
        @throw blockException;
	}
	
	self.status = statusData;
    [statusData release];
	self.errors = stderrData;
	[stderrData release];
    self.attributes = attributeData;
	[attributeData release];
	
    _exitStatus = _task.terminationStatus;
    
    if(_cancelled || (_pinentryCancelled && _exitStatus != 0))
        _exitStatus = GPGErrorCancelled;
    
	return _exitStatus;
}

- (BOOL)completed {
	return !_task.isRunning;
}

- (void)progress:(NSUInteger)processedBytes total:(NSUInteger)total {
    if(self.progressHandler)
        self.progressHandler(processedBytes, total);
}

- (int)processIdentifier {
    return _task.processIdentifier;
}

- (NSUInteger)_runInSandbox {
#if defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1080
	// This code is only necessary for >= 10.8, don't even bother compiling it
	// on older platforms. Wouldn't anyway.
	// XPC name: org.gpgtools.Libmacgpg.jailfree.xpc_OpenStep
    
	__block GPGTaskHelper * weakSelf = self;
	
	GPGTaskHelperXPC *xpcTask = [[GPGTaskHelperXPC alloc] init];
	xpcTask.progressHandler = ^(NSUInteger processedBytes, NSUInteger total) {
		if(weakSelf.progressHandler)
			weakSelf.progressHandler(processedBytes, total);
	};
	xpcTask.processStatus = ^NSData *(NSString *keyword, NSString *value) {
		if(!self.processStatus)
			return nil;
		
		NSData *response = weakSelf.processStatus(keyword, value);
		return response;
	};
	
	NSDictionary *result = nil;
	@try {
		result = [xpcTask launchGPGWithArguments:self.arguments data:_inData.readAllData readAttributes:self.readAttributes closeInput:_closeInput];
	}
	@catch (NSException *exception) {
		[xpcTask release];
		@throw exception;
		
		return -1;
	}
	
	
	if([result objectForKey:@"output"])
		[_output writeData:[result objectForKey:@"output"]];
	[_output release];
	_output = nil;
	
	if([result objectForKey:@"status"])
		self.status = [result objectForKey:@"status"];
	if([result objectForKey:@"attributes"])
		self.attributes = [result objectForKey:@"attributes"];
	if([result objectForKey:@"errors"])
		self.errors = [result objectForKey:@"errors"];
	self.exitStatus = [[result objectForKey:@"exitStatus"] intValue];
	
	[xpcTask release];
	
	return [[result objectForKey:@"exitStatus"] intValue];
#else
	NSLog(@"This should never be called on OS X < 10.8? Please report to team@gpgtools.org if you're seeing this message.");
#endif
}

- (NSUInteger)run {
    if(self.checkForSandbox && [GPGTask sandboxed])
        return [self _runInSandbox];
    else
        return [self _run];
}

- (void)writeInputData {
    if(!_task || !self.inData) {
        return;
    }
	
	NSPipe *stdinPipe = self.task.standardInput;

	[self writeData:self.inData pipe:stdinPipe close:_closeInput];
	
    self.inData = nil;
}

- (void)writeData:(GPGStream *)data pipe:(NSPipe *)pipe close:(BOOL)close {
    // If the task was already shutdown, it's still possible that
    // responds to status messages have to be processed in XPC mode.
    // In that case however the pipe no longer exists, so don't do anything.
    if(!pipe)
        return;
    NSFileHandle *ofh = [pipe fileHandleForWriting];
    GPGStream *input = data;
    NSData *tempData = nil;
    
    @try {
        while ((tempData = [input readDataOfLength:kDataBufferSize]) && tempData.length > 0) {
			@autoreleasepool {
				// NSMutableData is required to prevent an uncatchable exception in -writeData:
				tempData = [NSMutableData dataWithData:tempData];
				
				[ofh writeData:tempData];
			}
        }
        
        if(close) {
            [ofh closeFile];
        }
    }
    @catch (NSException *exception) {
        // If the task is no longer running, there's no need to throw this exception
        // since it's expected.
        if(!self.completed)
            @throw exception;
        return;
    }
}


- (NSData *)readStatusFile:(NSString *)statusFile {
	NSData *nl = @"\n".UTF8Data;
	NSData *space = @" ".UTF8Data;
	NSData *statusPrefix = GPG_STATUS_PREFIX.UTF8Data;
	NSUInteger statusPrefixLength = statusPrefix.length;
	
	NSMutableData *statusData = [NSMutableData data];
	NSMutableData *currentData = [NSMutableData data];
	
	NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:statusFile];

	
	NSData *readData = nil;
	while ((readData = fileHandle.availableData) && readData.length) {
		[currentData appendData:readData];
		
		NSUInteger currentDataLength = currentData.length;
		
		NSRange searchRange;
		searchRange.location = 0;
		searchRange.length = currentDataLength;
		
		NSUInteger nextLineStart = 0;
		NSRange lineRange;
		NSRange nlRange;
		
		// Process the status output line by line.
		while ((nlRange = [currentData rangeOfData:nl options:0 range:searchRange]).length > 0) {

			// Find th erange of the current line.
			lineRange.location = nextLineStart;
			lineRange.length = nlRange.location - lineRange.location + 1;
			nextLineStart = nlRange.location + 1;
			
			// Get the data of the current line.
			NSData *lineData = [currentData subdataWithRange:lineRange];
			
			
			if ([lineData rangeOfData:statusPrefix options:NSDataSearchAnchored range:NSMakeRange(0, lineData.length)].length > 0) {
				// Line is a status line. Line starts with "[GNUPG:] ".

				[statusData appendData:lineData];
				
				NSRange statusRange = NSMakeRange(statusPrefixLength, lineData.length - statusPrefixLength - 1);
				NSRange spaceRange = [lineData rangeOfData:space options:0 range:statusRange];
				
				// Split line in keyword and value.
				NSString *keyword, *value = @"";
				if (spaceRange.length == 0) {
					keyword = [lineData subdataWithRange:statusRange].gpgString;
				} else {
					keyword = [lineData subdataWithRange:NSMakeRange(statusRange.location, spaceRange.location - statusRange.location)].gpgString;
					value = [lineData subdataWithRange:NSMakeRange(spaceRange.location + 1, statusRange.location + statusRange.length - spaceRange.location - 1)].gpgString;
				}
				
				[self processStatusWithKeyword:keyword value:value];
			} else {
				// This should not happen. But it is not a real problem.
			}
			
			searchRange.location = nextLineStart;
			searchRange.length = currentDataLength - searchRange.location;
		}
		
		NSRange rangeToRemove = NSMakeRange(0, searchRange.location);
		[currentData replaceBytesInRange:rangeToRemove withBytes:"" length:0];
	}
	
	return [[statusData copy] autorelease];
}



- (void)processStatusWithKeyword:(NSString *)keyword value:(NSString *)value {
    NSInteger code = [[[[self class] statusCodes] objectForKey:keyword] integerValue];
    if(!code)
        return;
    
	

    // Most keywords are handled by the processStatus callback,
    // but some like pinentry passphrase requests are handled
    // directly.
	NSData *response = self.processStatus(keyword, value);
    
    switch(code) {
        case GPG_STATUS_USERID_HINT: {
            NSRange range = [value rangeOfString:@" "];
            NSString *keyID = [value substringToIndex:range.location];
            NSString *userID = [value substringFromIndex:range.location + 1];
            self.userIDHint = [NSDictionary dictionaryWithObjectsAndKeys:keyID, @"keyID", userID, @"userID", nil];
            break;
        }
        case GPG_STATUS_NEED_PASSPHRASE: {
            NSArray *components = [value componentsSeparatedByString:@" "];
            self.needPassphraseInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                       [components objectAtIndex:0], @"mainKeyID", 
                                       [components objectAtIndex:1], @"keyID", 
                                       [components objectAtIndex:2], @"keyType", 
                                       [components objectAtIndex:3], @"keyLength", nil];
            break;
        }
        case GPG_STATUS_GOOD_PASSPHRASE:
        case GPG_STATUS_BAD_PASSPHRASE:
        case GPG_STATUS_MISSING_PASSPHRASE: {    
            self.userIDHint = nil;
            self.needPassphraseInfo = nil;
			if(code == GPG_STATUS_MISSING_PASSPHRASE)
				_pinentryCancelled = YES;
            break;
        }
        case GPG_STATUS_GET_LINE:
        case GPG_STATUS_GET_BOOL:
        case GPG_STATUS_GET_HIDDEN:
            if([value isEqualToString:@"passphrase.enter"])
                [self getPassphraseAndForward];
            else {
                if(response)
                    [self respond:response];
                else {
                    NSPipe *cmdPipe = self.task.standardInput;
                    if (cmdPipe) {
                        [[cmdPipe fileHandleForWriting] closeFile];
                    }
                }
            }
            break;
            
        case GPG_STATUS_BEGIN_ENCRYPTION:
        case GPG_STATUS_BEGIN_SIGNING:
            [self writeInputData];
            break;
            
        case GPG_STATUS_PROGRESS: {
            if (!_totalInData)
                break;
            
            NSArray *parts = [value componentsSeparatedByString:@" "];
            NSString *what = [parts objectAtIndex:0];
            NSString *length = [parts objectAtIndex:2];
            
            if ([what hasPrefix:@"/dev/fd/"]) {
				_processedBytes -= [[_processedBytesMap objectForKey:what] integerValue];
			}
            [_processedBytesMap setObject:length forKey:what];
            
            _processedBytes += [length integerValue];
            
            if(self.progressHandler) {
                self.progressHandler(_processedBytes, _totalInData);
            }
            
            break;
        }
    }
}

- (void)getPassphraseAndForward {
    NSString *passphrase = nil;
    @try {
        passphrase = [self passphraseForKeyID:[self.needPassphraseInfo objectForKey:@"keyID"] 
                                    mainKeyID:[self.needPassphraseInfo objectForKey:@"mainKeyID"] 
                                       userID:[self.userIDHint objectForKey:@"userID"]];
        
    }
    @catch (NSException *exception) {
        [self cancel];
        @throw exception;
    }
    @finally {
        self.userIDHint = nil;
        self.needPassphraseInfo = nil;
    }
    
    [self respond:passphrase];
}

- (void)respond:(id)response {
    // Try to write to the command pipe.
	// Ignore call, if response is empty data.
	if([response length] == 0)
		return;
	NSPipe *cmdPipe = nil;
    
    NSData *NL = [@"\n" dataUsingEncoding:NSASCIIStringEncoding];
    
    NSMutableData *responseData = [[NSMutableData alloc] init];
    [responseData appendData:[response isKindOfClass:[NSData class]] ? response : [[response description] dataUsingEncoding:NSUTF8StringEncoding]];
    if([responseData rangeOfData:NL options:NSDataSearchBackwards range:NSMakeRange(0, [responseData length])].location == NSNotFound)
        [responseData appendData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];
    GPGStream *responseStream = [GPGMemoryStream memoryStream];

    @try {
        cmdPipe = self.task.standardInput;
    }
    @catch (NSException *exception) {
    }

    if(self.completed) {
        [responseData release];
        return;
    }

    if(!cmdPipe) {
        [responseData release];
        return;
    }

    [responseStream writeData:responseData];
    [self writeData:responseStream pipe:cmdPipe close:NO];
	[responseData release];
}

- (NSString *)passphraseForKeyID:(NSString *)keyID mainKeyID:(NSString *)mainKeyID userID:(NSString *)userID {
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = [[GPGOptions sharedOptions] pinentryPath];
    
	if(!task.launchPath)
		@throw [GPGException exceptionWithReason:@"Pinentry not found!" errorCode:GPGErrorNoPINEntry];
	task.standardInput = [[NSPipe pipe] noSIGPIPE];
    task.standardOutput = [[NSPipe pipe] noSIGPIPE];
    
    NSString *description = nil;
    if([keyID isEqualToString:mainKeyID])
        description = [NSString stringWithFormat:localizedLibmacgpgString(@"GetPassphraseDescription"), userID, [keyID shortKeyID]];
    else
        description = [NSString stringWithFormat:localizedLibmacgpgString(@"GetPassphraseDescription_Subkey"), 
					   userID, [keyID shortKeyID], [mainKeyID keyID]];
    
    description = [description stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *prompt = [localizedLibmacgpgString(@"PassphraseLabel") stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    NSData *command = [[NSString stringWithFormat:
                        @"OPTION grab\n"
                        "OPTION cache-id=%@\n"
                        "SETDESC %@\n"
                        "SETPROMPT %@\n"
                        "GETPIN\n"
                        "BYE\n",
                        keyID, description, prompt] dataUsingEncoding:NSUTF8StringEncoding];
    
    [[task.standardInput fileHandleForWriting] writeData:command];
    
    [task launch];
    
    NSData *output = [[task.standardOutput fileHandleForReading] readDataToEndOfFile];
    
    [task threadSafeWaitUntilExit];
    
    [task release];
    
    if(!output)
        @throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Pinentry error!") errorCode:GPGErrorPINEntryError];
    
    NSString *outString = [output gpgString];
    
    // Versions prior to 0.8 of pinentry-mac do not seem
    // to support the OPTION cache-id yet, but still the
    // password is successfully retrieved.
    // To not abort on such an error, first the output string
    // is checked for a non empty D line and if not found,
    // any errors are processed.
    NSRange range = [outString rangeOfString:@"\nD "];
	if(range.location != NSNotFound) {
        range.location++;
        range.length--;
        range = [outString lineRangeForRange:range];
        range.location += 2;
        range.length -= 3;
        
        if(range.length > 0) {
            return [[outString substringWithRange:range] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        }
    }
    // Otherwise process the error.
    
	range = [outString rangeOfString:@"\nERR "];
	if (range.length > 0) {
		range.location++; 
		range.length--;
		range = [outString lineRangeForRange:range];
		range.location += 4;
		range.length -= 5;
		NSRange spaceRange = [outString rangeOfString:@" " options:NSLiteralSearch range:range];
		if (spaceRange.length > 0) {
			range.length = spaceRange.location - range.location;
		}
		if ([[outString substringWithRange:range] integerValue] == 0x5000063) {
			@throw [GPGException exceptionWithReason:@"User cancelled pinentry request" errorCode:GPGErrorCancelled];
		} else {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Pinentry error!") errorCode:GPGErrorPINEntryError];
		}
		return nil;
	}
    return nil;
}

- (void)cancel {
	if (_cancelled) {
        return;
	}

	// Close all pipes, otherwise SIGTERM is ignored it seems.
	[[_task.standardInput fileHandleForReading] closeFile];
	[[_task.standardInput fileHandleForWriting] closeFile];
	[[_task.standardOutput fileHandleForReading] closeFile];
	[[_task.standardOutput fileHandleForWriting] closeFile];
	[[_task.standardError fileHandleForReading] closeFile];
	[[_task.standardError fileHandleForWriting] closeFile];
	[_task terminate];

    _cancelled = YES;
}

- (NSDictionary *)copyResult {
    NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
	if(self.status)
		[result setObject:self.status forKey:@"status"];
	if(self.errors)
		[result setObject:self.errors forKey:@"errors"];
	if(self.attributes)
		[result setObject:self.attributes forKey:@"attributes"];
	if(self.output)
		[result setObject:[self.output readAllData] forKey:@"output"];
	[result setObject:[NSNumber numberWithUnsignedInteger:self.exitStatus] forKey:@"exitcode"];
    
    return result;
}

+ (NSDictionary *)statusCodes {
    static NSDictionary *GPG_STATUS_CODES = nil;
    static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		GPG_STATUS_CODES =
		@{
		  @"ALREADY_SIGNED": @(GPG_STATUS_ALREADY_SIGNED),
		  @"ATTRIBUTE": @(GPG_STATUS_ATTRIBUTE),
		  @"BACKUP_KEY_CREATED": @(GPG_STATUS_BACKUP_KEY_CREATED),
		  @"BADARMOR": @(GPG_STATUS_BADARMOR),
		  @"BADMDC": @(GPG_STATUS_BADMDC),
		  @"BADSIG": @(GPG_STATUS_BADSIG),
		  @"BAD_PASSPHRASE": @(GPG_STATUS_BAD_PASSPHRASE),
		  @"BEGIN_DECRYPTION": @(GPG_STATUS_BEGIN_DECRYPTION),
		  @"BEGIN_ENCRYPTION": @(GPG_STATUS_BEGIN_ENCRYPTION),
		  @"BEGIN_SIGNING": @(GPG_STATUS_BEGIN_SIGNING),
		  @"BEGIN_STREAM": @(GPG_STATUS_BEGIN_STREAM),
		  @"CARDCTRL": @(GPG_STATUS_CARDCTRL),
		  @"DECRYPTION_FAILED": @(GPG_STATUS_DECRYPTION_FAILED),
		  @"DECRYPTION_INFO": @(GPG_STATUS_DECRYPTION_INFO),
		  @"DECRYPTION_OKAY": @(GPG_STATUS_DECRYPTION_OKAY),
		  @"DELETE_PROBLEM": @(GPG_STATUS_DELETE_PROBLEM),
		  @"ENC_TO": @(GPG_STATUS_ENC_TO),
		  @"END_DECRYPTION": @(GPG_STATUS_END_DECRYPTION),
		  @"END_ENCRYPTION": @(GPG_STATUS_END_ENCRYPTION),
		  @"END_STREAM": @(GPG_STATUS_END_STREAM),
		  @"ERRMDC": @(GPG_STATUS_ERRMDC),
		  @"ERROR": @(GPG_STATUS_ERROR),
		  @"ERRSIG": @(GPG_STATUS_ERRSIG),
		  @"EXPKEYSIG": @(GPG_STATUS_EXPKEYSIG),
		  @"EXPSIG": @(GPG_STATUS_EXPSIG),
		  @"FILE_DONE": @(GPG_STATUS_FILE_DONE),
		  @"GET_BOOL": @(GPG_STATUS_GET_BOOL),
		  @"GET_HIDDEN": @(GPG_STATUS_GET_HIDDEN),
		  @"GET_LINE": @(GPG_STATUS_GET_LINE),
		  @"GOODMDC": @(GPG_STATUS_GOODMDC),
		  @"GOODSIG": @(GPG_STATUS_GOODSIG),
		  @"GOOD_PASSPHRASE": @(GPG_STATUS_GOOD_PASSPHRASE),
		  @"GOT_IT": @(GPG_STATUS_GOT_IT),
		  @"IMPORTED": @(GPG_STATUS_IMPORTED),
		  @"IMPORT_CHECK": @(GPG_STATUS_IMPORT_CHECK),
		  @"IMPORT_OK": @(GPG_STATUS_IMPORT_OK),
		  @"IMPORT_PROBLEM": @(GPG_STATUS_IMPORT_PROBLEM),
		  @"IMPORT_RES": @(GPG_STATUS_IMPORT_RES),
		  @"INV_RECP": @(GPG_STATUS_INV_RECP),
		  @"INV_SGNR": @(GPG_STATUS_INV_SGNR),
		  @"KEYEXPIRED": @(GPG_STATUS_KEYEXPIRED),
		  @"KEYREVOKED": @(GPG_STATUS_KEYREVOKED),
		  @"KEY_CONSIDERED": @(GPG_STATUS_KEY_CONSIDERED),
		  @"KEY_CREATED": @(GPG_STATUS_KEY_CREATED),
		  @"KEY_NOT_CREATED": @(GPG_STATUS_KEY_NOT_CREATED),
		  @"MISSING_PASSPHRASE": @(GPG_STATUS_MISSING_PASSPHRASE),
		  @"NEED_PASSPHRASE": @(GPG_STATUS_NEED_PASSPHRASE),
		  @"NEED_PASSPHRASE_PIN": @(GPG_STATUS_NEED_PASSPHRASE_PIN),
		  @"NEED_PASSPHRASE_SYM": @(GPG_STATUS_NEED_PASSPHRASE_SYM),
		  @"NEWSIG": @(GPG_STATUS_NEWSIG),
		  @"NODATA": @(GPG_STATUS_NODATA),
		  @"NOTATION_DATA": @(GPG_STATUS_NOTATION_DATA),
		  @"NOTATION_NAME": @(GPG_STATUS_NOTATION_NAME),
		  @"NO_PUBKEY": @(GPG_STATUS_NO_PUBKEY),
		  @"NO_RECP": @(GPG_STATUS_NO_RECP),
		  @"NO_SECKEY": @(GPG_STATUS_NO_SECKEY),
		  @"NO_SGNR": @(GPG_STATUS_NO_SGNR),
		  @"PKA_TRUST_BAD": @(GPG_STATUS_PKA_TRUST_BAD),
		  @"PKA_TRUST_GOOD": @(GPG_STATUS_PKA_TRUST_GOOD),
		  @"PLAINTEXT": @(GPG_STATUS_PLAINTEXT),
		  @"PLAINTEXT_LENGTH": @(GPG_STATUS_PLAINTEXT_LENGTH),
		  @"POLICY_URL": @(GPG_STATUS_POLICY_URL),
		  @"PROGRESS": @(GPG_STATUS_PROGRESS),
		  @"REVKEYSIG": @(GPG_STATUS_REVKEYSIG),
		  @"RSA_OR_IDEA": @(GPG_STATUS_RSA_OR_IDEA),
		  @"SC_OP_FAILURE": @(GPG_STATUS_SC_OP_FAILURE),
		  @"SC_OP_SUCCESS": @(GPG_STATUS_SC_OP_SUCCESS),
		  @"SESSION_KEY": @(GPG_STATUS_SESSION_KEY),
		  @"SHM_GET": @(GPG_STATUS_SHM_GET),
		  @"SHM_GET_BOOL": @(GPG_STATUS_SHM_GET_BOOL),
		  @"SHM_GET_HIDDEN": @(GPG_STATUS_SHM_GET_HIDDEN),
		  @"SHM_INFO": @(GPG_STATUS_SHM_INFO),
		  @"SIGEXPIRED": @(GPG_STATUS_SIGEXPIRED),
		  @"SIG_CREATED": @(GPG_STATUS_SIG_CREATED),
		  @"SIG_ID": @(GPG_STATUS_SIG_ID),
		  @"SIG_SUBPACKET": @(GPG_STATUS_SIG_SUBPACKET),
		  @"TRUNCATED": @(GPG_STATUS_TRUNCATED),
		  @"TRUST_FULLY": @(GPG_STATUS_TRUST_FULLY),
		  @"TRUST_MARGINAL": @(GPG_STATUS_TRUST_MARGINAL),
		  @"TRUST_NEVER": @(GPG_STATUS_TRUST_NEVER),
		  @"TRUST_ULTIMATE": @(GPG_STATUS_TRUST_ULTIMATE),
		  @"TRUST_UNDEFINED": @(GPG_STATUS_TRUST_UNDEFINED),
		  @"UNEXPECTED": @(GPG_STATUS_UNEXPECTED),
		  @"USERID_HINT": @(GPG_STATUS_USERID_HINT),
		  @"VALIDSIG": @(GPG_STATUS_VALIDSIG),
		  @"WARNING": @(GPG_STATUS_WARNING),
		  @"VALIDSIG": @(GPG_STATUS_SUCCESS),
		  @"FAILURE": @(GPG_STATUS_FAILURE)
		  };
		[GPG_STATUS_CODES retain];
	});
	return GPG_STATUS_CODES;
}

+ (BOOL)isGPGAgentSocket:(NSString *)socketPath {
	socketPath = [socketPath stringByResolvingSymlinksInPath];
	NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:socketPath error:nil];
	if ([[attributes fileType] isEqualToString:NSFileTypeSocket]) {
		return YES;
	}
	return NO;
}

+ (NSString *)gpgAgentSocket {
	NSString *socketPath = [[[GPGOptions sharedOptions] gpgHome] stringByAppendingPathComponent:@"S.gpg-agent"];
	if ([self isGPGAgentSocket:socketPath]) {
		return socketPath;
	}
	socketPath = [NSString stringWithFormat:@"/tmp/gpg-agent/%@/S.gpg-agent", NSUserName()];
	if ([self isGPGAgentSocket:socketPath]) {
		return socketPath;
	}
	return nil;
}

+ (BOOL)isPassphraseInGPGAgentCache:(id)key {
	if(![key respondsToSelector:@selector(description)])
		return NO;
	
	NSString *socketPath = [GPGTaskHelper gpgAgentSocket];
	// No socket path available? Can't query the cache, so bail.
	if(!socketPath) {
		GPGDebugLog(@"No gpg-agent socket path available!");
		return NO;
	}

	__block int sock = -1;
	if ((sock = socket(AF_UNIX, SOCK_STREAM, 0)) == -1) {
		perror("+[GPGTaskHelper isPassphraseInGPGAgentCache:] failed to initiate socket");
		return NO;
	}

	BOOL (^cleanup)(BOOL) = ^(BOOL inCache){
		if(sock != -1)
			close(sock);
		return inCache;
	};

	const char *socketPathName = [socketPath UTF8String];
	unsigned long socketPathLength = [socketPath lengthOfBytesUsingEncoding:NSUTF8StringEncoding];

	struct sockaddr_un server;
	bzero((char *)&server, sizeof(struct sockaddr_un));
	server.sun_family = AF_UNIX;
	strncpy(server.sun_path, socketPathName, socketPathLength);
	// On BSD systems, sun_path is not to be expected to be terminated with a null byte.
	if (connect(sock, (struct sockaddr *)&server, sizeof(struct sockaddr_un)) < 0) {
		perror("+[GPGTaskHelper isPassphraseInGPGAgentCache:] failed to connect to gpg-agent socket");
		return cleanup(NO);
	}

	struct timeval socketTimeout;
	socketTimeout.tv_usec = 0;
	socketTimeout.tv_sec = 2;
	if(setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &socketTimeout, sizeof(socketTimeout)) < 0) {
		perror("+[GPGTaskHelper isPassphraseInGPGAgentCache:] failed to configure socket timeout");
		return cleanup(NO);
	}

	char buffer[100];
	bzero(&buffer, sizeof(buffer));
	// Check if server is responding by receiving the message OK, otherwise bail.
	if(recv(sock, buffer, 100, 0) <= 2) {
		GPGDebugLog(@"Failed to receive OK from gpg-agent.");
		return cleanup(NO);
	}
	if (strncmp(buffer, "OK", 2)) {
		GPGDebugLog(@"No OK from gpg-agent.");
		return cleanup(NO);
	}

	NSString *command = [NSString stringWithFormat:@"GET_PASSPHRASE --no-ask %@ . . .\n", key];
	// Request the passphrase connected to the key.
	send(sock, [command UTF8String], [command lengthOfBytesUsingEncoding:NSUTF8StringEncoding], 0);

	size_t pos = 0;
	ssize_t length = 0;
	bzero(&buffer, sizeof(buffer));
	BOOL inCache = NO;

	while ((length = recv(sock, buffer+pos, 100-pos, 0)) > 0) {
		pos += length;
		// Yes, we have the passphrase in cache!
		if(strnstr(buffer, "OK", pos)) {
			inCache = YES;
			break;
		}
		
		// gpg-agent is saying that we don't have the passphrase in cache!
		if(strnstr(buffer, "ERR", pos)) {
			inCache = NO;
			break;
		}
	}

	return cleanup(inCache);
}

- (void)dealloc {
    [_inData release];
    [_arguments release];
	[_output release];
    [_status release];
    [_errors release];
    [_attributes release];
    [_task release];
	_task = nil;
	[_processStatus release];
    [_userIDHint release];
    [_needPassphraseInfo release];
    [_progressHandler release];
    [_processedBytesMap release];
	[_environmentVariables release];
	
#if defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1080
    [_sandboxHelper release];
#endif
	
	[super dealloc];
}

+ (BOOL)launchGeneralTask:(NSString *)path withArguments:(NSArray *)arguments wait:(BOOL)wait {
	if ([GPGTask sandboxed]) {
		GPGTaskHelperXPC *xpcTask = [[GPGTaskHelperXPC alloc] init];
		
		BOOL succeeded = NO;
		@try {
			succeeded = [xpcTask launchGeneralTask:path withArguments:arguments wait:wait];
		}
		@catch (NSException *exception) {
			return NO;
		}
		@finally {
			[xpcTask release];
		}
		
		return succeeded;
	} else {
		NSTask *task = [NSTask launchedTaskWithLaunchPath:path arguments:arguments];
		if (wait) {
			[task threadSafeWaitUntilExit];
			return task.terminationStatus == 0;
		}
	}
	return YES;
}

+ (BOOL)showGPGSuitePreferencesWithArguments:(NSDictionary *)arguments {	
	if ([GPGTask sandboxed]) {
		// Use the xpc.
		
		GPGTaskHelperXPC *xpcTask = [[GPGTaskHelperXPC alloc] init];
		
		BOOL succeeded = NO;
		@try {
			succeeded = [xpcTask showGPGSuitePreferencesWithArguments:arguments];
		} @catch (NSException *exception) {
			return NO;
		} @finally {
			[xpcTask release];
		}
		
		return succeeded;
	} else {
		// Locate GPGPreferences.prefPane
		NSString *panePath = @"/Library/PreferencePanes/GPGPreferences.prefPane";
		if (![[NSFileManager defaultManager] fileExistsAtPath:panePath]) {
			// Look in the user library.
			panePath = [NSHomeDirectory() stringByAppendingPathComponent:panePath];
			if (![[NSFileManager defaultManager] fileExistsAtPath:panePath]) {
				// GPGPreferences.prefPane seems not to be installed.
				return NO;
			}
		}
		
		if (arguments.count > 0) {
			if (![self writeGPGSuitePreferencesArguments:arguments]) {
				return NO;
			}
		}
		
		NSURL *appURL = [[NSWorkspace sharedWorkspace] URLForApplicationWithBundleIdentifier:@"com.apple.systempreferences"];
		NSURL *paneURL = [NSURL fileURLWithPath:panePath];
		
		// Open GPGPreferences.prefPane with System Preferences.app
		NSRunningApplication *application = [[NSWorkspace sharedWorkspace] openURLs:@[paneURL] withApplicationAtURL:appURL options:0 configuration:@{} error:nil];
		if (!application) {
			return NO;
		}
		
		if (arguments.count > 0) {
			// Send the arguments to GPG Suite Preferences.
			[[NSDistributedNotificationCenter defaultCenter] postNotificationName:GPGPreferencesShowTabNotification object:nil userInfo:arguments deliverImmediately:YES];
		}
	}
	return YES;
}
+ (NSString *)gpgSuitePreferencesArgumentsFilePath {
	return [NSString stringWithFormat:@"/private/tmp/GPGPreferences.%@/arguments", NSUserName()];
}
+ (BOOL)writeGPGSuitePreferencesArguments:(NSDictionary *)arguments {
	// Write the arguments for GPG Suite Preferences into a temp file with a known path.
	NSString *path = [self gpgSuitePreferencesArgumentsFilePath];
	NSString *directory = [path stringByDeletingLastPathComponent];
	[[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:NO attributes:nil error:nil];
	
	return [arguments writeToFile:path atomically:YES];
}
+ (NSDictionary *)readGPGSuitePreferencesArguments {
	// Read the arguments for GPG Suite Preferences from a temp file with a known path and remove the file afterwards.
	NSDictionary *arguments = nil;
	
	NSString *path = [self gpgSuitePreferencesArgumentsFilePath];
	NSString *directory = [path stringByDeletingLastPathComponent];
	if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
		arguments = [NSDictionary dictionaryWithContentsOfFile:path];
		[[NSFileManager defaultManager] removeItemAtPath:directory error:nil];
	}

	return arguments;
}




@end

@implementation NSTask (GPGThreadSafeWait)
- (void)threadSafeWaitUntilExit {
	dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
	self.terminationHandler = ^(NSTask *task) {
		dispatch_semaphore_signal(semaphore);
	};
	dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
}
@end


