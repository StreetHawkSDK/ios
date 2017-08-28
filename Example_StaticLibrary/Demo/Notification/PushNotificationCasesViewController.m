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

#import "PushNotificationCasesViewController.h"
#import "MBProgressHUD.h"
#import <MessageUI/MessageUI.h>

@interface PushNotificationCasesViewController () <MFMailComposeViewControllerDelegate>

//show push notification information to UI.
- (void)displayPushNotificationInfo;
//install notification to update access token and mode.
- (void)installRegisterSuccessHandler:(NSNotification *)notification;
- (void)installUpdateSuccessHandler:(NSNotification *)notification;

@end

@implementation PushNotificationCasesViewController

#pragma mark - life cycle

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(installRegisterSuccessHandler:) name:SHInstallRegistrationSuccessNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(installUpdateSuccessHandler:) name:SHInstallUpdateSuccessNotification object:nil];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self displayPushNotificationInfo];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidUnload
{
    [self setLabelToken:nil];
    [self setLabelMode:nil];
    [self setButtonSetAlert:nil];
    [self setLabelRevoked:nil];
    [self setButtonSetEnabled:nil];
    [super viewDidUnload];
}

#pragma mark - event handler

- (IBAction)buttonSetEnabledClicked:(id)sender
{
    StreetHawk.isNotificationEnabled = !StreetHawk.isNotificationEnabled;
    [self.buttonSetEnabled setTitle:StreetHawk.isNotificationEnabled ? @"Notification is Enabled now" : @"Notification is Disabled now" forState:UIControlStateNormal];
}

- (IBAction)buttonCheckNotificationPermissionClicked:(id)sender
{
    if (StreetHawk.systemPreferenceDisableNotification)
    {
        if (![StreetHawk launchSystemPreferenceSettings])
        {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Info" message:@"Pre-iOS 8 show self made instruction." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alertView show];
        }
    }
    else
    {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Info" message:@"No need to show enable notification preference." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alertView show];
    }
}

#pragma mark - private functions

- (void)displayPushNotificationInfo
{
    if (self.isViewLoaded)
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
#if TARGET_IPHONE_SIMULATOR
            self.labelToken.text = @"Not applicable for simulator";
#else
            self.labelToken.text = StreetHawk.currentInstall.pushNotificationToken;
#endif
            self.labelMode.text = StreetHawk.currentInstall.mode;
            self.labelRevoked.text = StreetHawk.currentInstall.revoked;
            [self.buttonSetEnabled setTitle:StreetHawk.isNotificationEnabled ? @"Notification is Enabled now" : @"Notification is Disabled now" forState:UIControlStateNormal];
        });
    }
}

- (void)installRegisterSuccessHandler:(NSNotification *)notification
{
    [self displayPushNotificationInfo];
}

- (void)installUpdateSuccessHandler:(NSNotification *)notification
{
    [self displayPushNotificationInfo];
}

@end

