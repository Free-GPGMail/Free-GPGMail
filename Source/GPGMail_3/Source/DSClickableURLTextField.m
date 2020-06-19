/*
	DSClickableURLTextField
	
	Copyright (c) 2006 - 2007 Night Productions, by Darkshadow. All Rights Reserved.
	http://www.nightproductions.net/developer.htm
	darkshadow@nightproductions.net
	
	May be used freely, but keep my name/copyright in the header.
	
	There is NO warranty of any kind, express or implied; use at your own risk.
	Responsibility for damages (if any) to anyone resulting from the use of this
	code rests entirely with the user.
	
	------------------------------------
	
	* August 25, 2006 - initial release
	* August 30, 2006
		• Fixed a bug where cursor rects would be enabled even if the
		  textfield wasn't visible.  i.e. it's in a scrollview, but the
		  textfield isn't scrolled to where it's visible.
		• Fixed an issue where mouseUp wouldn't be called and so clicking
		  on the URL would have no effect when the textfield is a subview
		  of a splitview (and maybe some other certain views).  I did this
		  by NOT calling super in -mouseDown:.  Since the textfield is
		  non-editable and non-selectable, I don't believe this will cause
		  any problems.
		• Fixed the fact that it was using the textfield's bounds rather than
		  the cell's bounds to calculate rects.
	* May 25, 2007
		Contributed by Jens Miltner:
			• Fixed a problem with the text storage and the text field's
			  attributed string value having different lengths, causing
			  range exceptions.
			• Added a delegate method allowing custom handling of URLs.
			• Tracks initially clicked URL at -mouseDown: to avoid situations
			  where dragging would end up in a different URL at -mouseUp:, opening
			  that URL. This includes situations where the user clicks on an empty
			  area of the text field, drags the mouse, and ends up on top of a
			  link, which would then erroneously open that link.
			• Fixed to allow string links to work as well as URL links.
		Changes by Darkshadow:
			• Overrode -initWithCoder:, -initWithFrame:, and -awakeFromNib to
			  explicitly set the text field to be non-editable and
			  non-selectable.  Now you don't need to remember to set this up,
			  and the class will work correctly regardless.
			• Added in the ability for the user to copy URLs to the clipboard.
			  Note that this is off by default.
			• Some code clean up.
    * Sep 19, 2018
        Changes by Christopher Atlan:
             • Fixed a problem with text storage and text field using different
               font sizes, causing incorrect cursor rects.
*/

#import "DSClickableURLTextField.h"


@implementation DSClickableURLTextField

@dynamic delegate;

/* Set the text field to be non-editable and
	non-selectable. */
- (id)initWithCoder:(NSCoder *)coder
{
	if ( (self = [super initWithCoder:coder]) ) {
		[self setEditable:NO];
		[self setSelectable:NO];
		_canCopyURLs = NO;
	}
	
	return self;
}

/* Set the text field to be non-editable and
	non-selectable. */
- (id)initWithFrame:(NSRect)frameRect
{
	if ( (self = [super initWithFrame:frameRect]) ) {
		[self setEditable:NO];
		[self setSelectable:NO];
		_canCopyURLs = NO;
	}
	
	return self;
}

- (void)dealloc
{
}

/* Enforces that the text field be non-editable and
	non-selectable. Probably not needed, but I always
	like to be cautious.
*/
- (void)awakeFromNib
{
	[self setEditable:NO];
	[self setSelectable:NO];
}

- (void)setAttributedStringValue:(NSAttributedString *)aStr
{
	[[self window] invalidateCursorRectsForView:self];
	[super setAttributedStringValue:aStr];
    [_URLStorage setAttributedString:[self _attributedStringWithDefaultAttributes]];
}

- (void)setStringValue:(NSString *)aStr
{
	NSAttributedString *attrString = [[NSAttributedString alloc] initWithString:aStr attributes:nil];
	[self setAttributedStringValue:attrString];
}

- (void)setCanCopyURLs:(BOOL)aFlag
{
	_canCopyURLs = aFlag;
}

- (BOOL)canCopyURLs
{
	return _canCopyURLs;
}

