//
//  GPGUTF8Argument.m
//  Libmacgpg
//
//  Created by Mento on 25.07.18.
//

#import "GPGUTF8Argument.h"

@interface GPGUTF8Argument ()
@property (nonatomic, strong) NSString *realString;
@end

@implementation GPGUTF8Argument
- (const char *)fileSystemRepresentation {
	// Return the string as a utf-8 encoded string, because gpg wants utf-8 encoded umlauts.
	return self.realString.UTF8String;
}
- (instancetype)initWithCharactersNoCopy:(unichar *)characters length:(NSUInteger)length freeWhenDone:(BOOL)freeBuffer {
	self = [super init];
	if (self) {
		self.realString = [[[NSString alloc] initWithCharactersNoCopy:characters length:length freeWhenDone:freeBuffer] autorelease];
	}
	return self;
}
- (NSUInteger)length {
	return self.realString.length;
}
- (unichar)characterAtIndex:(NSUInteger)index {
	return [self.realString characterAtIndex:index];
}
- (void)dealloc {
	self.realString = nil;
	[super dealloc];
}
@end
