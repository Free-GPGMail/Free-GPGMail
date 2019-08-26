/*
 Copyright © Roman Zechmeister, 2017
 
 Diese Datei ist Teil von Libmacgpg.
 
 Libmacgpg ist freie Software. Sie können es unter den Bedingungen 
 der GNU General Public License, wie von der Free Software Foundation 
 veröffentlicht, weitergeben und/oder modifizieren, entweder gemäß 
 Version 3 der Lizenz oder (nach Ihrer Option) jeder späteren Version.
 
 Die Veröffentlichung von Libmacgpg erfolgt in der Hoffnung, daß es Ihnen 
 von Nutzen sein wird, aber ohne irgendeine Garantie, sogar ohne die implizite 
 Garantie der Marktreife oder der Verwendbarkeit für einen bestimmten Zweck. 
 Details finden Sie in der GNU General Public License.
 
 Sie sollten ein Exemplar der GNU General Public License zusammen mit diesem 
 Programm erhalten haben. Falls nicht, siehe <http://www.gnu.org/licenses/>.
*/

#import "GPGController.h"
#import "GPGTask.h"
#import "GPGTaskHelper.h"
#import "GPGGlobals.h"
#import "GPGMemoryStream.h"
#import "GPGException.h"
#import "GPGGlobals.h"
//#import <sys/shm.h>
#import <fcntl.h>
#import "NSBundle+Sandbox.h"
#import "GPGStatusLine.h"
#import <sys/stat.h>
#import "GPGTask_Private.h"


NSString * const GPGStatusFilePlaceholder = @"~%$STATUS_FILE_PATH$%~";
NSString * const GPGAttributeFilePlaceholder = @"~%$ATTRIBUTE_FILE_PATH$%~";


@class GPGController;

@implementation GPGTask

char partCountForStatusCode[GPG_STATUS_COUNT];
static NSLock *gpgTaskLock;

@synthesize isRunning, batchMode, getAttributeData, delegate, userInfo, exitcode, errData, statusData, attributeData, cancelled,
            progressInfo, statusDict, taskHelper = taskHelper, timeout, environmentVariables=_environmentVariables, passphrase, nonBlocking;
@synthesize outStream, statusArray;



- (NSArray *)arguments {
	return [[arguments copy] autorelease];
}

- (NSData *)outData {
    return [outStream readAllData];
}

- (void)setInput:(GPGStream *)stream {
	[stream retain];
	if (inData) {
		[inData release];
	}
	inData = stream;
}
- (void)setInData:(NSData *)data {
    [self setInput:[GPGMemoryStream memoryStreamForReading:data]];
}
- (void)setInText:(NSString *)string {
	[self setInData:[string UTF8Data]];
}

- (NSString *)outText {
	if (!outText) {
        outText = [[[outStream readAllData] gpgString] retain];
	}
	return [[outText retain] autorelease];
}
- (NSString *)errText {
	if (!errText) {
		errText = [[errData gpgString] retain];
	}
	return [[errText retain] autorelease];
}
- (NSString *)statusText {
	if (!statusText) {
		statusText = [[statusData gpgString] retain];
	}
	return [[statusText retain] autorelease];
}


+ (void)initialize {
	gpgTaskLock = [NSLock new];

	//Status codes where the last part can contain withespaces.
	memset(partCountForStatusCode, 0, sizeof(partCountForStatusCode));
	partCountForStatusCode[GPG_STATUS_EXPKEYSIG] = 2;
	partCountForStatusCode[GPG_STATUS_EXPSIG] = 2;
	partCountForStatusCode[GPG_STATUS_GOODSIG] = 2;
	partCountForStatusCode[GPG_STATUS_IMPORTED] = 2;
	partCountForStatusCode[GPG_STATUS_IMPORT_CHECK] = 3;
	partCountForStatusCode[GPG_STATUS_INV_RECP] = 2;
	partCountForStatusCode[GPG_STATUS_INV_SGNR] = 2;
	partCountForStatusCode[GPG_STATUS_NOTATION_DATA] = 1;
	partCountForStatusCode[GPG_STATUS_NOTATION_NAME] = 1;
	partCountForStatusCode[GPG_STATUS_NO_RECP] = 1;
	partCountForStatusCode[GPG_STATUS_NO_SGNR] = 1;
	partCountForStatusCode[GPG_STATUS_PKA_TRUST_BAD] = 1;
	partCountForStatusCode[GPG_STATUS_PKA_TRUST_GOOD] = 1;
	partCountForStatusCode[GPG_STATUS_PLAINTEXT] = 3;
	partCountForStatusCode[GPG_STATUS_POLICY_URL] = 1;
	partCountForStatusCode[GPG_STATUS_REVKEYSIG] = 2;
	partCountForStatusCode[GPG_STATUS_USERID_HINT] = 2;
}

