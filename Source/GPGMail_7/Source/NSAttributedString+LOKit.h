//
//  NSAttributedString+LOKit.h
//  LOKit
//
//  Created by Christopher Atlan on 26.12.17.
//  Copyright © 2017 Christopher Atlan. All rights reserved.
//

#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif

@interface NSAttributedString (LOKit)

+ (instancetype)lo_attributedStringWithBaseAttributes:(NSDictionary<NSAttributedStringKey, id> *)attrs argumentAttributes:(NSDictionary<NSAttributedStringKey, id> *)argAttrs formatString:(NSString *)formatString, ... NS_REQUIRES_NIL_TERMINATION;

@end
