//
//  NSPipe+NoSigPipe.h
//  Libmacgpg
//
//  Created by Lukas Pitschl on 03.06.12.
//  Copyright (c) 2014 Lukas Pitschl. All rights reserved.
//

#import <Foundation/Foundation.h>

// a little category to fcntl F_SETNOSIGPIPE on each fd
@interface NSPipe (SetNoSIGPIPE)
- (NSPipe *)noSIGPIPE;
@end