+ (NSString *)nameOfStatusCode:(NSInteger)statusCode {
	return [GPGTaskHelper.statusCodes allKeysForObject:@(statusCode)][0];
}


+ (id)gpgTaskWithArguments:(NSArray *)args batchMode:(BOOL)batch {
	return [[[self alloc] initWithArguments:args batchMode:batch] autorelease]; 
}
+ (id)gpgTaskWithArguments:(NSArray *)args {
	return [self gpgTaskWithArguments:args batchMode:NO]; 
}
+ (id)gpgTaskWithArgument:(NSString *)arg {
	return [self gpgTaskWithArguments:[NSArray arrayWithObject:arg] batchMode:NO]; 
}
+ (id)gpgTask {
	return [self gpgTaskWithArguments:nil batchMode:NO]; 
}




- (id)initWithArguments:(NSArray *)args batchMode:(BOOL)batch {
	self = [super init];
	if (self) {
		arguments = [[NSMutableArray alloc] initWithArray:args];
		batchMode = batch;
		errorCodes = [[NSMutableArray alloc] init];
		statusDict = [[NSMutableDictionary alloc] init];
		statusArray = [[NSMutableArray alloc] init];
	}
	return self;	
}
- (id)initWithArguments:(NSArray *)args {
	return [self initWithArguments:args batchMode:NO];
}
- (id)initWithArgument:(NSString *)arg {
	return [self initWithArguments:[NSArray arrayWithObject:arg] batchMode:NO];
}
- (id)init {
	return [self initWithArguments:nil batchMode:NO];
}



- (void)dealloc {
	[arguments release];
	self.userInfo = nil;
	
	[outStream release];
	[errData release];
	[statusData release];
	[attributeData release];
	[outText release];
	[errText release];
	[statusText release];
	[inData release];
    [errorCodes release];
	[statusDict release];
	[statusArray release];
	[_environmentVariables release];
	
    if(taskHelper)
        [taskHelper release];
    taskHelper = nil;
    
	[super dealloc];
}

- (void)addArgument:(NSString *)arg {
	[arguments addObject:arg];
}
- (void)addArguments:(NSArray *)args {
	[arguments addObjectsFromArray:args];
}


