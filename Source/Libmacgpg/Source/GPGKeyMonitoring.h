//
//  GPGKeyMonitoring.h
//  Libmacgpg
//
//  Created by Mento on 05.07.18.
//

@interface GPGKeyMonitoring : NSObject
/*
 * All alerts will be atached to this window.
 * Be sure to set this to nil again, before the window is released!
 */
@property (nonatomic, assign) NSWindow *sheetWindow;
+ (instancetype)sharedInstance;
@end
