/*
 * Copyright © Roman Zechmeister, 2010
 *
 * Dieses Programm ist freie Software. Sie können es unter den Bedingungen
 * der GNU General Public License, wie von der Free Software Foundation
 * veröffentlicht, weitergeben und/oder modifizieren, entweder gemäß
 * Version 3 der Lizenz oder (nach Ihrer Option) jeder späteren Version.
 *
 * Die Veröffentlichung dieses Programms erfolgt in der Hoffnung, daß es Ihnen
 * von Nutzen sein wird, aber ohne irgendeine Garantie, sogar ohne die implizite
 * Garantie der Marktreife oder der Verwendbarkeit für einen bestimmten Zweck.
 * Details finden Sie in der GNU General Public License.
 *
 * Sie sollten ein Exemplar der GNU General Public License zusammen mit diesem
 * Programm erhalten haben. Falls nicht, siehe <http://www.gnu.org/licenses/>.
 */

#import <Cocoa/Cocoa.h>
#import <Libmacgpg/Libmacgpg.h>

@interface GPGDefaults : NSObject {
	NSString *_domain;
	NSMutableDictionary *_defaults;
	NSLock *_defaultsLock;
	NSSet *_defaultDictionarys;
}

@property (retain) NSString *domain;

+ (id)gpgDefaults;
+ (id)standardDefaults;
+ (id)defaultsWithDomain:(NSString *)domain;
- (id)initWithDomain:(NSString *)aDomain;

- (void)setObject:(id) value forKey:(NSString *)defaultName;
- (id)objectForKey:(NSString *)defaultName;
- (void)removeObjectForKey:(NSString *)defaultName;

- (void)setInteger:(NSInteger) value forKey:(NSString *)defaultName;
- (NSInteger)integerForKey:(NSString *)defaultName;

- (void)setBool:(BOOL) value forKey:(NSString *)defaultName;
- (BOOL)boolForKey:(NSString *)defaultName;

- (void)setFloat:(float)value forKey:(NSString *)defaultName;
- (float)floatForKey:(NSString *)defaultName;

- (NSString *)stringForKey:(NSString *)defaultName;

- (NSArray *)arrayForKey:(NSString *)defaultName;

- (NSDictionary *)dictionaryRepresentation;

- (void)registerDefaults:(NSDictionary *)dictionary;

@end


@interface GPGAgentOptions : GPGOptions {}

+ (void)gpgAgentFlush;

@end

