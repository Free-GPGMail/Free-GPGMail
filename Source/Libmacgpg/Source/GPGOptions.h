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

#import <SystemConfiguration/SCPreferences.h>

@class GPGConf;

extern NSString * const GPGKeysFromVerifyingKeyserverKey;
extern NSString * const GPGUseSKSKeyserverAsBackupKey;


typedef enum {
	GPGDomain_standard = 0,
	GPGDomain_common = 1,
	GPGDomain_gpgConf = 3,
	GPGDomain_gpgAgentConf = 4,
	GPGDomain_special = 5, //special is not a real domain.
	GPGDomain_dirmngrConf = 6
} GPGOptionsDomain;

@interface GPGOptions : NSObject {
	BOOL initialized;
	NSMutableDictionary *standardDefaults;
	NSMutableDictionary *commonDefaults;
	NSString *httpProxy;
	BOOL autoSave;
	NSString *standardDomain;
	NSString *_pinentryPath;
	
	
	GPGConf *gpgConf;
	GPGConf *gpgAgentConf;
	GPGConf *dirmngrConf;
	NSString *identifier;
	NSUInteger updating;
    
    SCPreferencesRef preferences;
    id syncRoot;
}

@property (nonatomic, readonly) NSString *httpProxy;
@property (nonatomic, readonly) NSString *gpgHome;
@property (nonatomic, retain) NSArray *keyservers;
@property (nonatomic, retain) NSString *keyserver;
@property (nonatomic) BOOL autoSave;
@property (nonatomic, retain) NSString *standardDomain;
@property (nonatomic, readonly) BOOL debugLog;
@property (nonatomic, readonly) NSString *pinentryPath;

/*
 * Returns YES if the current keyserver supports the Verifying Keyserver Interface.
 * Currently only YES for keys.openpgp.org
 */
@property (nonatomic, readonly) BOOL isVerifyingKeyserver;
+ (BOOL)isVerifyingKeyserver:(NSString *)keyserver;


/*
 * Returns YES if the current keyserver is one of the old SKS keyservers.
 */
@property (nonatomic, readonly) BOOL isSKSKeyserver;
- (BOOL)isSKSKeyserver:(NSString *)keyserver;



+ (BOOL)debugLog;

+ (instancetype)sharedOptions;
- (id)valueForKey:(NSString *)key;
- (void)setValue:(id)value forKey:(NSString *)key;

- (id)valueForKey:(NSString *)key inDomain:(GPGOptionsDomain)domain;
- (void)setValue:(id)value forKey:(NSString *)key inDomain:(GPGOptionsDomain)domain;

- (void)registerDefaults:(NSDictionary *)dictionary;

- (void)setObject:(id)value forKey:(NSString *)key;
- (id)objectForKey:(NSString *)key;
- (void)setInteger:(NSInteger) value forKey:(NSString *)key;
- (NSInteger)integerForKey:(NSString *)key;
- (void)setBool:(BOOL) value forKey:(NSString *)key;
- (BOOL)boolForKey:(NSString *)key;
- (void)setFloat:(float)value forKey:(NSString *)key;
- (float)floatForKey:(NSString *)key;
- (NSString *)stringForKey:(NSString *)key;
- (NSArray *)arrayForKey:(NSString *)key;


- (id)valueInStandardDefaultsForKey:(NSString *)key;
- (void)setValueInStandardDefaults:(id)value forKey:(NSString *)key;
- (void)saveStandardDefaults;

- (id)valueInCommonDefaultsForKey:(NSString *)key;
- (void)setValueInCommonDefaults:(id)value forKey:(NSString *)key;
- (void)saveCommonDefaults;

- (id)specialValueForKey:(NSString *)key;
- (void)setSpecialValue:(id)value forKey:(NSString *)key;

- (id)valueInGPGConfForKey:(NSString *)key;
- (void)setValueInGPGConf:(id)value forKey:(NSString *)key;

- (id)valueInGPGAgentConfForKey:(NSString *)key;
- (void)setValueInGPGAgentConf:(id)value forKey:(NSString *)key;

- (id)valueInDirmngrConfForKey:(NSString *)key;
- (void)setValueInDirmngrConf:(id)value forKey:(NSString *)key;


- (void)addKeyserver:(NSString *)keyserver;
- (void)removeKeyserver:(NSString *)keyserver;


- (void)dirmngrFlush;

- (void)gpgAgentFlush;
- (void)gpgAgentTerminate;

+ (NSString *)standardizedKey:(NSString *)key;
- (GPGOptionsDomain)domainForKey:(NSString *)key;
+ (BOOL)isKnownKey:(NSString *)key inDomain:(GPGOptionsDomain)domain;
- (void)repairGPGConf;

@end