- (void)resetCursorRects
{
	if ( [[self attributedStringValue] length] == 0 ) {
		[super resetCursorRects];
		return;
	}
	
	NSRect cellBounds = [[self cell] drawingRectForBounds:[self bounds]];

	if ( _URLStorage == nil ) {
		BOOL cellWraps = ![[self cell] isScrollable];
		NSSize containerSize = NSMakeSize( cellWraps ? cellBounds.size.width : MAXFLOAT, cellWraps ? MAXFLOAT : cellBounds.size.height );
		_URLContainer = [[NSTextContainer alloc] initWithContainerSize:containerSize];
		_URLManager = [[NSLayoutManager alloc] init];
		_URLStorage = [[NSTextStorage alloc] init];
		
		[_URLStorage addLayoutManager:_URLManager];
		[_URLManager addTextContainer:_URLContainer];
		[_URLContainer setLineFragmentPadding:2.f];
		
		[_URLStorage setAttributedString:[self _attributedStringWithDefaultAttributes]];
	}
	
	NSUInteger myLength = [_URLStorage length];
	NSRange returnRange = { NSNotFound, 0 }, stringRange = { 0, myLength }, glyphRange = { NSNotFound, 0 };
	NSCursor *pointingCursor = nil;
	
	/* Here mainly for 10.2 compatibility (in case anyone even tries for that anymore) */
	if ( [NSCursor respondsToSelector:@selector(pointingHandCursor)] ) {
		pointingCursor = [NSCursor performSelector:@selector(pointingHandCursor)];
	} else {
		[super resetCursorRects];
		return;
	}
	
	/* Moved out of the while and for loops as there's no need to recalculate
	   it every time through */
	NSRect superVisRect = [self convertRect:[[self superview] visibleRect] fromView:[self superview]];

	while ( stringRange.location < myLength ) {
		id aVal = [_URLStorage attribute:NSLinkAttributeName atIndex:stringRange.location longestEffectiveRange:&returnRange inRange:stringRange];
		
		if ( aVal != nil ) {
			NSRectArray aRectArray = NULL;
			NSUInteger numRects = 0, j = 0;
			glyphRange = [_URLManager glyphRangeForCharacterRange:returnRange actualCharacterRange:nil];
			aRectArray = [_URLManager rectArrayForGlyphRange:glyphRange withinSelectedGlyphRange:glyphRange inTextContainer:_URLContainer rectCount:&numRects];
			for ( j = 0; j < numRects; j++ ) {
				/* Check to make sure the rect is visible before setting the cursor */
				NSRect glyphRect = aRectArray[j];
				glyphRect.origin.x += cellBounds.origin.x;
				glyphRect.origin.y += cellBounds.origin.y;
				NSRect textRect = NSIntersectionRect(glyphRect, cellBounds);
				NSRect cursorRect = NSIntersectionRect(textRect, superVisRect);
				if ( NSIntersectsRect( textRect, superVisRect ) )
					[self addCursorRect:cursorRect cursor:pointingCursor];
			}
		}
		stringRange.location = NSMaxRange(returnRange);
		stringRange.length = myLength - stringRange.location;
	}
}

- (NSURL*)urlAtMouse:(NSEvent *)mouseEvent
{
	NSURL*	urlAtMouse = nil;
	NSPoint mousePoint = [self convertPoint:[mouseEvent locationInWindow] fromView:nil];
	NSRect cellBounds = [[self cell] drawingRectForBounds:[self bounds]];
	
	if ( ([_URLStorage length] > 0 ) && [self mouse:mousePoint inRect:cellBounds] ) {
		id aVal = nil;
		NSRange returnRange = { NSNotFound, 0 }, glyphRange = { NSNotFound, 0 };
		NSRectArray linkRect = NULL;
		NSUInteger glyphIndex = [_URLManager glyphIndexForPoint:mousePoint inTextContainer:_URLContainer];
		NSUInteger charIndex = [_URLManager characterIndexForGlyphAtIndex:glyphIndex];
		NSUInteger numRects = 0, j = 0;
		
		aVal = [_URLStorage attribute:NSLinkAttributeName atIndex:charIndex longestEffectiveRange:&returnRange inRange:NSMakeRange(charIndex, [_URLStorage length] - charIndex)];
		if ( (aVal != nil) ) {
			glyphRange = [_URLManager glyphRangeForCharacterRange:returnRange actualCharacterRange:nil];
			linkRect = [_URLManager rectArrayForGlyphRange:glyphRange withinSelectedGlyphRange:glyphRange inTextContainer:_URLContainer rectCount:&numRects];
			for ( j = 0; j < numRects; j++ ) {
				NSRect testHit = linkRect[j];
				testHit.origin.x += cellBounds.origin.x;
				testHit.origin.x += cellBounds.origin.y;
				if ( [self mouse:mousePoint inRect:NSIntersectionRect(testHit, cellBounds)] ) {
					// be smart about links stored as strings
					if ( [aVal isKindOfClass:[NSString class]] )
						aVal = [NSURL URLWithString:aVal];
					urlAtMouse = aVal;
					break;
				}
			}
		}
	}
	return urlAtMouse;
}

