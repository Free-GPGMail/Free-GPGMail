//
//  GPGAttachmentController.h
//  GPGMail
//
//  Created by Lukas Pitschl on 08.11.11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "GPGSignatureView.h"

@class MimePart_GPGMail;

@interface GPGAttachmentController : NSWindowController <NSTableViewDelegate, NSTableViewDataSource, NSSplitViewDelegate> {
    NSImageView *__weak errorImageView;
    NSMutableArray *attachments;
    GPGSignature *signature;
    NSDictionary *currentAttachment;
    NSSet *keyList;
    NSIndexSet *attachmentIndexes;
	CGFloat initialHeight;
	
	
    IBOutlet NSView *scrollContentView;
	IBOutlet NSView *infoView;
	IBOutlet NSView *subkeyView;
	IBOutlet NSScrollView *scrollView;
	IBOutlet NSView *errorView;
	IBOutlet NSView *decryptOKView;
    IBOutlet NSTableView *tableView;
}

- (id)initWithAttachmentParts:(NSArray *)attachmentParts;
- (void)beginSheetModalForWindow:(NSWindow *)modalWindow completionHandler:(void (^)(NSInteger result))handler;
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;

@property (weak) IBOutlet NSImageView *errorImageView;
@property (strong) NSArray *attachments;
@property (nonatomic, strong) NSIndexSet *attachmentIndexes;
@property (strong) NSDictionary *currentAttachment;
@property (nonatomic, strong) GPGSignature *signature;
@property (strong) NSSet *keyList;
@property (strong, readonly, nonatomic) GPGKey *gpgKey;
@property (strong, readonly, nonatomic) GPGKey *subkey;


/**
 Returns the correctly signed or signature failure image, depending
 on the part status.
 */
- (NSImage *)signedImageForPart:(MimePart_GPGMail *)part;

/**
 Returns the encrypted or decrypted image, depending on the part
 status.
 */
- (NSImage *)encryptedImageForPart:(MimePart_GPGMail *)part;

@end

