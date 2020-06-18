/* NSPreferences+GPGMail.m created by Lukas Pitschl (lukele) on Sat 20-Aug-2011 */

/*
 * Copyright (c) 2000-2011, GPGTools Project Team <gpgtools-devel@lists.gpgtools.org>
 * All rights reserved.
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of GPGTools Project Team nor the names of GPGMail
 *       contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE GPGTools Project Team ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE GPGTools Project Team BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "CCLog.h"
#import "NSObject+LPDynamicIvars.h"
#import "NSArray+Functional.h"
#import <NSPreferences.h>
#import <NSPreferencesModule.h>
#import "NSPreferences+GPGMail.h"
#import "GPGMailPreferences.h"
#import "GPGMailBundle.h"

@implementation NSPreferences (GPGMail)

+ (id)MAMakePreferenceTabViewItems {
    // Bug #943: Make sure the GPGMail preference item is only added once.
    //
    // In theory -[GPGMailBundle registerBundle] is responsible for registering
    // the preference panel of GPGMail with Mail.app
    // This however only works, if an instance of MailPreferences already exists,
    // which seems to only be the case, if it was instantiated by a second plugin.
    // Otherwise +[MailPreferences sharedPreferences] would return nil and the
    // preference panel would not be registered.
    // To fix this problem, GPGMail hooked into +[MailPreferences sharedPreferences]
    // This however lead to the problem that the preference panel might have been registered
    // twice, if a second plugin was available which was loaded *prior* to GPGMail being
    // loaded.
    // In that case the preference panel would be loaded once in +[MailPreferences sharedPreferences]
    // and again in -[GPGMailBundle registerBundle].
    // In order to make sure that the preference panel is really only registered once, the code
    // hook on +[MailPreferences sharedPreferences] has been moved here.
    // This method is called by Mail, once the preference window is loaded,
    // and is probably the best place to add GPGMail's preference panel, if
    // it has not been already added from -[GPGMailBundle registerBundle]
    
    // At this point, the preference panel has been registered by -[GPGMailBundle registerBundle]
    // if a second plugin is available and has been loaded first, so it's safe, to trust the
    // bundles registered in preference owners.
    // Only if GPGMail's NSPreferencesModule is not yet present, it will be registered.
    NSPreferences *preferences = [NSClassFromString(@"MailPreferences") sharedPreferences];
    NSPreferencesModule *gpgMailPreferences = [GPGMailPreferences sharedInstance];
    NSArray *preferencesModules = [preferences valueForKey:@"_preferenceOwners"];
    NSString *panelName = [GPGMailBundle preferencesPanelName];

    // Register the preference panel if it's not already registered.
    if(![preferencesModules containsObject:gpgMailPreferences]) {
        [preferences addPreferenceNamed:panelName
                                  owner:gpgMailPreferences];
    }
    return [self MAMakePreferenceTabViewItems];
}

@end
