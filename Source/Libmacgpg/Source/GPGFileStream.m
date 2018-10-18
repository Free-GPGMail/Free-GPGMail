//
//  GPGFileStream.m
//  Libmacgpg
//
//  Created by Chris Fraire on 5/21/12.
//  Copyright (c) 2012 Chris Fraire. All rights reserved.
//

#import "GPGFileStream.h"


@interface GPGFileStream ()
// might be called (internally) for a writeable stream after writing
- (void)openForReading;
@end

@implementation GPGFileStream

- (void)dealloc
{
    [_filepath release];
    [_fh release];
    [_readfh release];
	[_cacheData release];
    [super dealloc];
}

- (id)init {
    return [self initForWritingAtPath:nil error:nil];
}

+ (id)fileStreamForWritingAtPath:(NSString *)path {
    NSError *error = nil;
    id newObject = [[[self alloc] initForWritingAtPath:path error:&error] autorelease];
	if (error) {
        return nil;
	}
    return newObject;
}

+ (id)fileStreamForReadingAtPath:(NSString *)path {
    NSError *error = nil;
    id newObject = [[[self alloc] initForReadingAtPath:path error:&error] autorelease];
	if (error) {
        return nil;
	}
    return newObject;
}

- (id)initForWritingAtPath:(NSString *)path error:(NSError **)error {
	self = [super init];
	if (!self) {
		return nil;
	}
	
	if (!path) {
		[self release];
		return nil;
	}

	_filepath = [path retain];

	_fh = [[NSFileHandle fileHandleForWritingAtPath:path] retain];
	if (!_fh) {
		if (error) {
			*error = [NSError errorWithDomain:@"libc" code:0 userInfo:nil];
		}
		[self release];
		return nil;
	}

    return self;
}

- (id)initForReadingAtPath:(NSString *)path error:(NSError **)error {
	self = [super init];
	if (!self) {
		return nil;
	}
	
	if (!path) {
		[self release];
		return nil;
	}
	
	_filepath = [path retain];
	
	[self openForReading];
	if (!_readfh) {
		if (error) {
			*error = [NSError errorWithDomain:@"libc" code:0 userInfo:nil];
		}
		[self release];
		return nil;
	}
	
    return self;
}

- (void)writeData:(NSData *)data
{
	if (_readfh) {
        @throw [NSException exceptionWithName:@"InvalidOperationException" reason:@"stream is readable" userInfo:nil];
	}
    [_fh writeData:data];
}

- (NSData *)readDataToEndOfStream {
	if (!_readfh) {
        [self openForReading];
	}
	if (_realOffset != NSUIntegerMax) {
		_cacheAvailableBytes = 0;
		[_readfh seekToFileOffset:_realOffset];
		_realOffset = NSUIntegerMax;
	}

	return [_readfh readDataToEndOfFile];
}

- (NSData *)readDataOfLength:(NSUInteger)length {
	if (!_readfh) {
		[self openForReading];
	}
	if (_realOffset != NSUIntegerMax) {
		_cacheAvailableBytes = 0;
		[_readfh seekToFileOffset:_realOffset];
		_realOffset = NSUIntegerMax;
	}

    return [_readfh readDataOfLength:length];
}

- (NSData *)readAllData {
	if (!_readfh) {
        [self openForReading];
	}
	_cacheAvailableBytes = 0;
	_realOffset = NSUIntegerMax;
	
    [_readfh seekToFileOffset:0];
    return [_readfh readDataToEndOfFile];
}

- (NSInteger)readByte {
	const NSUInteger cacheSize = 1024;
	
	if (!_readfh) {
		[self openForReading];
	}
	
	if (_cacheAvailableBytes == 0) {
		_cacheLocation = 0;
		
		if (_realOffset == NSUIntegerMax) {
			_realOffset = _readfh.offsetInFile;
		}
		
		[_cacheData release];
		_cacheData = [[_readfh readDataOfLength:cacheSize] retain];
		
		_cacheAvailableBytes = _cacheData.length;
		if (_cacheAvailableBytes == 0) {
			return EOF;
		}
		
		_cacheBytes = _cacheData.bytes;
	}
	
	_realOffset++;
	_cacheAvailableBytes--;
	return _cacheBytes[_cacheLocation++];
}

- (char)peekByte {
	if (!_readfh) {
		[self openForReading];
	}

    unsigned long long currentPos = [_readfh offsetInFile];
    NSData *peek = [_readfh readDataOfLength:1];
    [_readfh seekToFileOffset:currentPos];

    if (peek && [peek length])
        return *(char *)[peek bytes];
    return 0;
}

- (void)close 
{
    [_fh closeFile];
    if (_readfh) {
        [_readfh closeFile];
        // release and nil so it could be re-opened if necessary
        [_readfh release];
        _readfh = nil;
    }
}

- (void)flush {
    [_fh synchronizeFile];
}

- (void)seekToBeginning 
{
    if (_fh) {
        [_fh truncateFileAtOffset:0];
    }
    if (_readfh) {
        [_readfh seekToFileOffset:0];
    }
}
- (void)seekToOffset:(NSUInteger)offset {
	if (_fh) {
		if (offset > _fh.offsetInFile) {
			@throw [NSException exceptionWithName:NSRangeException reason:[NSString stringWithFormat:@"offset %lu exceeds file length", (unsigned long)offset] userInfo:nil];
		}
		[_fh truncateFileAtOffset:offset];
	}
	if (_readfh) {
		if (offset > _flength) {
			@throw [NSException exceptionWithName:NSRangeException reason:[NSString stringWithFormat:@"offset %lu exceeds file length", (unsigned long)offset] userInfo:nil];
		}
		[_readfh seekToFileOffset:offset];
	}
}
- (NSUInteger)offset {
	if (_fh) {
		return _fh.offsetInFile;
	}
	if (_readfh) {
		return _readfh.offsetInFile;
	}
	return NSIntegerMax;
}


- (unsigned long long)length
{
	if (_readfh) {
        return _flength;
	}
    return [_fh offsetInFile];
}

#pragma mark - private

- (void)openForReading 
{
    if (_fh) {
        [_fh closeFile];
        [_fh release];
        _fh = nil;
    }
    if (!_readfh) {
        _readfh = [[NSFileHandle fileHandleForReadingAtPath:_filepath] retain];
        _flength = [_readfh seekToEndOfFile];
        [_readfh seekToFileOffset:0];
		_realOffset = NSUIntegerMax;
    }
}

@end
