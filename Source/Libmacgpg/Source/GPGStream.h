//
//  GPGStream.h
//  Libmacgpg
//
//  Created by Chris Fraire on 5/21/12.
//  Copyright (c) 2012 Chris Fraire. All rights reserved.
//



// Abstract class for writing buffered data to a managed location
@interface GPGStream : NSObject

// append the specified data to the stream
- (void)writeData:(NSData *)data;

// read in to memory all the data from the current position to the end
- (NSData *)readDataToEndOfStream;
// read in to memory from the current position up to the specified length
- (NSData *)readDataOfLength:(NSUInteger)length;
// (re)read all data from the stream
- (NSData *)readAllData;
/**
 Read the next byte from the stream.
 @returns The next byte or EOF.
*/
- (NSInteger)readByte;
// return the character at the next position, without advancing position
- (char)peekByte;

// close the stream's underlying representation, when applicable
- (void)close;
// flush the underlying representation, when applicable
- (void)flush;
// seek the underlying representation back to the beginning; 
// for a writeable stream, this truncates all data
- (void)seekToBeginning;
// seek the underlying representation to the given offset;
// for a writeable stream, this truncates to the given offeset
- (void)seekToOffset:(NSUInteger)offset;
// the current offset in the stream.
- (NSUInteger)offset;

// readable streams may indicate total length; 
// writeable streams may indicate length written;
- (unsigned long long)length;

@end
