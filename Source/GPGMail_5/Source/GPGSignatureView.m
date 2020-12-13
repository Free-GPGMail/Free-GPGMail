#import "GPGSignatureView.h"
#import "GPGMailBundle.h"

#define localized(key) [[GPGMailBundle bundle] localizedStringForKey:(key) value:(key) table:@"SignatureView"]

@interface GPGSignatureView () <NSWindowDelegate, NSTableViewDelegate, NSTableViewDataSource, NSSplitViewDelegate> {
	BOOL running;
	NSIndexSet *signatureIndexes;
	GPGSignature *_signature;
	CGFloat fullHeight;
	CGFloat listHeight;
	CGFloat subkeyHeight;
}

@property (nonatomic, weak) IBOutlet NSSplitView *splitView;
@property (nonatomic, weak) IBOutlet NSView *parentView;
@property (nonatomic, strong) IBOutlet NSView *subkeyView; // Must be strong, because it's removed from its superview.

@property (nonatomic, strong) NSIndexSet *signatureIndexes;
@property (nonatomic, strong) GPGKey *gpgKey;
@property (nonatomic, strong) GPGKey *subkey;


@property (nonatomic, readonly) NSString *unlocalizedValidityKey;
@property (nonatomic, readonly) NSImage *validityImage;
@property (nonatomic, readonly) NSString *validityDescription;
@property (nonatomic, readonly) NSString *validityToolTip;
@property (nonatomic, readonly) NSString *keyID;
@property (nonatomic, readonly) NSImage *signatureImage;

@end



@implementation GPGSignatureView
GPGSignatureView *_sharedInstance;



#pragma mark Properties

- (NSString *)unlocalizedValidityKey {
	NSString *text = nil;

	switch (_signature.status) {
		case GPGErrorNoError:
			if (_signature.trust > 1) {
				text = @"VALIDITY_OK";
			} else {
				text = @"VALIDITY_NO_TRUST";
			}
			break;
		case GPGErrorBadSignature:
			text = @"VALIDITY_BAD_SIGNATURE";
			break;
		case GPGErrorSignatureExpired:
			text = @"VALIDITY_SIGNATURE_EXPIRED";
			break;
		case GPGErrorKeyExpired:
			text = @"VALIDITY_KEY_EXPIRED";
			break;
		case GPGErrorCertificateRevoked:
			text = @"VALIDITY_KEY_REVOKED";
			break;
		case GPGErrorUnknownAlgorithm:
			text = @"VALIDITY_UNKNOWN_ALGORITHM";
			break;
		case GPGErrorNoPublicKey:
			text = @"VALIDITY_NO_PUBLIC_KEY";
			break;
		default:
			text = @"VALIDITY_UNKNOWN_ERROR";
			break;
	}
	return text;
}

- (NSImage *)validityImage {
	if (![_signature isKindOfClass:[GPGSignature class]]) {
		return nil;
	}
	if (_signature.status != 0 || _signature.trust <= 1) {
		return [NSImage imageNamed:@"InvalidBadge"];
	} else {
		return [NSImage imageNamed:@"ValidBadge"];
	}
}

- (NSString *)validityDescription {
	if (!_signature) return nil;

	NSString *text = [self unlocalizedValidityKey];
	if (text) {
		return localized(text);
	} else {
		return @"";
	}
}

- (NSString *)validityToolTip {
	if (!_signature) return nil;

	NSString *text = [self unlocalizedValidityKey];
	text = [text stringByAppendingString:@"_TOOLTIP"];
	if (text) {
		return localized(text);
	} else {
		return @"";
	}
}

- (NSString *)keyID {
	NSString *keyID = self.gpgKey.keyID;
	if (!keyID) {
		keyID = _signature.fingerprint;
	}
	return [keyID shortKeyID];
}

- (NSImage *)signatureImage {
	if (![_signature isKindOfClass:[GPGSignature class]]) {
		return nil;
	}
	if (_signature.status != 0 || _signature.trust <= 1) {
		return [NSImage imageNamed:@"CertLargeNotTrusted"];
	} else {
		return [NSImage imageNamed:@"CertLargeStd"];
	}
}

- (NSIndexSet *)signatureIndexes {
	return signatureIndexes;
}
- (void)setSignatureIndexes:(NSIndexSet *)value {
	if (value != signatureIndexes) {
		signatureIndexes = value;
		NSUInteger index;
		if ([value count] > 0 && (index = [value firstIndex]) < self.signatures.count) {
			self.signature = self.signatures[index];
		} else {
			self.signature = nil;
		}
		
	}
}

