	#if defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1080

/* GPGTaskHelperXPC.m created by Lukas Pitschl (@lukele) on Mon 22-Apr-2014 */

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
 *     * Neither the name of GPGTools Team nor the names of Libmacgpg
 *       contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE GPGTools Team ``AS IS'' AND ANY
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

#import "Libmacgpg.h"
#import "GPGTaskHelper.h"
#import "GPGTaskHelperXPC.h"

@interface GPGTaskHelperXPC ()

@property (nonatomic) NSXPCConnection *connection;
@property (nonatomic) dispatch_semaphore_t taskLock;
@property (nonatomic) BOOL wasShutdown;
@property (nonatomic, retain, readwrite) NSException *connectionError;
@property (nonatomic, retain, readwrite) NSException *callError;
@property (nonatomic, retain, readwrite) NSException *taskError;
@property (nonatomic) BOOL success;

@end

@implementation GPGTaskHelperXPC

@synthesize connection=_connection, taskLock=_taskLock, progressHandler=_progressHandler, processStatus=_processStatus, wasShutdown=_wasShutdown, connectionError=_connectionError, callError=_callError, taskError=_taskError, success=_success;

#pragma mark - XPC connection helpers

- (id)init {
	self = [super init];
	if(self) {
		_connection = [[NSXPCConnection alloc] initWithMachServiceName:JAILFREE_XPC_NAME options:0];
		_connection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(Jailfree)];
		_connection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(Jail)];
		_connection.exportedObject = self;
		
		_success = false;

		// The invalidation handler is called when there's a problem establishing
		// the connection to the xpc service or it can't be found at all.
		__block GPGTaskHelperXPC *weakSelf = self;
		_connection.invalidationHandler = ^{
			// Signal any outstanding tasks that they are done.
			// This handler is always called, when the connection is shutdown,
			// but more importantly also, when no connection could be established,
			// so catch that!
			if(weakSelf.wasShutdown)
				return;
			
			weakSelf.connectionError = [GPGException exceptionWithReason:@"[Libmacgpg] Failed to establish connection to org.gpgtools.Libmacgpg.xpc" errorCode:GPGErrorXPCConnectionError];
			
			[weakSelf completeTaskWithFailure];
		};
		
		_taskLock = dispatch_semaphore_create(0);
		
		// Setup the remote object with error handler.
		_connectionError = nil;
		_callError = nil;
		
		// The error handler is invoked in the following cases:
		// - The xpc service crashes due to some error (for example overrelease.)
		// - If the xpc service is killed (process killed, also with -9)
		// - If the xpc service is unloaded with launchctl unload.
		// - If the xpc service is removed with launchctl remove.
		_jailfree = [_connection remoteObjectProxyWithErrorHandler:^(NSError *error) {
			// The connection has been invalidated by ourselves.
			// No need to log anything.
			if(weakSelf.wasShutdown)
				return;
			
			weakSelf.callError = [GPGException exceptionWithReason:@"[Libmacgpg] Failed to invoke XPC method" errorCode:GPGErrorXPCConnectionInterruptedError];
			
			[weakSelf completeTaskWithFailure];
		}];
	}
	return self;
}

- (BOOL)healthyXPCBinaryExists {
#ifdef DEBUGGING
	// Developers should know what they're doing, so this can always return YES.
	// Simply properly load the xpc if it doesn't work.
	return YES;
#endif
	
	BOOL healthy = NO;
	NSString *xpcBinaryName = @"org.gpgtools.Libmacgpg.xpc";
	NSString *xpcBinaryPath = [@"/Library/Application Support/GPGTools" stringByAppendingPathComponent:xpcBinaryName];
	if([[NSFileManager defaultManager] isExecutableFileAtPath:xpcBinaryPath])
		healthy = YES;
	
	return healthy;
}

- (void)prepareTask {
	// Reset connection error.
	self.connectionError = nil;
	self.callError = nil;
	
	// NSXPCConnection is not checking if the binary for the xpc service actually
	// exists and hence doesn't invoke an error handler if it doesn't.
	// So we do the check for it, and throw an error if necessary.
	if(![self healthyXPCBinaryExists]) {
		self.connectionError = [GPGException exceptionWithReason:@"[Libmacgpg] The xpc service binary is not available. Please re-install." errorCode:GPGErrorXPCBinaryError];
		[self shutdownAndThrowError];
	}
	// Resume will trigger the invalidationHandler if the connection can't
	// be established, for example, if the xpc service is not registered.
	[_connection resume];
}

