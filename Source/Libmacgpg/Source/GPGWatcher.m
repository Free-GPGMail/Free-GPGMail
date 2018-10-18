#import "GPGWatcher.h"
#import "GPGGlobals.h"
#import "GPGOptions.h"
#import "GPGTask.h"

NSString * const GPGKeysChangedNotification = @"GPGKeysChangedNotification";

@interface GPGWatcher ()
@property (nonatomic, retain) NSMutableDictionary *changeDates;
- (NSString *)gpgCurrentHome;
- (void)updateWatcher;
- (void)timerFired:(NSTimer *)timer;
- (void)keysChangedNotification:(NSNotification *)notification;
@end


@implementation GPGWatcher
@synthesize changeDates;
@synthesize toleranceBefore;
@synthesize toleranceAfter;
@synthesize checkForSandbox = _checkForSandbox;
#if defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1080
@synthesize jailfree;
#endif

#define TOLERANCE_BEFORE 4.0
#define TOLERANCE_AFTER 4.0
#define DW_LATENCY 2.0

static NSString * const kWatcherLastFoundChange = @"lastFoundChange";
static NSString * const kWatchedFileName = @"watchedFileName";

- (void)dealloc 
{
#if defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1080
    [jailfree release];
	jailfree = nil;
#endif
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];    
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];

    [dirWatcher release];
    [identifier release];
    [changeDates release];
    [filesToWatch release];
    [gpgSpecifiedHome release];
    [super dealloc];
}

- (void)setToleranceBefore:(NSTimeInterval)interval {
    if (interval < 0)
        interval = 0;
    toleranceBefore = interval;
}

- (void)setToleranceAfter:(NSTimeInterval)interval {
    if (interval < 0)
        interval = 0;
    toleranceAfter = interval;
}

- (NSString *)gpgCurrentHome {
    if (gpgSpecifiedHome)
        return gpgSpecifiedHome;
    return [[[GPGOptions sharedOptions] gpgHome] stringByStandardizingPath];
}

- (void)updateWatcher {
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSMutableDictionary *dates = [NSMutableDictionary dictionary];
	
	NSString *gpgHome = [self gpgCurrentHome];
	
	//TODO: Full support for symlinks.
	for (NSString *file in [filesToWatch allKeys]) {
        NSString *pathToFile = [gpgHome stringByAppendingPathComponent:file];
		NSDate *date = [[fileManager attributesOfItemAtPath:pathToFile error:nil] fileModificationDate];		
        // when nil, set to something old so that we can detect file creation
		if (!date) 
            date = [NSDate dateWithTimeIntervalSinceReferenceDate:0];
        [dates setObject:date forKey:file]; // note: not full path; just name
	}
	self.changeDates = dates;
	
	[dirWatcher removeAllPaths];
	[dirWatcher addPath:gpgHome];
}


- (void)pathsChanged:(NSArray *)paths flags:(const FSEventStreamEventFlags [])flags {
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSDate *date1, *date2;
	NSString *gpgHome = [self gpgCurrentHome];
	
	for (NSString *file in changeDates) {
        NSString *pathToFile = [gpgHome stringByAppendingPathComponent:file];
		date1 = [changeDates objectForKey:file];
		date2 = [[fileManager attributesOfItemAtPath:pathToFile error:nil] fileModificationDate];
        if (!date2)
            date2 = [NSDate dateWithTimeIntervalSinceReferenceDate:0];
		
		if (![date1 isEqualToDate:date2]) {
            [changeDates setObject:date2 forKey:file];

            NSTimeInterval eventLastKnownChange;
            NSString *eventName = [filesToWatch objectForKey:file];
            if ([GPGKeysChangedNotification isEqualToString:eventName]) {
                eventLastKnownChange = lastKnownChange;
            }
            else if ([GPGConfigurationModifiedNotification isEqualToString:eventName]) {
                eventLastKnownChange = lastConfKnownChange;
            }
            else {
                // unexpected!
                continue;
            }

			NSTimeInterval lastFoundChange = [NSDate timeIntervalSinceReferenceDate];
			if (eventLastKnownChange + toleranceBefore < lastFoundChange) {
                NSDictionary *timerInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                           [NSNumber numberWithDouble:lastFoundChange], kWatcherLastFoundChange, 
                                           file, kWatchedFileName,
                                           nil];
				[NSTimer scheduledTimerWithTimeInterval:toleranceAfter target:self selector:@selector(timerFired:) userInfo:timerInfo repeats:NO];
			}
			break;
		}
	}
}
- (void)timerFired:(NSTimer *)timer {
    NSDictionary *timerInfo = [timer userInfo];
	NSTimeInterval foundChange = [[timerInfo objectForKey:kWatcherLastFoundChange] doubleValue];
    NSString *watchedFile = [timerInfo objectForKey:kWatchedFileName];

    NSString *eventName = [filesToWatch objectForKey:watchedFile];
    if ([GPGKeysChangedNotification isEqualToString:eventName]) {
        // for this event type, lastKnownChange is set by watching the event itself!
        // (see keysChangedNotification:)

        [self postNotificationName:GPGKeysChangedNotification object:identifier];
    }
    else if ([GPGConfigurationModifiedNotification isEqualToString:eventName]) {
        // for this event type, we track lastConfKnownChange ourself
        lastConfKnownChange = foundChange;

        [self postNotificationName:GPGConfigurationModifiedNotification object:identifier];
    }
}
- (void)keysChangedNotification:(NSNotification *)notification {
	lastKnownChange = [NSDate timeIntervalSinceReferenceDate];
}

