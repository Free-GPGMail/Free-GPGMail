//
//  MMStopwatch.m
//  MBMLibrary
//
//  Created by Matt Maher on 1/24/12.
//  Copyright (c) 2012 FedEx. All rights reserved.
//

#import "MMStopwatch.h"




// +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -   
#pragma mark -
#pragma mark MMStopwatch
#pragma mark -
// +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  - 
// =================[ PRIVATE ]==================================
@interface MMStopwatch ()
+ (id) sharedInstance;
- (MMStopwatchItem *) get:(NSString *)name;
- (void) add:(NSString *)name;
- (void) remove:(NSString *)name;
@end
// ==============================================================
@implementation MMStopwatch
- (void)dealloc {
    [items removeAllObjects];
}
+ (void) start:(NSString *)name {
	[(MMStopwatch *)[MMStopwatch sharedInstance] add:name];
}
+ (void) stop:(NSString *)name {
	MMStopwatchItem *item = [[MMStopwatch sharedInstance] get:name];
	[item stop];
	[self print:name];
}
+ (void) print:(NSString *)name {	
	MMStopwatchItem *item = [[MMStopwatch sharedInstance] get:name];
	if (item) {
		if (item.stopped) {
			NSLog(@"%@", item);
		}
		
		else {
			NSLog(@"%@ (running)", item);
		}
	}
	
	else {
		NSLog(@"No stopwatch named [%@] found", name);
	}
}


// ----------------------
// INTERNALS
// ----------------------
- (MMStopwatchItem *) get:(NSString *)name {
	// bail
	if ( ! name) {
		return nil;
	}
	return (MMStopwatchItem *)[items objectForKey:name];
}
- (void) remove:(NSString *)name {
	// bail
	if ( ! name) {
		return;
	}
	[items removeObjectForKey:name];
}
- (void) add:(NSString *)name {
	// bail
	if ( ! name) {
		return;
	}
	
	[self remove:name];
	[items setObject:[MMStopwatchItem itemWithName:name] forKey:name];
}





// +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  
#pragma mark -
#pragma mark SINGLETON PATTERN
#pragma mark -
// +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  
- (id)init {
    self = [super init];
    if (self) {
        items = [[NSMutableDictionary alloc] init];
    }
    return self;
}
static id _sharedSingleton		= nil;
+ (id) sharedInstance {
	
	// return before any locking .. should perform better
	if (_sharedSingleton) 
		return _sharedSingleton;
	
	// THREAD SAFTEY
	@synchronized(self) {
		if (    !    _sharedSingleton) {
			_sharedSingleton		= [[self alloc] init];
		}
	}
	return _sharedSingleton;
}
+ (id) alloc {
	NSAssert(_sharedSingleton == nil, @"Attempted to allocate a second instance of a singleton.");
	return [super alloc];
}

@end













// +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -   
#pragma mark -
#pragma mark MMStopwatchItem
#pragma mark -
// +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  +  -  
@implementation MMStopwatchItem

@synthesize name;
@synthesize started;
@synthesize stopped;
+ (MMStopwatchItem *) itemWithName:(NSString *)name {
	MMStopwatchItem *item	= [[MMStopwatchItem alloc] init];
	item.name				= name;
	item.started			= [NSDate date];
	return item;
}
- (void) stop {
	self.stopped			= [NSDate date];
}
- (NSString *) description {
	NSMutableString *outString = [[NSMutableString alloc] init];
	[outString appendFormat:@"Stopwatch: [%@] runtime: [%@]", name, [self runtimePretty]];
	return outString;
}
- (NSString *) fullDescription {
	NSMutableString *outString = [[NSMutableString alloc] init];
	[outString appendFormat:@"Stopwatch:	[%@]\n", name];
	[outString appendFormat:@"	started:	[%@]\n", started];
	[outString appendFormat:@"	stopped:	[%@]\n", stopped];
	[outString appendString:@"			  --------\n"];
	[outString appendFormat:@"	runtime:	[%@]\n", [self runtimePretty]];
	return outString;
}
- (double) runtimeMills {
	return [self runtime] * 1000.0;
}
- (NSTimeInterval) runtime {
	// never started
	if ( ! started) {
		return 0.0;
	}
	
	// not yet stopped
	if ( ! stopped) {
		return [started timeIntervalSinceNow] * -1;
	}
	
	// start to stop time
	return [started timeIntervalSinceDate:stopped] * -1;
}
- (NSString *) runtimePretty {
	
	double secsRem		= [self runtime];
	
	// 3600 seconds in an hour
	
	int hours			= (int)(secsRem / 3600);
	secsRem				= secsRem - (hours * 3600);
	int mins			= (int)(secsRem / 60);
	secsRem				= secsRem - (mins * 60);
	
	if (hours > 0) {
		return [NSString stringWithFormat:@"%d:%d:%f", hours, mins, secsRem];
	}
	
	if (mins > 0) {
		return [NSString stringWithFormat:@"%d:%f", mins, secsRem];
	}
	
	return [NSString stringWithFormat:@"%f", secsRem];
}
@end












