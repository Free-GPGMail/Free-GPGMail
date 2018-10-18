#import "DirectoryWatcher.h"


@interface DirectoryWatcher ()
@property (nonatomic, readonly) NSMutableSet *pathsToWatch;
- (void)updateStream;
void eventStreamCallBack(ConstFSEventStreamRef streamRef, void *clientCallBackInfo, size_t numEvents, void *eventPaths, const FSEventStreamEventFlags eventFlags[], const FSEventStreamEventId eventIds[]);
@end



@implementation DirectoryWatcher


+ (id)directoryWatcherWithPath:(NSString *)path {
	return [[[self alloc] initWithPath:path] autorelease];
}
+ (id)directoryWatcherWithPaths:(NSArray *)paths {
	return [[[self alloc] initWithPaths:paths] autorelease];
}


- (id)init {
	return [self initWithPaths:nil];
}
- (id)initWithPath:(NSString *)path {
	return [self initWithPaths:[NSArray arrayWithObject:path]];
}
- (id)initWithPaths:(NSArray *)paths {
	if ((self = [super init]) == nil) {
		return nil;
	}
	latency = 1.0;
	if ([paths count] > 0) {
		[self addPaths:paths];
	}
	return self;
}



- (void)addPath:(NSString *)path {
	[self addPaths:[NSArray arrayWithObject:path]];
}
- (void)addPaths:(NSArray *)paths {
	NSUInteger count = self.pathsToWatch.count;
	[self.pathsToWatch addObjectsFromArray:paths];
	if (self.pathsToWatch.count > count) {
		[self updateStream];
	}
}
- (void)removePath:(NSString *)path {
	[self removePaths:[NSArray arrayWithObject:path]];
}
- (void)removePaths:(NSArray *)paths {
	NSUInteger count = self.pathsToWatch.count;
	for (id path in paths) {
		[self.pathsToWatch removeObject:path];
	}
	if (self.pathsToWatch.count < count) {
		[self updateStream];
	}	
}
- (void)removeAllPaths {
	if (self.pathsToWatch.count > 0) {
		[pathsToWatch removeAllObjects];
		[self updateStream];
	}
}


- (NSUInteger)latency {
	return latency;
}
- (void)setLatency:(NSUInteger)value {
	if (value != latency) {
		latency = value;
		[self updateStream];
	}
}
- (NSObject <DirectoryWatcherDelegate> *)delegate {
	return [[delegate retain] autorelease];
}
- (void)setDelegate:(NSObject <DirectoryWatcherDelegate> *)value {
	if (value != delegate) {
		delegate = value;
		[self updateStream];
	}
}




void eventStreamCallBack(ConstFSEventStreamRef streamRef, void *clientCallBackInfo, size_t numEvents, void *eventPaths, const FSEventStreamEventFlags eventFlags[], const FSEventStreamEventId eventIds[]) {
	DirectoryWatcher *directoryWatcher = clientCallBackInfo;
	[directoryWatcher.delegate pathsChanged:eventPaths flags:eventFlags];
}




- (void)updateStream {
	if (eventStream) {
		FSEventStreamStop(eventStream);
		FSEventStreamInvalidate(eventStream);
		FSEventStreamRelease(eventStream);
		eventStream = nil;
	}
	if (self.delegate && [self.pathsToWatch count] > 0) {
		FSEventStreamContext context = {0, self, nil, nil, nil};
		eventStream = FSEventStreamCreate(nil, &eventStreamCallBack, &context, (CFArrayRef)[self.pathsToWatch allObjects], kFSEventStreamEventIdSinceNow, latency, kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagIgnoreSelf);
		if (eventStream) {
			CFRunLoopRef mainLoop = [[NSRunLoop mainRunLoop] getCFRunLoop];
			FSEventStreamScheduleWithRunLoop(eventStream, mainLoop, kCFRunLoopDefaultMode);
			if (!FSEventStreamStart(eventStream)) {
				FSEventStreamInvalidate(eventStream);
				FSEventStreamRelease(eventStream);
				eventStream = nil;
			}
		}
	}
}


- (NSMutableSet *)pathsToWatch {
	if (!pathsToWatch) {
		pathsToWatch = [[NSMutableSet alloc] init];
	}
	return pathsToWatch;
}




- (void)finalize {
	FSEventStreamStop(eventStream);
	FSEventStreamInvalidate(eventStream);
	FSEventStreamRelease(eventStream);
	[super finalize];
}
- (void)dealloc {
	FSEventStreamStop(eventStream);
	FSEventStreamInvalidate(eventStream);
	FSEventStreamRelease(eventStream);
	[pathsToWatch release];
	[super dealloc];
}



@end


