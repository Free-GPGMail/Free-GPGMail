//
//  Paddle+CustomBundleIdentifier.h
//  GSPaddle
//
//  Created by Lukas Pitschl on 29.01.18.
//  Copyright © 2018 Lukas Pitschl. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Paddle/Paddle.h>

@interface NSFileManager (CustomBundleIdentifier)

- (id)GSCustomBundleIdentifier;
- (void)GSSetCustomBundleIdentifier:(NSString *)customBundleIdentifier;

@end
