/*
* Copyright (c) 2021, GPGTools GmbH <team@gpgtools.org>
* All rights reserved.
* Redistribution and use in source and binary forms, with or without
* modification, are permitted provided that the following conditions are met:
*
*     * Redistributions of source code must retain the above copyright
*       notice, this list of conditions and the following disclaimer.
*     * Redistributions in binary form must reproduce the above copyright
*       notice, this list of conditions and the following disclaimer in the
*       documentation and/or other materials provided with the distribution.
*     * Neither the name of GPGTools nor the names of GPGMail
*       contributors may be used to endorse or promote products
*       derived from this software without specific prior written permission.
*
* THIS SOFTWARE IS PROVIDED BY GPGTools ``AS IS'' AND ANY
* EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
* WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
* DISCLAIMED. IN NO EVENT SHALL GPGTools BE LIABLE FOR ANY
* DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
* (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
* LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
* ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
* (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
* SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import "NSArray+Functional.h"
#import "GMLoaderUpdater.h"

#import "PlugInsViewController.h"
#import "MailBundle.h"

#import "PluginsViewController+GPGMail.h"

@implementation PlugInsViewController_GPGMail

- (void)MAViewWillAppear {
    [self MAViewWillAppear];

    // To facilitate a GPG Mail Loader update without asking the user
    // to re-activate it, two GPG Mail Loaders will be installed in parallel.
    // The user however should never see two loaders, since that would be confusing.
    // In order to make sure that only one is ever visible, all other GPG Mail Loaders
    // are hidden and only the active ones is shown.
    NSArray *bundlesToRemainVisible = [[self valueForKey:@"_bundles"] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(MailBundle *mailBundle, __unused NSDictionary<NSString *,id> * _Nullable bindings) {
        return ![GMLoaderUpdater isLoaderBundle:mailBundle] || [mailBundle state] == 2;
    }]];

    [self setValue:bundlesToRemainVisible forKey:@"_bundles"];
    [[self valueForKey:@"_tableView"] reloadData];
    [(PlugInsViewController *)self _updateApplyButton];
}

@end
