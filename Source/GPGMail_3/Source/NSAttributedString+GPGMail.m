//
//  NSAttributedString+GPGMail.m
//  GPGMail
//
//  Created by Lukas Pitschl on 31.07.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "GPGTextAttachmentCell.h"
#import "NSAttributedString+GPGMail.h"

@implementation NSAttributedString (GPGMail)

+ (NSAttributedString *)attributedStringWithAttachment:(NSTextAttachment *)attachment image:(NSImage *)image link:(NSString *)link offset:(float)offset {
    GPGTextAttachmentCell *cell = [[GPGTextAttachmentCell alloc] init];
    cell.image = image;
    attachment.attachmentCell = cell;
    NSMutableAttributedString *attachmentString = [[NSAttributedString attributedStringWithAttachment:attachment] mutableCopy];
    // Now this is unusual but comfortable.
    // Set a link attribute on the attachment, so we get an event
    // when the attachment is clicked in the MessageHeaderDisplay.
    // See textView:clickOnLink:
    // If link is nil, just create the attachment with the image.
    if(link) {
        [attachmentString addAttribute:NSLinkAttributeName value:link 
                                 range:NSMakeRange(0, [attachmentString length])];
    }
    [attachmentString addAttribute:NSCursorAttributeName value:[NSCursor arrowCursor] 
                             range:NSMakeRange(0, [attachmentString length])];
    
    [attachmentString addAttribute:NSBaselineOffsetAttributeName 
                             value:@(offset)
                             range:NSMakeRange(0,[attachmentString length])];
    NSAttributedString *nonMutableAttachmentString = [[NSAttributedString alloc] initWithAttributedString:attachmentString];
    return nonMutableAttachmentString;
}

+ (NSAttributedString *)attributedStringWithString:(NSString *)string {
    return [[NSAttributedString alloc] initWithString:string];
}

@end
