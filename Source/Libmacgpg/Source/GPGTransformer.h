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


@interface GPGKeyAlgorithmNameTransformer : NSValueTransformer {
    BOOL _keepUnlocalized; // default NO; used for Unit Testing
}
// default NO
@property (nonatomic, assign) BOOL keepUnlocalized;

- (id)transformedIntegerValue:(NSInteger)value;
@end

@interface GPGHashAlgorithmNameTransformer : NSValueTransformer {
	BOOL _keepUnlocalized; // default NO; used for Unit Testing
}
// default NO
@property (nonatomic, assign) BOOL keepUnlocalized;

- (id)transformedIntegerValue:(NSInteger)value;
@end

@interface GPGValidityDescriptionTransformer : NSValueTransformer {
    BOOL _keepUnlocalized; // default NO; used for Unit Testing
}
// default NO
@property (nonatomic, assign) BOOL keepUnlocalized;
@end

@interface GPGFingerprintTransformer : NSValueTransformer {
    BOOL _keepUnlocalized; // default NO; used for Unit Testing
}
// default NO
@property (nonatomic, assign) BOOL keepUnlocalized;
@end

@interface GPGNoBreakFingerprintTransformer : GPGFingerprintTransformer
+ (id)sharedInstance;
@end


DEPRECATED_ATTRIBUTE @interface SplitFormatter : NSFormatter {
	NSInteger blockSize;
}
@property (nonatomic) NSInteger blockSize;
@end


@interface NSNumber (GPGValidityCompare)
// Compare two GPGValidity NSNumbers.
- (NSComparisonResult)compareGPGValidity:(NSNumber *)otherNumber;
@end

