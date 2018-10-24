//
//  PADApi+GSPaddle.h
//  GSPaddle
//
//  Created by Lukas Pitschl on 27.09.18.
//  Copyright © 2018 Lukas Pitschl. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PADApi_GSPaddle : NSObject

@end

@interface Paddle (GSPaddleMore)

- (NSError *)activationErrorForActivationCode:(NSString *)activationCode;
- (void)setActivationError:(NSError *)error forActivationCode:(NSString *)activationCode;

@end
