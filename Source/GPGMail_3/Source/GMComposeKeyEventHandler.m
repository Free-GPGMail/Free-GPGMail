#import "GMComposeKeyEventHandler.h"

@implementation GMComposeKeyEventHandler
@synthesize eventsAndSelectors;

- (id)initWithView:(NSView *)view {
	if (!(self = [super initWithFrame:NSMakeRect(0, 0, 0, 0)])) {
		return nil;
	}
	// Hang into the responder chain.
	[view addSubview:self];
	return self;
}


- (BOOL)performKeyEquivalent:(NSEvent *)event {
	for (NSDictionary *dict in self.eventsAndSelectors) {
		NSString *keyEquivalent = dict[@"keyEquivalent"];
		NSUInteger keyEquivalentModifierMask = [dict[@"keyEquivalentModifierMask"] unsignedIntegerValue];
		
		if ((event.modifierFlags & NSDeviceIndependentModifierFlagsMask) == keyEquivalentModifierMask && [keyEquivalent isEqualToString:event.charactersIgnoringModifiers]) {
			id target = dict[@"target"];
			SEL selector = [dict[@"selector"] pointerValue];
	
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Warc-performSelector-leaks"
			[target performSelector:selector withObject:self];
#pragma GCC diagnostic pop
			return YES;
		}
	}
	
	return [super performKeyEquivalent:event];
}


@end
