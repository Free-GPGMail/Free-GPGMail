//
//     Generated by class-dump 3.5 (64 bit).
//
//     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2013 by Steve Nygard.
//

//#import "NSViewController.h"

@class MFIMAPAccount, NSPopUpButton;

@interface _SpecialMailboxPopUpButtonController : NSViewController
{
    int _specialMailboxType;
}

@property(nonatomic) int specialMailboxType; // @synthesize specialMailboxType=_specialMailboxType;
- (void)_updatePopUp;
@property(retain) MFIMAPAccount *representedObject;
- (void)viewDidDisappear;
- (void)_mailboxListingDidChange:(id)arg1;
- (void)viewWillAppear;
@property(retain) NSPopUpButton *view;

@end

