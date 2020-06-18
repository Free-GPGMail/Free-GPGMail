#import <Cocoa/Cocoa.h>

@interface GMComposeKeyEventHandler : NSView {
	NSArray *eventsAndSelectors;
}

/*
 * eventsAndSelectors
 * Contains NSDicionarys with these keys:
 *	 NSString keyEquivalent
 *	 NSNumber keyEquivalentModifierMask
 *	 id       target
 *	 NSValue  selector
 */
@property (strong) NSArray *eventsAndSelectors;

- (id)initWithView:(NSView *)view;

@end
