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

#import <Cocoa/Cocoa.h>

@class GPGTask;
@class GPGTaskHelper;
@class GPGStream;
@class GPGStatusLine;


extern NSString * const GPGStatusFilePlaceholder;
extern NSString * const GPGAttributeFilePlaceholder;


@protocol GPGTaskDelegate
@optional
//Should return NSData or NSString, it is passed to GPG.
- (id)gpgTask:(GPGTask *)gpgTask statusCode:(NSInteger)status prompt:(NSString *)prompt;

- (void)gpgTask:(GPGTask *)gpgTask progressed:(NSInteger)progressed total:(NSInteger)total;
- (void)gpgTaskWillStart:(GPGTask *)gpgTask;
- (void)gpgTaskDidTerminate:(GPGTask *)gpgTask;


@end


@interface GPGTask : NSObject {
	NSMutableArray *arguments;
	BOOL batchMode;
	NSObject <GPGTaskDelegate> *delegate;
	NSDictionary *userInfo;
	NSInteger exitcode;
	int errorCode;
	NSMutableArray<NSNumber *> *errorCodes;
	BOOL getAttributeData;
	NSDictionary *_environmentVariables;
	
	GPGStream *inData;
	NSString *passphrase;
	
    GPGTaskHelper *taskHelper;
    
    GPGStream *outStream;
	NSData *errData;
	NSData *statusData;
	NSData *attributeData;
	
	NSString *outText;
	NSString *errText;
	NSString *statusText;
	
	BOOL cancelled;
	BOOL isRunning;
	BOOL nonBlocking;
	
	BOOL progressInfo;
	
	NSMutableDictionary *statusDict;
	NSMutableArray <GPGStatusLine *> *statusArray;
	NSUInteger timeout;
}

@property (nonatomic, readonly) BOOL cancelled;
@property (nonatomic, readonly) BOOL isRunning;
@property (nonatomic, readonly) NSDictionary *statusDict;
@property (nonatomic, readonly) NSArray <GPGStatusLine *> *statusArray;
@property (nonatomic) BOOL progressInfo;
@property (nonatomic) BOOL batchMode;
@property (nonatomic) BOOL getAttributeData;
@property (nonatomic, unsafe_unretained) NSObject <GPGTaskDelegate> *delegate;
@property (nonatomic, strong) NSDictionary *userInfo;
@property (nonatomic, strong) NSString *passphrase;
@property (nonatomic, readonly) NSInteger exitcode;
@property (nonatomic, readonly) int errorCode;
@property (nonatomic, readonly) NSArray *errorCodes;
@property (nonatomic, readonly) int fullErrorCode;
// if not set before starting, GPGTask will use a GPGMemoryStream
@property (nonatomic, retain) GPGStream *outStream;
@property (nonatomic, readonly, retain) NSData *errData;
@property (nonatomic, readonly, retain) NSData *statusData;
@property (nonatomic, readonly, retain) NSData *attributeData;
@property (nonatomic, readonly) NSString *outText;
@property (nonatomic, readonly) NSString *errText;
@property (nonatomic, readonly) NSString *statusText;
@property (nonatomic, readonly) NSArray *arguments;
@property (nonatomic, readonly) GPGTaskHelper *taskHelper;
@property (nonatomic, assign) NSUInteger timeout;
@property (nonatomic, retain) NSDictionary *environmentVariables;
@property (nonatomic, assign) BOOL nonBlocking;


+ (NSString *)nameOfStatusCode:(NSInteger)statusCode;

- (void)addArgument:(NSString *)argument;
- (void)addArguments:(NSArray *)args;

- (NSInteger)start;

- (NSData *)outData;
- (void)setInput:(GPGStream *)stream;
- (void)setInData:(NSData *)data;
- (void)setInText:(NSString *)string;

- (void)cancel;

+ (id)gpgTaskWithArguments:(NSArray *)args batchMode:(BOOL)batch;
+ (id)gpgTaskWithArguments:(NSArray *)args;
+ (id)gpgTaskWithArgument:(NSString *)arg;
+ (id)gpgTask;


- (id)initWithArguments:(NSArray *)args batchMode:(BOOL)batch;
- (id)initWithArguments:(NSArray *)args;
- (id)initWithArgument:(NSString *)arg;

- (void)logDataContent:(NSData *)data message:(NSString *)message;

+ (BOOL)launchGeneralTask:(NSString *)path withArguments:(NSArray *)arguments;
+ (BOOL)launchGeneralTask:(NSString *)path withArguments:(NSArray *)arguments wait:(BOOL)wait;

/**
 * Opens GPG Suite Preferences.
 *
 * @param tab (optional) the tab to show. One of "settings", "report" or "about".
 * @param arguments reserved for future use.
 * @return YES if GPG Suite Preferences was successfully shown.
 */
+ (BOOL)showGPGSuitePreferencesTab:(NSString *)tab arguments:(NSDictionary *)arguments;
/**
 * Get the arguments, passed to GPG Suite Preferences via temp file.
 * Removes the file after reading, so call it once and store it's return value, if needed later.
 *
 * @return The arguments from the temp file.
 */
+ (NSDictionary *)readGPGSuitePreferencesArguments;


/**
 Check if the application Libmacgpg is used with is sandboxed.
 */
+ (BOOL)sandboxed;

@end
