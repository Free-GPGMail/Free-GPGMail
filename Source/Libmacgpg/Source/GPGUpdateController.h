//
//  UpdateController.h
//  GPGPreferences
//
//  Created by Mento on 26.04.2013
//
//

@class GPGOptions;
@interface GPGUpdateController : NSObject {
	GPGOptions *_options;
}
@property BOOL automaticallyChecksForUpdates;
@property BOOL downloadBetaUpdates;

- (IBAction)checkForUpdates:(id)sender;
- (IBAction)showReleaseNotes:(id)sender;

+ (instancetype)sharedInstance;

@end
