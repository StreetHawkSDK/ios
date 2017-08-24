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
#import "BaseLogMonitor.h"
#import "MBProgressHUD.h"
#import <MessageUI/MessageUI.h>

@interface LogModeHandler : NSObject<ISHCustomiseHandler>

@property (nonatomic, strong) BaseLogMonitor *logger;

@end

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

- (IBAction)buttonSetAlertClicked:(id)sender
{
    SHAlertSettingsViewController *alertSettingsVC = [[SHAlertSettingsViewController alloc] initWithNibName:nil bundle:nil];
    [alertSettingsVC presentOnTopWithCover:YES withCoverColor:nil withCoverAlpha:0 withDelay:YES withCoverTouchHandler:nil withAnimationHandler:nil withOrientationChangedHandler:nil];
}

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

- (IBAction)buttonTurnOnLogmodeClicked:(id)sender
{
    LogModeHandler *handler = [[LogModeHandler alloc] init];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Notification is handled by Log Mode!" message:@"Kill App and relaunch will turn back to normal mode." delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
    [StreetHawk shSetCustomiseHandler:handler];
    [alert show];
}

- (IBAction)buttonSendLogClicked:(id)sender
{
    if ([MFMailComposeViewController canSendMail])
    {
        BaseLogMonitor *logger = [[BaseLogMonitor alloc] initWithLogFileName:@"NotificationLogs"];
        MFMailComposeViewController *mc = [[MFMailComposeViewController alloc] init];
        mc.mailComposeDelegate = self;
        [mc setMessageBody:[logger logHistoryContent:nil] isHTML:NO];
        [mc setSubject:[NSString stringWithFormat:@"Notification logs sent on %@", shFormatStreetHawkDate([NSDate date])]];
        [self presentViewController:mc animated:YES completion:nil];
    }
    else
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Cannot send email" message:@"Please check email is configured and ready to use." delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
        [alert show];
    }
}

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    if (!error)
    {
        [controller dismissViewControllerAnimated:YES completion:nil];
        SHAlertView *alertView = [[SHAlertView alloc] initWithTitle:@"Delete local logs?" message:@"Do you want to delete local caches, next will start from new text?" withHandler:^(UIAlertView *view, NSInteger buttonIndex)
          {
              if (buttonIndex != view.cancelButtonIndex)
              {
                  BaseLogMonitor *logger = [[BaseLogMonitor alloc] initWithLogFileName:@"NotificationLogs"];
                  [logger clearLogHistory:nil];
              }
          } cancelButtonTitle:@"No" otherButtonTitles:@"Yes"];
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

@implementation LogModeHandler

#pragma mark - life cycle

- (id)init
{
    if (self = [super init])
    {
        self.logger = [[BaseLogMonitor alloc] initWithLogFileName:@"NotificationLogs"];
    }
    return self;
}

#pragma mark - override functions

- (BOOL)onReceive:(PushDataForApplication *)pushData clickButton:(ClickButtonHandler)handler
{
    //not process normal UI stuff, only show a message to let user know notification arrives.
    NSString *alert = shAppendString(pushData.title, pushData.message);
    UIWindow *topWindow = [UIApplication sharedApplication].windows[0];
    MBProgressHUD *infoView = [MBProgressHUD showHUDAddedTo:topWindow animated:YES];
    infoView.mode = MBProgressHUDModeText; //only show result text, not show progress bar.
    infoView.labelText = alert;
    [infoView hide:YES afterDelay:1];
    //log notification alert locally.
    [self.logger writeToLogFileAndPostNotification:alert];
    return YES;
}

@end