- (void)waitForTaskToCompleteAndShutdown:(BOOL)shutdown throwExceptionIfNecessary:(BOOL)throwException {
	// No timeout necessary unless there's a bug in libxpc.
	dispatch_semaphore_wait(_taskLock, DISPATCH_TIME_FOREVER);
	dispatch_release(_taskLock);
	_taskLock = nil;
	
	if(shutdown) {
		if(!_success && throwException)
			[self shutdownAndThrowError];
		else
			[self shutdown];
	}
}

- (void)shutdownAndThrowError {
	NSException *errorToThrow = nil;
	
	// Errors are thrown in the following order:
	// - taskError
	// - connectionError
	// - callError
	//
	// If connection error is set, call error is most likely also set, since both error
	// handlers are invoked by XPC Connection in case of a connection error.
	
	if(self.taskError)
		errorToThrow = [self.taskError copy];
	else if(self.connectionError)
		errorToThrow = [self.connectionError copy];
	else if(self.callError)
		errorToThrow = [self.callError copy];
	
	[self shutdown];
	
	@throw [errorToThrow autorelease];
}

- (void)completeTaskWithStatus:(BOOL)status {
	_success = status == true ? true : false;
	if(_taskLock != NULL)
		dispatch_semaphore_signal(_taskLock);
}

- (void)completeTaskWithSuccess {
	[self completeTaskWithStatus:true];
}

- (void)completeTaskWithFailure {
	[self completeTaskWithStatus:false];
}
#pragma mark XPC service methods

- (NSDictionary *)launchGPGWithArguments:(NSArray *)arguments data:(NSData *)data readAttributes:(BOOL)readAttributes closeInput:(BOOL)closeInput {
	[self prepareTask];
	
	NSException * __block taskError = nil;
	NSMutableDictionary *result = [[NSMutableDictionary alloc] initWithCapacity:0];
	
	[_jailfree launchGPGWithArguments:arguments data:data readAttributes:readAttributes closeInput:closeInput reply:^(NSDictionary *info) {
		// Received an error? Convert it to an NSException and out of here.
		if([info objectForKey:@"exception"]) {
			NSDictionary *exceptionInfo = [info objectForKey:@"exception"];
			NSException *exception = nil;
			if(![exceptionInfo objectForKey:@"errorCode"]) {
				exception = [NSException exceptionWithName:[exceptionInfo objectForKey:@"name"] reason:[exceptionInfo objectForKey:@"reason"] userInfo:nil];
			}
			else {
				exception = [GPGException exceptionWithReason:[exceptionInfo objectForKey:@"reason"] errorCode:[[exceptionInfo objectForKey:@"errorCode"] unsignedIntValue]];
			}
			
			taskError = [exception retain];
			[self completeTaskWithFailure];
			
			return;
		}
		
        // If there's a problem with the XPC service, it's possible that one of the required
        // dictionary elements is not set. In that case, throw a general error.
        if(![info objectForKey:@"status"] || ![info objectForKey:@"errors"] || ![info objectForKey:@"exitcode"] || ![info objectForKey:@"output"]) {
            taskError = [[GPGException exceptionWithReason:@"Erron in XPC response" errorCode:GPGErrorXPCConnectionError] retain];
            [self completeTaskWithFailure];

            return;
        }
        [result setObject:[info objectForKey:@"status"] forKey:@"status"];
		if([info objectForKey:@"attributes"])
			[result setObject:[info objectForKey:@"attributes"] forKey:@"attributes"];
        [result setObject:[info objectForKey:@"errors"] forKey:@"errors"];
		[result setObject:[info objectForKey:@"exitcode"] forKey:@"exitStatus"];
		[result setObject:[info objectForKey:@"output"] forKey:@"output"];
		
        [self completeTaskWithSuccess];
	}];
	
	[self waitForTaskToCompleteAndShutdown:NO throwExceptionIfNecessary:NO];
	
	if(!_success) {
		if(taskError)
			self.taskError = taskError;
		
		[result release];
		[self shutdownAndThrowError];
		return nil;
	}
	
	[self shutdown];
	
	return [result autorelease];
}

