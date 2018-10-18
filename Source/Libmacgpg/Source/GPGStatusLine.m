//
//  GPGStatusLine.m
//  Libmacgpg
//
//  Created by Mento on 30.05.18.
//

#import "GPGStatusLine.h"

@implementation GPGStatusLine

+ (instancetype)statusLineWithKeyword:(NSString *)keyword code:(NSInteger)code parts:(NSArray *)parts {
	return [[[self alloc] initWithKeyword:keyword code:code parts:parts] autorelease];
}

- (instancetype)initWithKeyword:(NSString *)keyword code:(NSInteger)code parts:(NSArray *)parts {
	self = [super init];
	if (!self) {
		return nil;
	}
	
	_keyword = [keyword copy];
	_code = code;
	_parts = [parts copy];

	return self;
}

- (void)dealloc {
	[_keyword release];
	[_parts release];
	[super dealloc];
}

- (NSString *)description {
	return [NSString stringWithFormat:@"%li %@ %@", (long)self.code, self.keyword, self.parts];
}

@end