- (NSInteger)start {	
	isRunning = YES;
	
	if (nonBlocking == NO) {
		[gpgTaskLock lock];
	}
	
	
    // Default arguments which every call to GPG needs.
    NSMutableArray *defaultArguments = [NSMutableArray arrayWithObjects:
                                        @"--no-greeting", @"--no-tty", @"--with-colons", @"--fixed-list-mode",
										@"--utf8-strings", @"--display-charset", @"utf-8", @"--enable-special-filenames",
                                        @"--yes", @"--status-file", GPGStatusFilePlaceholder, @"--no-verbose", nil];

	
	if (progressInfo && [delegate respondsToSelector:@selector(gpgTask:progressed:total:)]) {
		[defaultArguments addObject:@"--enable-progress-filter"];
    }
	
	NSSet *genKeyArgs = [NSSet setWithObjects:@"--gen-key", @"--generate-key", @"--full-gen-key", @"--full-generate-key", nil];
	if (![[NSSet setWithArray:arguments] intersectsSet:genKeyArgs]) {
		[defaultArguments addObject:@"--output"];
		[defaultArguments addObject:@"-"];
	}
	
    // If batch mode is not set, add the command-fd using stdin.
    if (batchMode) {
        [defaultArguments addObject:@"--batch"];
    } else {
        [defaultArguments addObjectsFromArray:[NSArray arrayWithObjects:@"--no-batch", @"--command-fd", @"0", nil]];
	}
	
    // If the attribute data is required, add the attribute-fd.
	if (getAttributeData) {
        [defaultArguments addObjectsFromArray:[NSArray arrayWithObjects:@"--attribute-file", GPGAttributeFilePlaceholder, nil]];
	}
 
	
	GPGStream *input = inData;
	if (passphrase) {
		[defaultArguments addObject:@"--passphrase-fd"];
		[defaultArguments addObject:@"0"];
		NSMutableData *fullInput = [NSMutableData dataWithData:passphrase.UTF8Data];
		[fullInput appendBytes:"\n" length:1];
		[fullInput appendData:inData.readAllData];
		input = [GPGMemoryStream memoryStreamForReading:fullInput];
	}
	
	
	// TODO: Optimize and make more generic.
    //Für Funktionen wie --decrypt oder --verify muss "--no-armor" nicht gesetzt sein.
    if ([arguments containsObject:@"--no-armor"] || [arguments containsObject:@"--no-armour"]) {
        NSSet *inputParameters = [NSSet setWithObjects:@"--decrypt", @"--verify", @"--import", @"--recv-keys", @"--refresh-keys", nil];
        for (NSString *argument in arguments) {
            if ([inputParameters containsObject:argument]) {
                NSUInteger index = [arguments indexOfObject:@"--no-armor"];
                if (index == NSNotFound) {
                    index = [arguments indexOfObject:@"--no-armour"];
                }
				if (index != NSNotFound) {
					[arguments replaceObjectAtIndex:index withObject:@"--armor"];
					while ((index = [arguments indexOfObject:@"--no-armor"]) != NSNotFound) {
						[arguments removeObjectAtIndex:index];
					}
					while ((index = [arguments indexOfObject:@"--no-armour"]) != NSNotFound) {
						[arguments removeObjectAtIndex:index];
					}
				}
                break;
            }
        }
    }
    [defaultArguments addObjectsFromArray:arguments];
	
	
	
    if ([delegate respondsToSelector:@selector(gpgTaskWillStart:)]) {
        [delegate gpgTaskWillStart:self];
    }
    
    // Allow the target to abort.
	if (cancelled) {
		if (nonBlocking == NO) {
			[gpgTaskLock unlock];
		}
		// It's not good to return an error, but don't set it.
		self.errorCode = GPGErrorCancelled;
		return GPGErrorCancelled;
	}
	
    __block GPGTask* cself = self;
    taskHelper = [[GPGTaskHelper alloc] initWithArguments:defaultArguments];
    if([delegate isKindOfClass:[GPGController class]])
		taskHelper.timeout = ((GPGController *)delegate).timeout;
	else
		taskHelper.timeout = self.timeout;
    
    if(!outStream)
        self.outStream = [GPGMemoryStream memoryStream];
    
    taskHelper.output = outStream;
    taskHelper.inData = input;
	taskHelper.closeInput = !!inData;
    taskHelper.processStatus = (lp_process_status_t)^(NSString *keyword, NSString *value){
        return [cself processStatusWithKeyword:keyword value:value];
    };
    // Only setup the progress handler if the delegate can handle progress messages
    // and gpg is requested to print out progress info.
    if(progressInfo && [delegate respondsToSelector:@selector(gpgTask:progressed:total:)]) {
        taskHelper.progressHandler = ^(NSUInteger processedBytes, NSUInteger totalBytes) {
            [cself.delegate gpgTask:cself progressed:processedBytes total:totalBytes];
        };
    }
    taskHelper.readAttributes = getAttributeData;
    taskHelper.checkForSandbox = YES;
	taskHelper.environmentVariables = self.environmentVariables;
	
    
    @try {
        exitcode = [taskHelper run];
        self.statusData = taskHelper.status;
        self.attributeData = taskHelper.attributes;
        self.errData = taskHelper.errors;
    }
    @catch (NSException *exception) {
        [taskHelper release];
		taskHelper = nil;
		if (nonBlocking == NO) {
			[gpgTaskLock unlock];
		}
		@throw exception;
    }
    
	// In case pinentry or gpg-agent crashed or was killed or is not available at all
	// and Libmacgpg is used from a sandboxed application, the exitcode will be GPGErrorCancelled,
	// but errorCodes will contain the actual error.
	// GPGErrorCancelled should only be returned if the user in fact cancelled
	// a passphrase request.
	if(exitcode == GPGErrorCancelled) {
		// Remove the NO_SECKEY error, since that will always be contained if
		// a pinentry request was cancelled.
		if([errorCodes count]) {
			NSMutableArray *newErrorCodes = [errorCodes mutableCopy];
			[newErrorCodes removeObject:[NSNumber numberWithInt:GPGErrorNoSecretKey]];
			exitcode = [[newErrorCodes objectAtIndex:0] integerValue];
		}
	}
	
    if([delegate respondsToSelector:@selector(gpgTaskDidTerminate:)])
        [delegate gpgTaskDidTerminate:self];
    
    isRunning = NO;
    
	[taskHelper release];
	taskHelper = nil;
	
	if (nonBlocking == NO) {
		[gpgTaskLock unlock];
	}
    return exitcode;
}

