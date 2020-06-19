#import <Cocoa/Cocoa.h>
#import <Libmacgpg/Libmacgpg.h>

@interface GPGSignatureView : NSWindowController

@property (nonatomic, strong) NSArray *signatures;

+ (id)signatureView;

- (NSInteger)runModal;
- (void)beginSheetModalForWindow:(NSWindow *)modalWindow completionHandler:(void (^)(NSInteger result))handler;
@end


@interface GPGSignatureCertImageTransformer : NSValueTransformer {} @end
@interface GPGFlippedView : NSView {} @end
@interface GPGFlippedClipView : NSClipView {} @end
@interface TopScrollView : NSScrollView {} @end
