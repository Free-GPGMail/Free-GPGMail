//
//     Generated by class-dump 3.5 (64 bit).
//
//     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2015 by Steve Nygard.
//

//#import <objc/NSObject.h>

@class MCActivityAggregate;

@interface MCActivityAggregator : NSObject
{
    MCActivityAggregate *_in;
    MCActivityAggregate *_out;
    MCActivityAggregate *_save;
    MCActivityAggregate *_synchronizingActivityAggregate;
    MCActivityAggregate *_downloadingContentAggregate;
}

+ (id)sharedInstance;
+ (id)allocWithZone:(struct _NSZone *)arg1;
@property(readonly, nonatomic) MCActivityAggregate *downloadingContentAggregate; // @synthesize downloadingContentAggregate=_downloadingContentAggregate;
@property(readonly, nonatomic) MCActivityAggregate *synchronizingActivityAggregate; // @synthesize synchronizingActivityAggregate=_synchronizingActivityAggregate;
@property(readonly, nonatomic) MCActivityAggregate *save; // @synthesize save=_save;
@property(readonly, nonatomic) MCActivityAggregate *out; // @synthesize out=_out;
@property(readonly, nonatomic) MCActivityAggregate *in; // @synthesize in=_in;
//- (void).cxx_destruct;
- (void)activityMonitor:(id)arg1 didChangeTypeFrom:(long long)arg2;
- (void)dealloc;
- (id)init;

@end

