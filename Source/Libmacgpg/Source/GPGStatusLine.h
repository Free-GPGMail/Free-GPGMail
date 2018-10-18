//
//  GPGStatusLine.h
//  Libmacgpg
//
//  Created by Mento on 30.05.18.
//

@interface GPGStatusLine : NSObject
@property (readonly, nonatomic) NSString *keyword;
@property (readonly, nonatomic) NSInteger code;
@property (readonly, nonatomic) NSArray *parts;

+ (instancetype)statusLineWithKeyword:(NSString *)keyword code:(NSInteger)code parts:(NSArray *)parts;
- (instancetype)initWithKeyword:(NSString *)keyword code:(NSInteger)code parts:(NSArray *)parts;

@end
