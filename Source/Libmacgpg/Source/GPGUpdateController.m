//
//  UpdateController.m
//  GPGPreferences
//
//  Created by Mento on 26.04.2013
//
//

#import <Libmacgpg/Libmacgpg.h>
#import "GPGUpdateController.h"

static NSString *const SUEnableAutomaticChecksKey = @"SUEnableAutomaticChecks";
static NSString *const GPGBetaUpdatesKey = @"BetaUpdates";

@implementation GPGUpdateController


- (instancetype)realInit {
	self = [super init];
	if (self == nil) {
		return nil;
	}
	
	_options = [GPGOptions new];
	_options.standardDomain = @"org.gpgtools.updater";
	
	[_options registerDefaults:@{SUEnableAutomaticChecksKey: @YES}];
	
	[_options addObserver:self forKeyPath:SUEnableAutomaticChecksKey options:0 context:nil];
	[_options addObserver:self forKeyPath:GPGBetaUpdatesKey options:0 context:nil];
	
	return self;
}

- (void)dealloc {
	[_options removeObserver:self forKeyPath:SUEnableAutomaticChecksKey];
	[_options removeObserver:self forKeyPath:GPGBetaUpdatesKey];
	[_options release];
	[super dealloc];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	NSString *changedValue = nil;
	
	if ([keyPath isEqualToString:SUEnableAutomaticChecksKey]) {
		changedValue = @"automaticallyChecksForUpdates";
	} else if ([keyPath isEqualToString:GPGBetaUpdatesKey]) {
		changedValue = @"downloadBetaUpdates";
	}
	
	if (changedValue) {
		[self willChangeValueForKey:changedValue];
		[self didChangeValueForKey:changedValue];
	}
}



#pragma mark IBActions

- (IBAction)checkForUpdates:(id)sender {
	NSString *updaterPath = @"/Library/Application Support/GPGTools/GPGSuite_Updater.app";
	OSStatus status = 1;
	
	BOOL isDir = NO;
	if ([[NSFileManager defaultManager] fileExistsAtPath:updaterPath isDirectory:&isDir] && isDir == YES) {
		LSLaunchURLSpec urlSpec;
		urlSpec.appURL = (CFURLRef)[NSURL fileURLWithPath:updaterPath];
		urlSpec.itemURLs = (CFArrayRef)@[[NSURL URLWithString:@"gpgsuite-updater://checknow"]];
		urlSpec.passThruParams = nil;
		urlSpec.launchFlags = kLSLaunchAsync;
		urlSpec.asyncRefCon = nil;
		status = LSOpenFromURLSpec(&urlSpec, nil);
	}
	
	if (status != 0) {
		NSRunAlertPanel(localizedLibmacgpgString(@"UpdaterNotWorking_Title"), @"%@", nil, nil, nil, localizedLibmacgpgString(@"UpdaterNotWorking_Msg"));
	}
}

- (IBAction)showReleaseNotes:(id)sender {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://gpgtools.org/releases/gpgsuite/release-notes.html"]];
}



#pragma mark Properties

- (BOOL)automaticallyChecksForUpdates {
	return [_options boolForKey:SUEnableAutomaticChecksKey];
}
- (void)setAutomaticallyChecksForUpdates:(BOOL)value {
	[_options setBool:value forKey:SUEnableAutomaticChecksKey];
}

- (BOOL)downloadBetaUpdates {
	NSNumber *value = [_options valueForKey:GPGBetaUpdatesKey];
	
	if (value) {
		return value.boolValue;
	} else {
		NSBundle *updaterBundle = [NSBundle bundleWithPath:@"/Library/Application Support/GPGTools/GPGSuite_Updater.app"];
		NSString *version = [updaterBundle objectForInfoDictionaryKey:@"CFBundleVersion"];
		if ([version rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"abAB"]].length > 0) {
			return YES;
		}
	}
	
	return NO;
}
- (void)setDownloadBetaUpdates:(BOOL)value {
	[_options setBool:value forKey:GPGBetaUpdatesKey];
}



#pragma mark Singleton

+ (instancetype)sharedInstance {
	static dispatch_once_t onceToken;
	static GPGUpdateController *sharedInstance;
	
	dispatch_once(&onceToken, ^{
		sharedInstance = [[super allocWithZone:nil] realInit];
	});
	
	return sharedInstance;
}

+ (id)allocWithZone:(NSZone *)zone {
	return [[self sharedInstance] retain];
}

- (id)init {
	return self;
}

- (id)copyWithZone:(NSZone *)zone {
	return self;
}

- (id)retain {
	return self;
}

- (NSUInteger)retainCount {
	return NSUIntegerMax;
}

- (oneway void)release {
}

- (id)autorelease {
	return self;
}


@end


