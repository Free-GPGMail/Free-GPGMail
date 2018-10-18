//
//  NSPipe+NoSigPipe.m
//  Libmacgpg
//
//  Created by Lukas Pitschl on 03.06.12.
//  Copyright (c) 2014 Lukas Pitschl. All rights reserved.
//

#import "NSPipe+NoSigPipe.h"

@implementation NSPipe (SetNoSIGPIPE)

#ifndef F_SETNOSIGPIPE
#define F_SETNOSIGPIPE		73	/* No SIGPIPE generated on EPIPE */
#endif
#define FCNTL_SETNOSIGPIPE(fd) (fcntl(fd, F_SETNOSIGPIPE, 1))

- (NSPipe *)noSIGPIPE 
{
    FCNTL_SETNOSIGPIPE([[self fileHandleForReading] fileDescriptor]);
    FCNTL_SETNOSIGPIPE([[self fileHandleForWriting] fileDescriptor]);
    return self;
}

@end