- (void)setSignature:(GPGSignature *)value {
	if (value == _signature) {
		return;
	}
	_signature = value;
	
	GPGKey *key = _signature.primaryKey;
	GPGKey *subkey = _signature.key;
	if ([key isEqual:subkey]) {
		subkey = nil;
	}
	self.gpgKey = key;
	self.subkey = subkey;

	if (subkey) {
		// Set the width of self.subkeyView to the parents width.
		[self.subkeyView setFrameSize:NSMakeSize(self.parentView.frame.size.width, self.subkeyView.frame.size.height)];
		
		// Add the self.subkeyView.
		[self.parentView addSubview:self.subkeyView];
		
		// Calculate the required height for the parent.
		CGFloat height = 0;
		for (NSView *view in self.parentView.subviews) {
			height += view.frame.size.height;
		}
		// Set the parent height. (The parentView is set to fill it's superview).
		[self.parentView.superview setFrameSize:NSMakeSize(self.parentView.frame.size.width, height)];
		
		// The self.subkeyView should be on the bottom.
		[self.subkeyView setFrameOrigin:NSMakePoint(0, 0)];
		
		[self resizeForSubkeyAnimate:YES];
	} else {
		[self.subkeyView removeFromSuperview];
		CGFloat height = 0;
		for (NSView *view in self.parentView.subviews) {
			height += view.frame.size.height;
		}
		[self.parentView.superview setFrameSize:NSMakeSize(self.parentView.frame.size.width, height)];
	}
	
	
}

- (id)valueForKeyPath:(NSString *)keyPath {
	if ([keyPath hasPrefix:@"signature."]) {
		if (_signature == nil) {
			return nil;
		}
		keyPath = [keyPath substringFromIndex:10];
		if ([_signature respondsToSelector:NSSelectorFromString(keyPath)]) {
			return [_signature valueForKey:keyPath];
		}
	}
	return [super valueForKeyPath:keyPath];
}


#pragma mark Helper methods

- (void)resizeForSubkeyAnimate:(BOOL)animate {
	// The method increases the window size, if the user did not resized it and
	// there is not enough space to show the subkey details.
	
	if (!self.subkey) {
		return;
	}
		
	CGFloat currentHeight = self.window.contentView.frame.size.height;
	CGFloat defaultHeight; // The default height of the window. It's only required to detect, if the user changed the window size.
	if (self.signatures.count == 1) {
		defaultHeight = fullHeight - subkeyHeight - listHeight;
	} else {
		defaultHeight = fullHeight - subkeyHeight;
	}
	
	if (defaultHeight == currentHeight) {
		// The user did not change the window size manually.
		
		// Calulate the new window size.
		NSRect frame = self.window.frame;
		frame.size.height += self.subkeyView.frame.size.height;
		// Change y so the window (sheet) stays attached to the main window.
		frame.origin.y -= self.subkeyView.frame.size.height;
		
		if (animate) {
			[self.window.animator setFrame:frame display:YES];
		} else {
			[self.window setFrame:frame display:YES];
		}
	}
}

- (void)prepareForShow {
	running = 1;
	[self willChangeValueForKey:@"signatureDescriptions"];
	[self didChangeValueForKey:@"signatureDescriptions"];
	
	if (self.signatures.count == 1) {
		[self.splitView setPosition:-self.splitView.dividerThickness ofDividerAtIndex:0];
		
		NSSize size = self.window.contentView.frame.size;
		size.height = fullHeight - subkeyHeight - listHeight;
		[self.window setContentSize:size];
	} else {
		[self.splitView setPosition:listHeight ofDividerAtIndex:0];
		
		NSSize size = self.window.contentView.frame.size;
		size.height = fullHeight - subkeyHeight;
		[self.window setContentSize:size];
	}
	
	[self resizeForSubkeyAnimate:NO];
}


#pragma mark Public methods

- (NSInteger)runModal {
	if (!running) {
		[self prepareForShow];
		[NSApp runModalForWindow:self.window];
		return NSOKButton;
	} else {
		return NSCancelButton;
	}
}
- (void)beginSheetModalForWindow:(NSWindow *)modalWindow completionHandler:(void (^)(NSInteger result))handler {
	if (!running) {
		[self prepareForShow];
		[NSApp beginSheet:self.window modalForWindow:modalWindow modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:(__bridge void *)(handler)];
	} else {
		handler(NSCancelButton);
	}
}

