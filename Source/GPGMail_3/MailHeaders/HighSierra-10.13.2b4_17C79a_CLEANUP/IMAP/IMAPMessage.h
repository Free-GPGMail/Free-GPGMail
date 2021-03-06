//
//     Generated by class-dump 3.5 (64 bit).
//
//     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2013 by Steve Nygard.
//

#import "MCRemoteMessage.h"

#import "IMAPMessage-Protocol.h"

@class NSDate, NSString;

@interface IMAPMessage : MCRemoteMessage <IMAPMessage>
{
    unsigned int _uid;
    long long _originalFlags;
}

+ (void)initialize;
@property(readonly, nonatomic) long long originalFlags; // @synthesize originalFlags=_originalFlags;
- (void)setDataSource:(id)arg1;
@property(readonly) id /*<IMAPMessageDataSource>*/ dataSource;
@property(readonly, nonatomic) id /*<IMAPAccount>*/ account;
@property(readonly, copy) NSString *subject;
- (id)remoteMailboxURLString;
- (id)remoteID;
@property(readonly, copy, nonatomic) NSString *mailboxName;
- (BOOL)isMessageContentLocallyAvailable;
@property unsigned int uid;
@property(readonly, copy, nonatomic) NSString *messageID;
@property(readonly, copy) NSString *description;
- (id)initWithFlags:(long long)arg1 size:(unsigned long long)arg2 uid:(unsigned int)arg3;

// Remaining properties
@property(readonly) NSDate *dateReceived;
@property(readonly, copy) NSString *debugDescription;
@property(readonly, nonatomic) BOOL hasAttachments;
@property(readonly) unsigned long long hash;
@property BOOL isPartial;
@property(readonly) unsigned long long messageSize;
@property BOOL partsHaveBeenCached;
@property(readonly, nonatomic) BOOL shouldDeferBodyDownload;
@property(readonly) Class superclass;

@end

