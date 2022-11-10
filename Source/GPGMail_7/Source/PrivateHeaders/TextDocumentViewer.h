/* TextDocumentViewer.h created by stephane on Tue 04-Jul-2000 */

#import <Foundation/NSObject.h>
#import <AppKit/NSNibDeclarations.h>
#import <AppKit/NSTextAttachment.h>


@class NSImageView;
@class NSScrollView;
@class NSTextView;
@class Message;
@class MessageTextView;
@class MessageTextContainer;
@class HTMLView;
@class NSTimer;


extern NSString *MessageWillBeDisplayedInView;
// Object is TextDocumentViewer
// UserInfo:
//  MessageKey = Message
//  MessageViewKey = MessageTextView
extern NSString *MessageWillNoLongerBeDisplayedInView;
// Object is TextDocumentViewer
// UserInfo:
//  MessageKey = Message
//  MessageViewKey = MessageTextView


@class MessageViewingState;
@class ActivityMonitor;
@class ObjectCache;
@class InvocationQueue;

@interface TextDocumentViewer : NSResponder
{
	Message *_message;
	MessageViewingState *_viewingState;
	ActivityMonitor *_documentMonitor;
	NSScrollView *messageScroll;
	MessageTextView *textView;
	MessageTextContainer *specialContainer;
	NSImageView *imageView;
	NSView *contentContainerView;
	NSView *junkMailView;
	HTMLView *_htmlView;
	NSView *_currentView;
	NSTimer *_fadeTimer;
	ObjectCache *_documentCache;
	struct __CFSet *observedHTMLDocuments;
	InvocationQueue *invocationQueue;
	NSString *_messageIDToRestoreInitialStateFor;
	struct _NSRect _initialVisibleRect;
	struct _NSRange _initialSelectedRange;
	int _fadeStepCounter : 30;
	int _attachmentsMayBeLoading : 1;
	int _textViewHasBeenInitialized : 1;
}

- (void)awakeFromNib;
- attachmentContextMenu;
- (void)readDefaultsFromDictionary:fp12;
- (void)writeDefaultsToDictionary:fp12;
- (void)_setupUI;
- (void)dealloc;
- (void)stopAllActivity;
- (void)_messageMayHaveBecomeAvailable;
- (void)_cancelBackgroundAttachmentLoadingIfNeeded;
- (void)_switchToNSTextView;
- (void)_switchToHTMLView;
- (void)fadeToEmpty;
- (void)fadeOneNotch:fp12;
- (void)_stopFadingTimer;
- (void)_pushDocumentToCache;
- (void)_backgroundLoadFinished:fp12;
- (void)setMessage:fp12;
- (void)_setMessage:fp12;
- (void)_fetchContentsForMessage:fp12 fromStore:fp16 withViewingAttributes:fp20;
- (void)_startBackgroundLoad:fp12;
- message;
- (void)_removeCurrentMessageFromCache;
- (void)reloadCurrentMessage;
- (void)viewerPreferencesChanged:fp12;
- (void)showJunkMailHelp:fp12;
- (void)_addHelpButton;
- (void)_showJunkMailBanner;
- (void)_hideJunkMailBanner;
- (void)_updateJunkMailBannerForLevel:(int)fp12;
- (void)markAsNotJunkMailClicked:fp12;
- (void)_messageFlagsDidChange:fp12;
- (void)_updateDisplay;
- (void)highlightSearchText:fp12;
- textView;
- currentSelection;
- (void)clearCache;
- (void)_updateSendersImageToMatchSender:fp12;
- (void)_displayHTMLDocument:fp12;
- (void)displayAttributedString:fp12;
- (void)_addressPhotoLoaded:fp12;
- (void)_unregisterForHTMLDocumentNotifications;
- (void)htmlDocumentDidChange:fp12;
- (void)initPrintInfo;
- (int)headerDetailLevel;
- (char)showingAllHeaders;
- (void)setShowAllHeaders:(char)fp12;
- (void)keyDown:fp12;
- (char)pageDown;
- (char)pageUp;
- attachmentDirectory;
- (void)textView:fp12 clickedOnCell:fp16 inRect:(struct _NSRect)fp20 atIndex:(unsigned int)fp32;
- (void)textView:fp12 doubleClickedOnCell:fp16 inRect:(struct _NSRect)fp20 atIndex:(unsigned int)fp32;
- (void)textView:fp12 draggedCell:fp16 inRect:(struct _NSRect)fp20 event:fp32 atIndex:(unsigned int)fp36;
- (char)_handleClickOnURL:fp12;
- (char)textView:fp12 clickedOnLink:fp16 atIndex:(unsigned int)fp20;
- (void)targetHtmlView:fp12 followLink:fp16;
- (char)htmlView:fp12 clickedOnLink:fp16;
- (char)currentlyViewingSource;
- (char)_validateAction:(SEL) fp12 tag:(int)fp16;
- (char)validateToolbarItem:fp12;
- (char)validateMenuItem:fp12;
- (void)showAllHeaders:fp12;
- (void)showFilteredHeaders:fp12;
- (void)viewSource:fp12;
- (void)toggleShowControlCharacters:fp12;
- (void)showFirstAlternative:fp12;
- (void)showPreviousAlternative:fp12;
- (void)showNextAlternative:fp12;
- (void)showBestAlternative:fp12;
- (void)changeTextEncoding:fp12;
- (void)_makeFontBigger:fp12;
- (void)_makeFontSmaller:fp12;
- (void)makeFontBigger:fp12;
- (void)makeFontSmaller:fp12;

@end
