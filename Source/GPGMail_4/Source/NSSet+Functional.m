//
//  NSSet+Functional.m
//  GPGMail
//
//  Created by Lukas Pitschl on 15.06.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "NSSet+Functional.h"

@implementation NSSet (Functional)

- (NSSet *)filter:(id (^)(id))block {
    NSMutableSet *set = [NSMutableSet set];
    for(id obj in self) {
        id ret = block(obj);
        if(!ret) continue;
        [set addObject:obj];
    }
    return [NSSet setWithSet:set];
}

@end
