//
//  GPGFileStream.h
//  Libmacgpg
//
//  Created by Chris Fraire on 5/21/12.
//  Copyright (c) 2012 Chris Fraire. All rights reserved.
//

#import <Libmacgpg/GPGStream.h>

// you can call the read methods of GPGStream on a writeable 
// GPGFileStream, at which point it will convert to a readable
// stream (from offset 0) and no longer be writeable
@interface GPGFileStream : GPGStream {
    NSString *_filepath;
    // for writing
    NSFileHandle *_fh;
    // for reading
    NSFileHandle *_readfh;
    // for readable files
    unsigned long long _flength;
	
	// cache to speed-up byte wise reading.
	NSData *_cacheData;
	const UInt8 *_cacheBytes;
	NSUInteger _cacheLocation;
	NSUInteger _cacheAvailableBytes;
	NSUInteger _realOffset;
	
}

// returns nil if creating file for writing failed
+ (id)fileStreamForWritingAtPath:(NSString *)path;
// returns nil if opening file for reading failed
+ (id)fileStreamForReadingAtPath:(NSString *)path;

- (id)initForWritingAtPath:(NSString *)path error:(NSError **)error;
- (id)initForReadingAtPath:(NSString *)path error:(NSError **)error;

@end