- (NSData *)processStatusWithKeyword:(NSString *)keyword value:(NSString *)value {
    
    NSArray <NSString *> *parts = value.length == 0 ? @[] : [value componentsSeparatedByString:@" "];
    NSInteger statusCode = [GPGTaskHelper.statusCodes[keyword] integerValue];
    // No status code available, we're out of here.
    if(!statusCode)
        return nil;

    switch(statusCode) {
		case GPG_STATUS_FAILURE:
        case GPG_STATUS_ERROR: {
            NSRange range = [value rangeOfString:@" "];
			if (range.length > 0) {
				NSInteger tempValue = [value substringFromIndex:range.location + 1].integerValue;
                self.errorCode = tempValue & 0xFFFF;
			}
            break;
        }
		case GPG_STATUS_NO_SECKEY:
			self.errorCode = GPGErrorNoSecretKey;
			break;
		case GPG_STATUS_NO_PUBKEY:
			self.errorCode = GPGErrorNoPublicKey;
			break;
		case GPG_STATUS_DECRYPTION_OKAY:
		case GPG_STATUS_KEY_CONSIDERED:
			[self unsetErrorCode:GPGErrorNoSecretKey];
			[self unsetErrorCode:GPGErrorCancelled];
			break;
		case GPG_STATUS_BAD_PASSPHRASE:
			self.errorCode = GPGErrorBadPassphrase;
			break;
		case GPG_STATUS_MISSING_PASSPHRASE:
		case GPG_STATUS_GOOD_PASSPHRASE:
			[self unsetErrorCode:GPGErrorBadPassphrase];
			break;
		case GPG_STATUS_DECRYPTION_FAILED:
			if (self.errorCode == GPGErrorNoError) {
				self.errorCode = GPGErrorDecryptionFailed;
			} else {
				// Add GPGErrorDecryptionFailed to the list of error codes.
				int oldValue = self.errorCode;
				self.errorCode = GPGErrorDecryptionFailed;
				self.errorCode = oldValue;
			}
			break;
		case GPG_STATUS_BADMDC:
			self.errorCode = GPGErrorBadMDC;
			break;
		case GPG_STATUS_DECRYPTION_INFO:
			// First field: MDC. Always 0 when AEAD is used.
			// Second field: Symmetric algorithm.
			// Third field: AEAD algorithm.
			if (parts.count >= 1 && parts[0].integerValue == 0) {
				if (parts.count < 3 || parts[2].integerValue == 0) {
					// No MDC was used.
					self.errorCode = GPGErrorNoMDC;
				}
			}
			break;
    }
	
	//Fill statusDict.
	NSUInteger partCount = [parts count];
	if (partCount > 0) {
		NSArray *myParts;
		NSUInteger maxCount = partCountForStatusCode[statusCode];
		if (maxCount > 0 && partCount > maxCount) { //We have more parts than maxCount (the real last part contain whitespaces).
			myParts = [parts subarrayWithRange:NSMakeRange(0, maxCount - 1)];
			NSString *lastPart = [[parts subarrayWithRange:NSMakeRange(maxCount, partCount - maxCount)] componentsJoinedByString:@" "];
			myParts = [myParts arrayByAddingObject:lastPart];
		} else {
			myParts = parts;
		}
		
		NSMutableArray *statusValue = [statusDict objectForKey:keyword];
		if (statusValue) {
			[statusValue addObject:myParts];
		} else {
			[statusDict setObject:[NSMutableArray arrayWithObject:myParts] forKey:keyword];
		}
	} else {
		[statusDict setObject:[NSNumber numberWithBool:YES] forKey:keyword];
	}
	
	// Fill statusArray
	[statusArray addObject:[GPGStatusLine statusLineWithKeyword:keyword code:statusCode parts:parts]];
	
	
	
	// If the status is either GET_HIDDEN, GET_LINE or GET_BOOL
    // the GPG Controller is asked for a value to be passed
    // to GPG using the command pipe.
    id response = nil;
    if([delegate respondsToSelector:@selector(gpgTask:statusCode:prompt:)])
        response = [delegate gpgTask:self statusCode:statusCode prompt:value];
    
    return [response isKindOfClass:[NSData class]] ? response : [[response description] dataUsingEncoding:NSUTF8StringEncoding];
}

