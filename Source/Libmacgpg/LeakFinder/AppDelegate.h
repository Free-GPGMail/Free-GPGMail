//
//  AppDelegate.h
//  LeakFinder
//
//  Created by Lukas Pitschl on 23.04.13.
//
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

- (IBAction)doEncrypt:(id)sender;

@property (nonatomic, assign) IBOutlet NSWindow *window;
@property (nonatomic, assign) IBOutlet NSButton *encryptButton;

@end
