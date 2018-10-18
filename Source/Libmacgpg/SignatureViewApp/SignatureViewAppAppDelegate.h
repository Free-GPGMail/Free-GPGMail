//
//  SignatureViewAppAppDelegate.h
//  SignatureViewApp
//
//  Created by Lukas Pitschl on 26.07.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SignatureViewAppAppDelegate : NSObject <NSApplicationDelegate> {
    NSWindow *_window;
}

@property (nonatomic, strong) IBOutlet NSWindow *window;

@end