- (NSMenu *)menuForEvent:(NSEvent *)aEvent
{
	if ( !_canCopyURLs )
		return nil;
	
	NSURL *anURL = [self urlAtMouse:aEvent];
	
	if ( anURL != nil ) {
		NSMenu *aMenu = [[NSMenu alloc] initWithTitle:@"Copy URL"];
		NSMenuItem *anItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Copy URL", @"Copy URL") action:@selector(copyURL:) keyEquivalent:@""];
		[anItem setTarget:self];
		[anItem setRepresentedObject:anURL];
		[aMenu addItem:anItem];
		
		return aMenu;
	}
	
	return nil;
}

- (void)copyURL:(id)sender
{
	NSPasteboard *copyBoard = [NSPasteboard pasteboardWithName:NSGeneralPboard];
	NSURL *copyURL = [sender representedObject];
	
	[copyBoard declareTypes:[NSArray arrayWithObjects:NSURLPboardType, NSStringPboardType, nil] owner:nil];
	[copyURL writeToPasteboard:copyBoard];
	[copyBoard setString:[copyURL absoluteString] forType:NSStringPboardType];
}

- (void)mouseDown:(NSEvent *)mouseEvent
{
	/* Not calling [super mouseDown:] because there are some situations where
		the mouse tracking is ignored otherwise. */
	
	/* Remember which URL was clicked originally, so we don't end up opening
		the wrong URL accidentally.
	*/
	_clickedURL = [self urlAtMouse:mouseEvent];
}

- (void)mouseUp:(NSEvent *)mouseEvent
{
	NSURL* urlAtMouse = [self urlAtMouse:mouseEvent];
	if ( (urlAtMouse != nil)  &&  [urlAtMouse isEqualTo:_clickedURL] ) {
		// check if delegate wants to open the URL itself, if not, let the workspace open the URL
        id<DSClickableURLTextField> delegate = [self delegate];
		if ( (delegate == nil)  || ![delegate respondsToSelector:@selector(textField:openURL:)] || ![delegate textField:self openURL:urlAtMouse] )
			[[NSWorkspace sharedWorkspace] openURL:urlAtMouse];
	}
	_clickedURL = nil;
	[super mouseUp:mouseEvent];
}

- (NSDictionary *)_defaultAttributes
{
    NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
    [attrs setObject:[self font] forKeyedSubscript:NSFontAttributeName];
    return [attrs copy];
}

- (NSAttributedString *)_attributedStringWithDefaultAttributes
{
    NSAttributedString *string = [self attributedStringValue];
    if ([string length] == 0) return string;
    
    NSDictionary *attributes = [string attributesAtIndex:0 effectiveRange:NULL];
    if ([attributes objectForKey:NSFontAttributeName]) return string;
    
    NSDictionary *defaultAttributes = [self _defaultAttributes];
    NSMutableAttributedString *adjustedString = [string mutableCopy];
    __block NSRange lastRange = NSMakeRange(0, 0);
    [string enumerateAttribute:NSFontAttributeName inRange:NSMakeRange(0, [string length]) options:0 usingBlock:^(id value, NSRange range, BOOL * stop) {
        NSRange changeRange = value ? NSMakeRange(NSMaxRange(lastRange), range.location) : range;
        [adjustedString addAttributes:defaultAttributes range:changeRange];
        lastRange = range;
    }];
    return [adjustedString copy];
}

@end
