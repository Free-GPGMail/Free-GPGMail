//
//  NSAttributedString+LOKit.m
//  LOKit
//
//  Created by Christopher Atlan on 26.12.17.
//  Copyright © 2017 Christopher Atlan. All rights reserved.
//

#import "NSAttributedString+LOKit.h"



@implementation NSAttributedString (LOKit)

+ (instancetype)lo_attributedStringWithBaseAttributes:(nullable NSDictionary<NSAttributedStringKey, id> *)attrs argumentAttributes:(nullable NSDictionary<NSAttributedStringKey, id> *)argAttrs formatString:(NSString *)formatString, ...
{
    va_list args;
    va_start(args, formatString);
    NSString *str = [[NSString alloc] initWithFormat:formatString arguments:args];
    va_end(args);
    
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:str attributes:attrs];
    
    va_start(args, formatString);
    for (NSString *arg = formatString; arg != nil; arg = va_arg(args, NSString *))
    {
        if (arg == formatString) continue; // Ignore first argument, aka the formatString.
        
        NSRange range = [str rangeOfString:arg];
        if (range.location != NSNotFound)
        {
            [attributedString addAttributes:argAttrs range:range];
        }
    }
    va_end(args);
    
    return [attributedString copy];
}

@end
