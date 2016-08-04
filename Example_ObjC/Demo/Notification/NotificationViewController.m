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

#import "NotificationViewController.h"

@interface NotificationViewController ()

@property (retain, nonatomic) IBOutlet UIButton *buttonSetEnabled;
@property (strong, nonatomic) IBOutlet UITextField *textboxAlertSettings;

- (IBAction)buttonSetEnabledClicked:(id)sender;
- (IBAction)buttonCheckNotificationPermissionClicked:(id)sender;
- (IBAction)buttonSetAlertClicked:(id)sender;
- (IBAction)buttonGetAlertSettingsClicked:(id)sender;

@end

@implementation NotificationViewController

#pragma mark - life cycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.buttonSetEnabled setTitle:StreetHawk.isNotificationEnabled ? @"SDK API enables Notification now" : @"SDK API disables Notification now" forState:UIControlStateNormal];
}

#pragma mark - event handler

- (IBAction)buttonSetEnabledClicked:(id)sender
{
    StreetHawk.isNotificationEnabled = !StreetHawk.isNotificationEnabled;
    [self.buttonSetEnabled setTitle:StreetHawk.isNotificationEnabled ? @"SDK API enables Notification now" : @"SDK API disables Notification now" forState:UIControlStateNormal];
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

- (IBAction)buttonSetAlertClicked:(id)sender
{
    [self.textboxAlertSettings resignFirstResponder];
    NSInteger pauseMinutes = [self.textboxAlertSettings.text integerValue];
    //pauseMinutes <= 0 means not pause
    //pauseMinutes >= StreetHawk_AlertSettings_Forever means pause forever
    [StreetHawk shSetAlertSetting:pauseMinutes finish:^(NSObject *result, NSError *error)
    {
        dispatch_async(dispatch_get_main_queue(), ^
           {
               if (error)
               {
                   UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Fail to setup alert settings!" message:error.localizedDescription delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
                   [alert show];
               }
               else
               {
                   UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Save alert settings successfully!" message:nil delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
                   [alert show];
               }
           });
    }];
}

- (IBAction)buttonGetAlertSettingsClicked:(id)sender
{
    [self.textboxAlertSettings resignFirstResponder];
    NSInteger pauseMinutes = [StreetHawk getAlertSettingMinutes];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:@"Pause %ld minutes.", (long)pauseMinutes] message:nil delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
    [alert show];
}

@end
