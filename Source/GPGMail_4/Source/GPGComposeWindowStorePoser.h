/* GPGComposeWindowStorePoser.h created by dave on Sun 14-Jan-2001 */

#import <ComposeWindowStore.h>

#import <AppKit/AppKit.h>


@interface GPGComposeWindowStorePoser : ComposeWindowStore

// The following actions are forwarded to the GPGMailComposeAccessoryViewOwner
- (IBAction)gpgToggleEncryptionForNewMessage:(id)sender;
- (IBAction)gpgToggleSignatureForNewMessage:(id)sender;
- (IBAction)gpgChoosePublicKeys:(id)sender;
- (IBAction)gpgChoosePersonalKey:(id)sender;
- (IBAction)gpgChoosePublicKey:(id)sender;

// Some menu validations are forwarded to GPGMailComposeAccessoryViewOwner
- (BOOL)validateMenuItem:(id <NSMenuItem>)menuItem;

// The following notification methods are forwarded to the GPGMailComposeAccessoryViewOwner
#ifndef MACOSX
- (void)textDidChange:(NSNotification *)notification;
#endif
- (void)textDidEndEditing:(NSNotification *)notification;

@end
