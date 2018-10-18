//
//  GPGMemoryStream.m
//  Libmacgpg
//
//  Created by Chris Fraire on 5/21/12.
//  Copyright (c) 2012 Chris Fraire. All rights reserved.
//

#import "GPGMemoryStream.h"

@interface GPGMemoryStream ()
// might be called (internally) for a writeable stream after writing
- (void)openForReading;
@end

@implementation GPGMemoryStream

- (void)dealloc 
{
    [_data release];
    [_readableData release];
    [super dealloc];
}

- (id)init 
{
    if (self = [super init]) {
        _data = [[NSMutableData data] retain];
        // _readableData stays nil
    }
    return self;
}

- (id)initForReading:(NSData *)data
{
    if (self = [super init]) {
        // _data stays nil
        _readableData = [[NSData dataWithData:data] retain];
		_readableBytes = _readableData.bytes;
		_readableLength = _readableData.length;
    }
    return self;
}

+ (id)memoryStream 
{
    return [[[self alloc] init] autorelease];
}

+ (id)memoryStreamForReading:(NSData *)data
{
    return [[[self alloc] initForReading:data] autorelease];
}

- (void)writeData:(NSData *)data
{
	if (!_data) {
        @throw [NSException exceptionWithName:@"InvalidOperationException" reason:@"stream is readable" userInfo:nil];
	}
    [_data appendData:data];
}

- (NSData *)readDataToEndOfStream
{
	if (!_readableData) {
		[self openForReading];
	}

    NSUInteger rlength = [_readableData length];
    if (_readPos >= rlength)
        return [NSData data];

    NSData *result = [_readableData subdataWithRange:NSMakeRange(_readPos, rlength - _readPos)];
    _readPos = rlength;
    return result;
}

- (NSData *)readDataOfLength:(NSUInteger)length
{
	if (!_readableData) {
		[self openForReading];
	}
	
    NSUInteger rlength = [_readableData length];
    if (_readPos >= rlength)
        return [NSData data];

    NSUInteger nextLength = MIN(length, rlength - _readPos);
    NSData *result = [_readableData subdataWithRange:NSMakeRange(_readPos, nextLength)];
    _readPos += nextLength;
    return result;
}

- (NSData *)readAllData 
{
	if (!_readableData) {
		[self openForReading];
	}

    return _readableData;
}

- (NSInteger)readByte {
	if (!_readableData) {
		[self openForReading];
	}
	if (_readPos >= _readableLength) {
		return EOF;
	}
	return _readableBytes[_readPos++]; // Post-increment.
}

- (char)peekByte 
{
	if (!_readableData) {
        [self openForReading];
	}

    unsigned long long rlength = [_readableData length];
    if (_readPos >= rlength)
        return 0;

    char buf[1] = {0};
    [_readableData getBytes:&buf range:NSMakeRange(_readPos, 1)];
    return buf[0];
}

/// flush does nothing special

/// close does nothing special

- (void)seekToBeginning
{
	if (_data) {
        [_data setLength:0];
	}
	if (_readableData) {
        _readPos = 0;
	}
}
- (void)seekToOffset:(NSUInteger)offset {
	if (_data) {
		if (offset > _data.length) {
			@throw [NSException exceptionWithName:NSRangeException reason:[NSString stringWithFormat:@"offset %lu exceeds data length", (unsigned long)offset] userInfo:nil];
		}
		[_data setLength:offset];
	}
	if (_readableData) {
		if (offset > _readableData.length) {
			@throw [NSException exceptionWithName:NSRangeException reason:[NSString stringWithFormat:@"offset %lu exceeds data length", (unsigned long)offset] userInfo:nil];
		}
		_readPos = offset;
	}
}
- (NSUInteger)offset {
	if (_data) {
		return _data.length;
	}
	if (_readableData) {
		return _readPos;
	}
	return NSIntegerMax;
}

- (unsigned long long)length
{
	if (_readableData) {
        return [_readableData length];
	}
    return [_data length];
}

#pragma mark - private

- (void)openForReading 
{
	if (!_readableData) {
        _readableData = [[NSData dataWithData:_data] retain];
		_readableBytes = _readableData.bytes;
		_readableLength = _readableData.length;
	}
    if (_data) {
        [_data release];
        _data = nil;
    }
}

@end
