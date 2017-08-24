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

#import "InstallServiceMonitor.h"

@interface InstallServiceMonitor ()

- (void)installRegisterSuccessHandler:(NSNotification *)notification;
- (void)installRegisterFailHandler:(NSNotification *)notification;
- (void)installUpdateSuccessHandler:(NSNotification *)notification;
- (void)installUpdateFailHandler:(NSNotification *)notification;

@end

@implementation InstallServiceMonitor

#pragma mark - life cycle

+ (id)shared
{
    static InstallServiceMonitor *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^ {
        instance = [[InstallServiceMonitor alloc] init];
    });
    return instance;
}

- (id)init
{
    if (self = [super initWithLogFileName:@"InstallLogs"])
    {
        //listen to install notification
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(installRegisterSuccessHandler:) name:SHInstallRegistrationSuccessNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(installRegisterFailHandler:) name:SHInstallRegistrationFailureNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(installUpdateSuccessHandler:) name:SHInstallUpdateSuccessNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(installUpdateFailHandler:) name:SHInstallUpdateFailureNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - install notification handler

- (void)installRegisterSuccessHandler:(NSNotification *)notification
{
    SHInstall *install = (notification.userInfo)[SHInstallNotification_kInstall];
    [self writeToLogFileAndPostNotification:[NSString stringWithFormat:@"Register successfully: %@.", install]];
}

- (void)installRegisterFailHandler:(NSNotification *)notification
{
    NSError *error = (notification.userInfo)[SHInstallNotification_kError];
    [self writeToLogFileAndPostNotification:[NSString stringWithFormat:@"Register fail due to error: %@.", error]];
}

- (void)installUpdateSuccessHandler:(NSNotification *)notification
{
    SHInstall *install = (notification.userInfo)[SHInstallNotification_kInstall];
    [self writeToLogFileAndPostNotification:[NSString stringWithFormat:@"Update successfully: %@.", install]];
}

- (void)installUpdateFailHandler:(NSNotification *)notification
{
    SHInstall *install = (notification.userInfo)[SHInstallNotification_kInstall];
    NSError *error = (notification.userInfo)[SHInstallNotification_kError];
    [self writeToLogFileAndPostNotification:[NSString stringWithFormat:@"Update install (%@) fail due to error: %@.", install, error]];
}

@end