- (void)postNotificationName:(NSString *)name object:(NSString *)object {
#if defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1080
	if (jailfree && !self.checkForSandbox) {
        [[jailfree remoteObjectProxy] postNotificationName:name object:object];
	} else
#endif
	{
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:name object:object userInfo:nil options:0];
	}
}

//TODO: Testen ob Symlinks in der Mitte des Pfades korrekt verarbeitet werden.
- (void)workspaceDidMount:(NSNotification *)notification {
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *gpgHome = [self gpgCurrentHome];
	NSString *resolvedGPGHome = nil, *temp;
	
	// Resolve symlinks.
	do {
		resolvedGPGHome = [fileManager destinationOfSymbolicLinkAtPath:gpgHome error:nil];
		if (!resolvedGPGHome) {
			break;
		} else if (![resolvedGPGHome hasPrefix:@"/"]) {
			resolvedGPGHome = [[[gpgHome stringByDeletingLastPathComponent] stringByAppendingPathComponent:resolvedGPGHome] stringByStandardizingPath];
		}
		
		temp = gpgHome;
		gpgHome = resolvedGPGHome;
	} while (![gpgHome isEqualToString:temp]);
	
	
	NSString *devicePath = [[notification userInfo] objectForKey:@"NSDevicePath"];
	
	if ([gpgHome rangeOfString:devicePath].length > 0) {
		// The (un)mounted volume contains gpgHome.
		[self postNotificationName:GPGKeysChangedNotification object:identifier];
	}
}

// Singleton: alloc, init etc.

static id syncRoot = nil;

+ (void)initialize {
    if (!syncRoot)
        syncRoot = [[NSObject alloc] init];
}

+ (void)activate {
    [self activateWithXPCConnection:nil];
}

+ (void)activateWithXPCConnection:(id)connection {
	GPGWatcher *instance = [self sharedInstance];
    if(!connection)
        return;
    
#if defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1080
    instance.jailfree = connection;
    
    [[NSDistributedNotificationCenter defaultCenter] addObserver:instance selector:@selector(keysChangedNotification:) name:GPGKeysChangedNotification object:nil];
    
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:instance selector:@selector(workspaceDidMount:) name:NSWorkspaceDidMountNotification object:[NSWorkspace sharedWorkspace]];
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:instance selector:@selector(workspaceDidMount:) name:NSWorkspaceDidUnmountNotification object:[NSWorkspace sharedWorkspace]];
#endif
}

+ (id)sharedInstance {
    // Normally might just setup the singleton in initialize and not worry
    // about locking; but for unit testing, we don't want spurious events,
    // as no one will have called sharedInstance.
    static id sharedInstance = nil;
    @synchronized(syncRoot) {
        if (!sharedInstance)
            sharedInstance = [[self alloc] init];
    }
    return [[sharedInstance retain] autorelease];	
}

- (id)init {
    self.checkForSandbox = [GPGTask sandboxed];
    if([GPGTask sandboxed])
        return [self initSandboxed];
    else {
        return [self initWithGpgHome:nil];
    }
}

- (id)initWithGpgHome:(NSString *)directoryPath
{
    if (self = [super init]) {
        gpgSpecifiedHome = [directoryPath retain];
        filesToWatch = [[NSDictionary alloc] initWithObjectsAndKeys:
                        GPGKeysChangedNotification, @"pubring.gpg", 
                        GPGKeysChangedNotification, @"secring.gpg",
                        GPGConfigurationModifiedNotification, @"gpg.conf",
						GPGConfigurationModifiedNotification, @"gpg-agent.conf",
						GPGConfigurationModifiedNotification, @"dirmngr.conf",
                        nil];

		identifier = [[NSString alloc] initWithFormat:@"%i%p", [[NSProcessInfo processInfo] processIdentifier], self];

		self.toleranceBefore = TOLERANCE_BEFORE;
        self.toleranceAfter = TOLERANCE_AFTER;
        
        dirWatcher = [[DirectoryWatcher alloc] init];
        dirWatcher.delegate = self;
        dirWatcher.latency = (NSUInteger)DW_LATENCY;
        [self updateWatcher];
		
		[[NSGarbageCollector defaultCollector] disableCollectorForPointer:self];
	}
	return self;
}

- (id)initSandboxed {
#if defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1080
    self = [super init];
    if(self) {
        // The semaphore is used to wait for the reply from the xpc
        // service.
        // XPC name: org.gpgtools.Libmacgpg.jailfree.xpc_OpenStep
        jailfree = [[NSXPCConnection alloc] initWithMachServiceName:JAILFREE_XPC_MACH_NAME options:0];
        jailfree.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(Jailfree)];
        jailfree.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(Jail)];
        jailfree.exportedObject = self;
        
        [jailfree resume];
        
        // Ask the helper to setup the watcher.
        [[jailfree remoteObjectProxy] startGPGWatcher];
    }
    return self;
#else
	return [self initWithGpgHome:nil];
#endif
}

@end
