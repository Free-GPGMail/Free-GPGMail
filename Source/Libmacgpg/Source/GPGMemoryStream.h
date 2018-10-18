//
//  GPGMemoryStream.h
//  Libmacgpg
//
//  Created by Chris Fraire on 5/21/12.
//  Copyright (c) 2012 Chris Fraire. All rights reserved.
//

#import <Libmacgpg/GPGStream.h>

// you can call the read methods of GPGStream on a writeable 
// GPGFileStream, at which point it will convert to a readable
// stream (from offset 0) and no longer be writeable
@interface GPGMemoryStream : GPGStream {
    NSMutableData *_data;
    NSData *_readableData;
    NSUInteger _readPos;
	const UInt8 *_readableBytes;
	NSUInteger _readableLength;
}

// return a new, autoreleased memory stream
+ (id)memoryStream;
// return a new, autoreleased memory stream atop the specified data 
+ (id)memoryStreamForReading:(NSData *)data;

- (id)initForReading:(NSData *)data;

@end