- (NSString *)loadConfigFileAtPath:(NSString *)path {
	[self prepareTask];
	
	NSMutableString *result = [[NSMutableString alloc] init];
	
	[_jailfree loadConfigFileAtPath:path reply:^(NSString *content) {
		if(content)
			[result appendString:content];
		
		[self completeTaskWithSuccess];
	}];
	
	[self waitForTaskToCompleteAndShutdown:NO throwExceptionIfNecessary:NO];
	
	if(!_success) {
		[result release];
		[self shutdownAndThrowError];
		return nil;
	}
	
	[self shutdown];
	
	return [result autorelease];
}

- (NSDictionary *)loadUserDefaultsForName:(NSString *)domainName {
	[self prepareTask];
	
	NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
	
	[_jailfree loadUserDefaultsForName:domainName reply:^(NSDictionary *defaults) {
		if(defaults)
			[result addEntriesFromDictionary:defaults];
			
		[self completeTaskWithSuccess];
	}];
	
	[self waitForTaskToCompleteAndShutdown:NO throwExceptionIfNecessary:NO];
	
	if(!_success) {
		[result release];
		[self shutdownAndThrowError];
		return nil;
	}
	
	[self shutdown];
	
	return [result autorelease];
}

- (void)setUserDefaults:(NSDictionary *)domain forName:(NSString *)domainName {
	[self prepareTask];

	__block BOOL success = NO;
	
	[_jailfree setUserDefaults:domain forName:domainName reply:^(BOOL result) {
		success = result;
		
		[self completeTaskWithSuccess];
	}];
	
	[self waitForTaskToCompleteAndShutdown:YES throwExceptionIfNecessary:YES];
}


- (BOOL)launchGeneralTask:(NSString *)path withArguments:(NSArray *)arguments wait:(BOOL)wait {
	[self prepareTask];
	
	__block BOOL success = NO;
	
	[_jailfree launchGeneralTask:path withArguments:arguments wait:wait reply:^(BOOL result) {
		success = result;
		
		[self completeTaskWithSuccess];
	}];
	
	[self waitForTaskToCompleteAndShutdown:YES throwExceptionIfNecessary:YES];
	
	return success;
}

- (BOOL)isPassphraseForKeyInGPGAgentCache:(NSString *)key {
	[self prepareTask];
	
	BOOL __block inCache = NO;
	
	[_jailfree isPassphraseForKeyInGPGAgentCache:key reply:^(BOOL result) {
		inCache = result;
		
		[self completeTaskWithSuccess];
	}];
	
	[self waitForTaskToCompleteAndShutdown:YES throwExceptionIfNecessary:YES];
		
	return inCache;
}

- (void)processStatusWithKey:(NSString *)keyword value:(NSString *)value reply:(void (^)(NSData *))reply {
	// If process status is not set, we still have to reply otherwise the request might hang forever.
	NSData *response = nil;
	if(self.processStatus)
		response = self.processStatus(keyword, value);
	
	// Response can't be nil otherwise the reply won't be send as it turns out.
	if(!response)
		response = [NSData data];
	
	reply(response);
}

- (void)progress:(NSUInteger)processedBytes total:(NSUInteger)total {
    if(self.progressHandler)
        self.progressHandler(processedBytes, total);
}

- (BOOL)showGPGSuitePreferencesWithArguments:(NSDictionary *)arguments {
	[self prepareTask];
	
	__block BOOL success = NO;
	
	[_jailfree showGPGSuitePreferencesWithArguments:arguments reply:^(BOOL result) {
		success = result;
		
		[self completeTaskWithSuccess];
	}];
	
	[self waitForTaskToCompleteAndShutdown:YES throwExceptionIfNecessary:NO];
	
	return success;
}



#pragma mark - XPC connection cleanup

- (void)shutdown {
	self.wasShutdown = YES;
	_success = false;
	
	[_taskError release];
	_taskError = nil;
	
	[_callError release];
	_callError = nil;
	
	[_connectionError release];
	_connectionError = nil;
	
	_jailfree = nil;
	
	_connection.invalidationHandler = nil;
	_connection.interruptionHandler = nil;
	[_connection invalidate];
	_connection.exportedObject = nil;
	[_connection release];
	_connection = nil;
	
	if(_taskLock)
		dispatch_release(_taskLock);
	_taskLock = nil;
		
	Block_release(_processStatus);
	_processStatus = nil;
	Block_release(_progressHandler);
	_progressHandler = nil;
}

- (void)dealloc {
	if(!self.wasShutdown)
		[self shutdown];
	
	[super dealloc];
}

@end

#endif
