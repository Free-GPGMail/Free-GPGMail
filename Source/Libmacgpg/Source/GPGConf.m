#import "NSBundle+Sandbox.h"
#import "GPGTaskHelperXPC.h"
#import "GPGConf.h"
#import "GPGConfReader.h"
#import "GPGStdSetting.h"
#import "GPGGlobals.h"
#import "GPGTask.h"

@interface GPGConf ()
@property (nonatomic, retain) NSString *path;
@end

@implementation GPGConf
@synthesize path;
@synthesize optionsDomain;

- (id)valueForKey:(NSString *)key {
    GPGStdSetting *setting = [config objectForKey:key];
    if (setting) 
        return [setting value];
    else
        return nil;
}
- (void)setValue:(id)value forKey:(NSString *)key {
    GPGStdSetting *setting = [config objectForKey:key];
	if (value) {
        if (!setting) {
            GPGConfReader *reader = [GPGConfReader readerForDomain:self.optionsDomain];
            setting = [reader buildForLine:key];            
            if (setting) {
                [config setObject:setting forKey:key];
                [contents addObject:setting];
            }
        }

        if (setting)
            [setting setValue:value];
	} else if (setting) { //value == nil
		[setting setValue:nil];
	}
}


- (BOOL)saveConfig {
	NSString *lines = [self getContents];

	NSError *error = nil;
	[lines writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&error];
	if (error) {
		return NO;
	}
	return YES;
}

- (NSString *)getContents {
	NSMutableString *lines = [NSMutableString string];
	
	for (id item in contents) {
        NSString *encoded = [item description];
        [lines appendString:encoded];
        if (![encoded hasSuffix:@"\n"])
            [lines appendString:@"\n"];
	}
    return lines;
}

- (BOOL)loadConfig {
	NSString *configFile = nil;
	if([GPGTask sandboxed]) {
		configFile = [self loadConfigFileXPC];
	}
	else {
		NSError *error = nil;
		configFile = [NSString stringWithContentsOfFile:path usedEncoding:nil error:&error];
		
		if (!configFile) {
			if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
				GPGDebugLog(@"Can't load config (%@): %@", path, error);
				return  NO;
			}
			configFile = @"";
		}
	}
	return [self loadContents:configFile];
}

- (BOOL)loadContents:(NSString *)contentString {
	[config removeAllObjects];
    [contents removeAllObjects];
	
	GPGConfReader *reader = [GPGConfReader readerForDomain:self.optionsDomain];
    NSMutableArray *saveLines = [NSMutableArray arrayWithCapacity:0];
	NSCharacterSet *whitespaces = [NSCharacterSet whitespaceCharacterSet];
    BOOL lastLineWasEmpty = FALSE;
	
    NSMutableArray *lines = [NSMutableArray arrayWithArray:[contentString componentsSeparatedByString:@"\n"]];
    // if configFile ends with a newline, one split line is spurious
    if ([contentString hasSuffix:@"\n"])
        [lines removeObjectAtIndex:[lines count] - 1];
	
	for (NSString *line in lines) {
        GPGStdSetting *setting = [reader buildForLine:line];
        if (!setting) {
            // An empty line is noted; may later checkpoint saved lines and clear
            NSString *trimmed = [line stringByTrimmingCharactersInSet:whitespaces];
            if ([trimmed length] < 1) {
                lastLineWasEmpty = TRUE;
                [saveLines addObject:line];
            }
            else if (lastLineWasEmpty) {
                lastLineWasEmpty = FALSE;
                [contents addObjectsFromArray:saveLines];
                [saveLines removeAllObjects];
                [saveLines addObject:line];
            }
            else {
                [saveLines addObject:line];
            }
            
            continue;
        }
		
        lastLineWasEmpty = FALSE;
        
        // Append to existing settings if already mapped
        GPGStdSetting *extant = [config objectForKey:setting.key];
        if (!extant) {
            extant = setting;
            [config setObject:setting forKey:setting.key];
            [contents addObject:setting];
        }
		
        // Append any savedLines
        for (NSString *nsaved in saveLines) {
            [extant appendLine:nsaved withReader:reader];
        }
        [saveLines removeAllObjects];
		
        // Append the current line
        [extant appendLine:line withReader:reader];
	}
	
    // Checkpoint any savedLines
    [contents addObjectsFromArray:saveLines];
    [saveLines removeAllObjects];
	
	return YES;
}


- (NSString *)loadConfigFileXPC {
	GPGTaskHelperXPC *taskHelper = [[GPGTaskHelperXPC alloc] init];
	NSString *content = nil;
	
	@try {
		content = [taskHelper loadConfigFileAtPath:path];
	}
	@catch (NSException *exception) {
	}
	@finally {
		[taskHelper release];
	}
	
	return content;
}

+ (id)confWithPath:(NSString *)aPath {
	return [[[[self class] alloc] initWithPath:aPath] autorelease];
}

- (id)initWithPath:(NSString *)aPath {
    return [self initWithPath:aPath andDomain:GPGDomain_gpgConf];
}

- (id)initWithPath:(NSString *)aPath andDomain:(GPGOptionsDomain)domain {
	if ((self = [super init]) == nil) {
		return nil;
	}

	self.path = aPath;
    self.optionsDomain = domain;
    config = [[NSMutableDictionary alloc] init];
    contents = [[NSMutableArray alloc] init];
	
	if (![self loadConfig]) {
		[self release];
		return nil;
	}
	
	return self;
}
- (id)init {
    return [self initWithPath:nil];
}
- (void)dealloc {
	[config release];
	[contents release];
	self.path = nil;
    [super dealloc];
}

@end

/*
 config	is a NSMutableDictionary, it can contain GPGStdSetting objects
 contents contains the objects in config but also unassociated comments from .conf
 
 Samples:
 
 keyserver pgp.mit.edu						NSstring		@"pgp.mit.edu"
 ask-cert-level								NSNumber		YES
 no-version									NSNumber		NO	(The key in config is "version"!)
 list-options show-photos show-keyring		NSArray			@"show-photos", @"show-keyring"
 group xyz=00D026C4 FB3B1734				NSDictionary	xyz = NSArray(@"00D026C4", @"FB3B1734")
 comment Comment Line 1						NSArray			(@"Comment Line 1")
 

*/








