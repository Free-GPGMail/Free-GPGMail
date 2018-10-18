#import "GPGException.h"
#import "GPGTask.h"
#import <dlfcn.h>

@interface GPGException ()
@property (nonatomic, retain) GPGTask *gpgTask;
@property (nonatomic) GPGErrorCode errorCode;
@end


@implementation GPGException
@synthesize gpgTask, errorCode;

NSString *GPGExceptionName = @"GPGException";
NSString * const GPGErrorDomain = @"GPGErrorDomain";

- (id)initWithName:(NSString *)aName reason:(NSString *)aReason userInfo:(NSDictionary *)aUserInfo errorCode:(GPGErrorCode)aErrorCode gpgTask:(GPGTask *)aGPGTask {
	if (!(self = [super initWithName:aName reason:aReason userInfo:aUserInfo])) {
		return nil;
	}

	if (aGPGTask) {
		self.gpgTask = aGPGTask;
		if (aGPGTask.exitcode == GPGErrorCancelled) {
			aErrorCode = GPGErrorCancelled;
		} else if (aErrorCode == 0 && gpgTask.errorCode) {
			aErrorCode = gpgTask.errorCode;
		}
	}

	// Ignore the high-bit flags of the errorCode.
	self.errorCode = aErrorCode & 0xFFFF;

	return self;
}

- (id)initWithName:(NSString *)aName reason:(NSString *)aReason userInfo:(NSDictionary *)aUserInfo {
	return [self initWithName:aName reason:aReason userInfo:aUserInfo errorCode:0 gpgTask:nil];
}

+ (GPGException *)exceptionWithReason:(NSString *)aReason userInfo:(NSDictionary *)aUserInfo errorCode:(GPGErrorCode)aErrorCode gpgTask:(GPGTask *)aGPGTask {
	return [[[self alloc] initWithName:GPGExceptionName reason:aReason userInfo:aUserInfo errorCode:aErrorCode gpgTask:aGPGTask] autorelease];
}
+ (GPGException *)exceptionWithReason:(NSString *)aReason errorCode:(GPGErrorCode)aErrorCode gpgTask:(GPGTask *)aGPGTask {
	return [[[self alloc] initWithName:GPGExceptionName reason:aReason userInfo:nil errorCode:aErrorCode gpgTask:aGPGTask] autorelease];
}
+ (GPGException *)exceptionWithReason:(NSString *)aReason gpgTask:(GPGTask *)aGPGTask {
	return [[[self alloc] initWithName:GPGExceptionName reason:aReason userInfo:nil errorCode:0 gpgTask:aGPGTask] autorelease];
}
+ (GPGException *)exceptionWithReason:(NSString *)aReason errorCode:(GPGErrorCode)aErrorCode {
	return [[[self alloc] initWithName:GPGExceptionName reason:aReason userInfo:nil errorCode:aErrorCode gpgTask:nil] autorelease];
}


- (NSString *)description {
	if (description) {
		return description;
	}
	
	GPGErrorCode code = self.errorCode;
	if (!code && self.gpgTask) {
		code = self.gpgTask.errorCode;
	}
	
	NSString *details = nil;
	
	//TODO: Keyserver error codes.
	switch (code) {
		case 0:
			// No further details.
			break;
		case GPGErrorBadMDC:
			details = @"Modification detected";
			break;
		case GPGErrorNoMDC:
			details = @"No modification detection code";
			break;
		case GPGErrorSubkeyNotFound:
			details = @"Subkey not found";
			break;
		default: {
			BOOL failed = NO;
			void *libHandle = nil;
			const char *errorString = nil;
			unsigned int (*gpg_err_init)() = nil;
			const char *(*gpg_strerror)(unsigned int) = nil;
			
			libHandle = dlopen("/usr/local/MacGPG2/lib/libgpg-error.dylib", RTLD_LOCAL | RTLD_LAZY);
			if (!libHandle) {
				GPGDebugLog(@"[%@] %s", [self className], dlerror());
				failed = YES;
			}

			if (!failed) {
				gpg_err_init = (unsigned int (*)())dlsym(libHandle, "gpg_err_init");
				if (!gpg_err_init) {
					GPGDebugLog(@"[%@] %s", [self className], dlerror());
					failed = YES;
				}
			}

			if (!failed) {
				gpg_strerror = (const char *(*)(unsigned int))dlsym(libHandle, "gpg_strerror");
				if (!gpg_strerror) {
					GPGDebugLog(@"[%@] %s", [self className], dlerror());
					failed = YES;
				}
			}

			if (!failed) {
				if (gpg_err_init()) {
					GPGDebugLog(@"[%@] gpg_err_init() failed!", [self className]);
					failed = YES;
				}
			}

			if (!failed) {
				errorString = gpg_strerror(2 << 24 | code);
				if (errorString) {
					details = [NSString stringWithUTF8String:errorString];
				}
			}
			
			if (libHandle) {
				dlclose(libHandle);
			}
			break;
		}
	}
	
	
	if (details) {
		description = [[NSString alloc] initWithFormat:@"%@ (%@)\nCode = %i", self.reason, details, code];
	} else {
		description = [[NSString alloc] initWithFormat:@"%@\nCode = %i", self.reason, code];
	}
	
	return description;
}

- (void)dealloc {
	[description release];
	[gpgTask release];
	gpgTask = nil;
	[super dealloc];
}


@end

