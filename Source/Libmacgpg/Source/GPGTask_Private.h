//
//  GPGTask_Private.h
//  Libmacgpg
//
//  Created by Mento on 12.06.18.
//

@interface GPGTask ()

@property (nonatomic, retain) NSData *errData;
@property (nonatomic, retain) NSData *statusData;
@property (nonatomic, retain) NSData *attributeData;
@property (nonatomic) int errorCode;

- (void)unsetErrorCode:(int)value;

@end

