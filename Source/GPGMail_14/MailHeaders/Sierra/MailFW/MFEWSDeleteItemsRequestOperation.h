//
//     Generated by class-dump 3.5 (64 bit).
//
//     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2013 by Steve Nygard.
//

#import <Mail/MFEWSRequestOperation.h>

#import "NSCoding.h"

@class NSArray, NSString;

@interface MFEWSDeleteItemsRequestOperation : MFEWSRequestOperation <NSCoding>
{
    NSArray *_EWSItemIds;	// 24 = 0x18
    NSString *_folderIdString;	// 32 = 0x20
}

@property(readonly, copy, nonatomic) NSString *folderIdString; // @synthesize folderIdString=_folderIdString;
@property(readonly, copy, nonatomic) NSArray *EWSItemIds; // @synthesize EWSItemIds=_EWSItemIds;
- (void).cxx_destruct;	// IMP=0x00000000000820a1
- (void)setupOfflineResponse;	// IMP=0x0000000000082009
- (id)prepareRequest;	// IMP=0x0000000000081d7e
- (id)activityString;	// IMP=0x0000000000081b33
- (void)_ewsDeleteItemsRequestOperationCommonInitWithEWSItemIds:(id)arg1 folderIdString:(id)arg2;	// IMP=0x0000000000081a94
- (id)initWithGateway:(id)arg1 errorHandler:(id)arg2;	// IMP=0x00000000000819c5
- (void)encodeWithCoder:(id)arg1;	// IMP=0x00000000000818e4
- (id)initWithCoder:(id)arg1;	// IMP=0x000000000008178e
- (id)initWithEWSItemIds:(id)arg1 folderIdString:(id)arg2 gateway:(id)arg3;	// IMP=0x00000000000816a9

@end
