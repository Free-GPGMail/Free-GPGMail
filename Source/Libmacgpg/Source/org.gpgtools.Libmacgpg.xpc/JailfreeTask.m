//
//  GPGXPCTask.m
//  Libmacgpg
//
//  Created by Lukas Pitschl on 28.09.12.
//
//

#import "JailfreeTask.h"
#import "GPGMemoryStream.h"
#import "GPGWatcher.h"
#import "GPGException.h"
#import "GPGTaskHelper.h"
#import <xpc/xpc.h>

@interface JailfreeTask ()
- (BOOL)isCodeSignatureValidAtPath:(NSString *)path;
@end

@implementation JailfreeTask

@synthesize xpcConnection = _xpcConnection;

- (void)testConnection:(void (^)(BOOL))reply {
	reply(YES);
}

- (void)launchGPGWithArguments:(NSArray *)arguments data:(NSData *)data readAttributes:(BOOL)readAttributes closeInput:(BOOL)closeInput reply:(void (^)(NSDictionary *))reply {
    
	GPGTaskHelper *task = [[GPGTaskHelper alloc] initWithArguments:arguments];
    
	dispatch_group_t taskAndStatusGroup = dispatch_group_create();
	
    // Setup the task.
	GPGMemoryStream *outputStream = [[GPGMemoryStream alloc] init];
    task.output = outputStream;
	
	
	GPGMemoryStream *inputStream = [GPGMemoryStream memoryStreamForReading:data];

    task.inData = inputStream;
	task.closeInput = closeInput;
	id <Jail> remoteProxy = [_xpcConnection remoteObjectProxy];
    typeof(task) __weak weakTask = task;
    
	task.processStatus = (lp_process_status_t)^(NSString *keyword, NSString *value) {
        dispatch_group_enter(taskAndStatusGroup);
        [remoteProxy processStatusWithKey:keyword value:value reply:^(NSData *response) {
            GPGTaskHelper *strongTask = weakTask;
            // Since not every process status requires an answer, but currently our protocol does,
            // it's possible that the gpg process has already completed when responses are still coming in.
            if(response && !strongTask.completed) {
				@try {
					[strongTask respond:response];
				}
				@catch (NSException *exception) {}
			}
			dispatch_group_leave(taskAndStatusGroup);
		}];
		return [NSData data];
    };
    
	task.progressHandler = ^(NSUInteger processedBytes, NSUInteger totalBytes) {
        [remoteProxy progress:processedBytes total:totalBytes];
    };
    
	task.readAttributes = readAttributes;
    task.checkForSandbox = NO;
    
    xpc_transaction_begin();
		
	__block NSException *taskError = nil;
	dispatch_group_async(taskAndStatusGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		// Start the task.
		@try {
			[task run];
		}
		@catch (NSException *exception) {
			taskError = exception;
		}
	});
	dispatch_group_notify(taskAndStatusGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		// Once the task is completed, check for errors and create an error response if necessary,
		// otherwise copy the task results into the response and send it back.
		NSDictionary *result = nil;
		if(taskError) {
			NSMutableDictionary *exceptionInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:taskError.name, @"name",
												  taskError.reason, @"reason", nil];
			if([taskError isKindOfClass:[GPGException class]])
				[exceptionInfo setObject:[NSNumber numberWithUnsignedInt:((GPGException *)taskError).errorCode] forKey:@"errorCode"];
			
			result = [NSDictionary dictionaryWithObjectsAndKeys:exceptionInfo, @"exception", nil];
		}
		else {
			result = [task copyResult];
		}
		
		reply(result);
		
		xpc_transaction_end();
	});
}

- (void)launchGeneralTask:(NSString *)path withArguments:(NSArray *)arguments wait:(BOOL)wait reply:(void (^)(BOOL))reply {
	if ([self isCodeSignatureValidAtPath:path]) {
		NSTask *task = [NSTask launchedTaskWithLaunchPath:path arguments:arguments];
		if (wait) {
			[task threadSafeWaitUntilExit];
			reply(task.terminationStatus == 0);
		} else {
			reply(YES);
		}
	} else {
		NSLog(@"No valid signature at path: %@", path);
		reply(NO);
	}
}

- (void)startGPGWatcher {
    [GPGWatcher activateWithXPCConnection:self.xpcConnection];
}

- (void)loadConfigFileAtPath:(NSString *)path reply:(void (^)(NSString *))reply {
	NSArray *allowedConfigs = @[@"gpg.conf", @"gpg-agent.conf", @"dirmngr.conf"];
	
	if(![allowedConfigs containsObject:[path lastPathComponent]])
		reply(nil);
	
	NSError * __autoreleasing error = nil;
 	NSString *configFile = [[NSString alloc] initWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
	if(!configFile) {
		reply(nil);
	}
	
	reply(configFile);
}

- (void)loadUserDefaultsForName:(NSString *)domainName reply:(void (^)(NSDictionary *))reply {
	NSDictionary *defaults = [[NSUserDefaults standardUserDefaults] persistentDomainForName:domainName];
	
	reply(defaults);
}

- (void)setUserDefaults:(NSDictionary *)domain forName:(NSString *)domainName reply:(void (^)(BOOL))reply {
	[[NSUserDefaults standardUserDefaults] setPersistentDomain:domain forName:domainName];
	
	reply(YES);
}

- (void)isPassphraseForKeyInGPGAgentCache:(NSString *)key reply:(void (^)(BOOL))reply {
	reply([GPGTaskHelper isPassphraseInGPGAgentCache:key]);
}

- (void)showGPGSuitePreferencesWithArguments:(NSDictionary *)arguments reply:(void (^)(BOOL result))reply {
	reply([GPGTaskHelper showGPGSuitePreferencesWithArguments:arguments]);
}

#pragma mark - General Helper Methods

// Helper methods

- (BOOL)isCodeSignatureValidAtPath:(NSString *)path  {
    OSStatus result;
    SecRequirementRef requirement = nil;
    SecStaticCodeRef staticCode = nil;
        
    result = SecStaticCodeCreateWithPath((__bridge CFURLRef)[NSURL fileURLWithPath:path], kSecCSDefaultFlags, &staticCode);
    if (result) {
        goto finally;
    }

    SecCSFlags validityFlags = kSecCSDefaultFlags | kSecCSCheckNestedCode | kSecCSCheckAllArchitectures | kSecCSEnforceRevocationChecks;
	result = SecRequirementCreateWithString(CFSTR("anchor apple generic and ( cert leaf = H\"C21964B138DE0094F42CEDE7078C6F800BA5838B\" or cert leaf = H\"233B4E43187B51BF7D6711053DD652DDF54B43BE\" or cert leaf = H\"E2C077C85EC4024699920B3C206364F742CEC790\" ) "), kSecCSDefaultFlags, &requirement);
	if (result) {
        goto finally;
    }

	result = SecStaticCodeCheckValidity(staticCode, validityFlags, requirement);
    
finally:
    if (staticCode) CFRelease(staticCode);
    if (requirement) CFRelease(requirement);
    return result == 0;
}






@end
