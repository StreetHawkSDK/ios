/*
 * Copyright (c) StreetHawk, All rights reserved.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 3.0 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library.
 */

#import "SHInstallHandler.h"
//header from StreetHawk
#import "SHInstall.h" //for SHInstall notification definitions
#import "SHAppStatus.h" //for `sendAppStatusCheckRequest`
#import "SHUtils.h" //for SHLog

@implementation SHInstallHandler

#pragma mark - life cycle

- (id)init
{
    if ((self = [super init]))
    {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(installRegistrationSucceeded:) name:SHInstallRegistrationSuccessNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(installRegistrationFailure:) name:SHInstallRegistrationFailureNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(installUpdateSucceeded:) name:SHInstallUpdateSuccessNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(installUpdateFailure:) name:SHInstallUpdateFailureNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - install notification handlers

- (void)installRegistrationSucceeded:(NSNotification *)aNotification
{
    SHInstall *install = (aNotification.userInfo)[SHInstallNotification_kInstall];
    SHLog(@"Install register succeed with new id: %@", install.suid);
    [[SHAppStatus sharedInstance] sendAppStatusCheckRequest:YES completeHandler:nil/*mark it force so that make sure to contain install id and do again*/]; //first fresh install app/status/ does not have install id, thus submit_views is false; as long as register and get install id, need to refresh app/status/ again and do submit_views.
}

- (void)installRegistrationFailure:(NSNotification *)aNotification
{
    NSError *error = (aNotification.userInfo)[SHInstallNotification_kError];
    SHLog(@"Install register fail with error: %@", error);
}

- (void)installUpdateSucceeded:(NSNotification *)aNotification
{
    SHInstall *install = (aNotification.userInfo)[SHInstallNotification_kInstall];
    SHLog(@"Install update succeed with id: %@", install.suid);
    //note: after install/update, not call "registerForRemoteNotification", because "registerForRemoteNotification" calls install/update after: a)successfully register and get new token; b)unregister and send install/update with revoked.
}

- (void)installUpdateFailure:(NSNotification *)aNotification
{
    SHInstall *install = (aNotification.userInfo)[SHInstallNotification_kInstall];
    NSError *error = (aNotification.userInfo)[SHInstallNotification_kError];
    SHLog(@"Install %@ update fail with error: %@", install.suid, error);
}

@end