+ (id)signatureView {
	static dispatch_once_t pred;
	static GPGSignatureView *_sharedInstance;
	dispatch_once(&pred, ^{
		_sharedInstance = [[GPGSignatureView alloc] initWithWindowNibName:@"GPGSignatureView"];
	});
	return _sharedInstance;
}


#pragma mark Delegate and Actions

- (IBAction)close:(__unused id)sender {
	[self.window orderOut:self];
	[NSApp stopModal];
	[NSApp endSheet:self.window];
	running = 0;
}

- (void)windowWillClose:(__unused NSNotification *)notification {
	[NSApp stopModal];
	[NSApp endSheet:self.window];
	running = 0;
}

- (BOOL)splitView:(__unused NSSplitView *)aSplitView shouldHideDividerAtIndex:(__unused NSInteger)dividerIndex {
	return self.signatures.count == 1;
}
- (CGFloat)splitView:(__unused NSSplitView *)aSplitView constrainMinCoordinate:( __unused CGFloat)proposedMinimumPosition ofSubviewAt:(__unused NSInteger)dividerIndex {
	if (self.signatures.count == 1) {
		return -self.splitView.dividerThickness;
	} else {
		return 60;
	}
}
- (CGFloat)splitView:(__unused NSSplitView *)aSplitView constrainMaxCoordinate:(CGFloat)proposedMaximumPosition ofSubviewAt:(__unused NSInteger)dividerIndex {
	return proposedMaximumPosition - 90;
}
- (void)splitView:(NSSplitView *)aSplitView resizeSubviewsWithOldSize:(__unused NSSize)oldSize {
//	if (self.signatures.count == 1) {
//		return;
//	}
	
	
	NSArray *subviews = aSplitView.subviews;
	NSView *view1 = subviews[0];
	NSView *view2 = subviews[1];
	NSSize splitViewSize = aSplitView.frame.size;
	NSSize size1 = view1.frame.size;
	NSRect frame2 = view2.frame;
	CGFloat dividerThickness = self.signatures.count == 1 ? 0 : aSplitView.dividerThickness;

	size1.width = splitViewSize.width;
	frame2.size.width = splitViewSize.width;

	frame2.size.height = splitViewSize.height - dividerThickness - size1.height;
	if (frame2.size.height < 60) {
		frame2.size.height = 60;
		size1.height = splitViewSize.height - 60 - dividerThickness;
	}
	frame2.origin.y = splitViewSize.height - frame2.size.height;

	
	if (self.signatures.count != 1) {
		[view1 setFrameSize:size1];
	}
	
	[view2 setFrame:frame2];
}

- (void)sheetDidEnd:(__unused NSWindow *)sheet returnCode:(__unused NSInteger)returnCode contextInfo:(void *)contextInfo {
	((__bridge void (^)(NSInteger result))contextInfo)(NSOKButton);
}


#pragma mark Init

- (instancetype)initWithWindowNibName:(NSNibName)windowNibName {
	self = [super initWithWindowNibName:windowNibName];
	if (!self) {
		return nil;
	}
	[self.window layoutIfNeeded];
	
	fullHeight = self.window.contentView.frame.size.height;
	listHeight = self.splitView.subviews[0].frame.size.height;
	subkeyHeight = self.subkeyView.frame.size.height;
	[self.subkeyView removeFromSuperview];
	
	return self;
}


@end




@implementation GPGSignatureCertImageTransformer
+ (Class)transformedValueClass { return [NSImage class]; }
+ (BOOL)allowsReverseTransformation { return NO; }
- (id)transformedValue:(GPGSignature *)signature {
	if (![signature isKindOfClass:[GPGSignature class]]) {
		return nil;
	}
	if (signature.status != 0 || signature.trust <= 1) {
		return [NSImage imageNamed:@"CertSmallStd_Invalid"];
	} else {
		return [NSImage imageNamed:@"CertSmallStd"];
	}
}
@end

@implementation GPGFlippedView
- (BOOL)isFlipped {
	return YES;
}
@end

@implementation TopScrollView
// When the view is resized, the content would normally stay at the bottom.
// The TopScrollView inverts this behavior, so the top of the contents stays visible.
- (void)setFrameSize:(NSSize)newSize {
	NSClipView *clipView = [self contentView];
	NSRect bounds = [clipView bounds];
	[super setFrameSize:newSize];
	bounds.origin.y = bounds.origin.y - (bounds.size.height - [clipView bounds].size.height);
	[clipView setBoundsOrigin:bounds.origin];
}
@end