- (int)fullErrorCode {
	return errorCode;
}
- (int)errorCode {
	return errorCode & 0xFFFF;
}
- (void)setErrorCode:(int)value {
	NSNumber *code = [NSNumber numberWithInt:value];
	if (![errorCodes containsObject:code]) {
		[errorCodes addObject:code];
		// GPGErrorCancelled is the most important error code.
		if (!errorCode || (value & 0xFFFF) == GPGErrorCancelled) {
			errorCode = value;
		}
	}
}
- (void)unsetErrorCode:(int)value {
	NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];
	NSUInteger count = errorCodes.count;
	
	// Find the error code with all possible prefixes.
	for (NSUInteger i = 0; i < count; i++) {
		NSInteger tempValue = errorCodes[i].integerValue;
		tempValue = tempValue & 0xFFFF;
		if (tempValue == value) {
			[indexes addIndex:i];
		}
	}
	
	if (indexes.count > 0) {
		[errorCodes removeObjectsAtIndexes:indexes];
		
		/* If other errors were found, set the errorCode to the
		 first one, otherwise to No Error.
		 */
		if (errorCodes.count) {
			errorCode = errorCodes[0].intValue;
		} else {
			errorCode = GPGErrorNoError;
		}
	}
}
- (NSArray *)errorCodes {
	NSMutableArray *filteredCodes = [NSMutableArray arrayWithCapacity:errorCodes.count];
	for (NSNumber *code in errorCodes) {
		[filteredCodes addObject:@(code.intValue & 0xFFFF)];
	}
	return filteredCodes;
}

- (void)cancel {
    [taskHelper cancel];
}


/* Helper function to display NSData content. */
- (void)logDataContent:(NSData *)data message:(NSString *)message {
    NSString *tmpString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    GPGDebugLog(@"[DEBUG] %@: %@ >>", message, tmpString);
    [tmpString release];
}


+ (BOOL)launchGeneralTask:(NSString *)path withArguments:(NSArray *)arguments {
	return [self launchGeneralTask:path withArguments:arguments wait:NO];
}

+ (BOOL)launchGeneralTask:(NSString *)path withArguments:(NSArray *)arguments wait:(BOOL)wait {
	return [GPGTaskHelper launchGeneralTask:path withArguments:arguments wait:wait];
}

+ (BOOL)showGPGSuitePreferencesTab:(NSString *)tab arguments:(NSDictionary *)arguments {
	NSMutableDictionary *mutableArguments = [NSMutableDictionary dictionaryWithDictionary:arguments];
	if (!arguments[@"tool"]) {
		// Add the name tool to the arguments.
		NSString *identifier = [NSBundle mainBundle].bundleIdentifier;
		NSString *tool = [identifier componentsSeparatedByString:@"."].lastObject;
		if ([tool isEqualToString:@"mail"]) {
			// When the identifier is com.apple.mail it means GPGMail is used.
			tool = @"gpgmail";
		}
		if (tool) {
			mutableArguments[@"tool"] = tool;
		}
	}
	if (tab) {
		// Set the name of the tab.
		mutableArguments[@"tab"] = tab;
	}
	arguments = [NSDictionary dictionaryWithDictionary:mutableArguments];
	
	return [GPGTaskHelper showGPGSuitePreferencesWithArguments:arguments];
}
+ (NSDictionary *)readGPGSuitePreferencesArguments {
	return [GPGTaskHelper readGPGSuitePreferencesArguments];
}



+ (BOOL)sandboxed {
	// Don't perform sandbox check on 10.6, since Mail.app wasn't sandboxed
	// back then and it seems to be a problem, resulting in a crash when used in
	// GPGPreferences and GPGServices
	if(NSAppKitVersionNumber < NSAppKitVersionNumber10_7)
		return NO;
	
	static dispatch_once_t onceToken;
	static BOOL sandboxed;
	dispatch_once(&onceToken, ^{
		sandboxed = [[NSBundle mainBundle] ob_isSandboxed];
	});
		
	return sandboxed;
}

@end


