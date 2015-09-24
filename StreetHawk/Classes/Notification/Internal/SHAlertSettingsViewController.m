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

#import "SHAlertSettingsViewController.h"
//header from StreetHawk
#import "SHApp+Notification.h" //for `StreetHawk`
#import "SHAlertView.h" //for confirm dialog
#import "SHUtils.h" //for shPresentErrorAlert
#import "SHPresentDialog.h" //for present modal dialog

@interface SHAlertSettingsViewController ()

@property (nonatomic) NSInteger pauseMinutes; //memory used pause minutes.

//display alert settings to UI.
- (void)displayAlertSettingsInfo:(NSDate *)pauseUntil;

@end

@implementation SHAlertSettingsViewController

#pragma mark - life cycle

-(id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        self.isViewAdjustForKeyboard = YES;
    }
    return self;
}


-(void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor lightGrayColor];
    //Load alert settings from server and update UI
    [StreetHawk getAlertSettingPauseUntil:^(NSObject *result, NSError *error)
    {
        shPresentErrorAlert(error, YES);
        if (error == nil)
        {
            self.pauseMinutes = [StreetHawk getAlertSettingMinutes];
            [self displayAlertSettingsInfo:(NSDate *)result];
        }
    }];
}

#pragma mark - event handle

- (IBAction)switchPauseValueChanged:(id)sender
{
    if (self.switchPause.on)
    {
        NSArray *options = @[@"Not paused", @"Pause for an hour", @"Pause for 2 hours", @"Pause for 4 hours", @"Pause for 8 hours", @"Pause for a day", @"Pause forever"];
        NSArray *minutes = @[@0, @60, @120, @240, @480, @1440, @SHAlertSettings_Forever];
        NSAssert(options.count == minutes.count, @"Pause option not match minutes");
        SHAlertView *alertView = [[SHAlertView alloc] initWithTitle:@"Pause from now" message:nil withHandler:^(UIAlertView *view, NSInteger buttonIndex)
        {
            if (buttonIndex != view.cancelButtonIndex)
            {
                self.pauseMinutes = [minutes[buttonIndex - 1] intValue];
                NSDate *pauseUntil = nil;
                if (self.pauseMinutes < SHAlertSettings_Forever && self.pauseMinutes > 0)
                {
                    pauseUntil = [NSDate dateWithTimeIntervalSinceNow:self.pauseMinutes * 60];
                }
                else if (self.pauseMinutes >= SHAlertSettings_Forever)
                {
                    pauseUntil = [NSDate distantFuture]; //pause forever
                }
                else
                {
                    pauseUntil = [NSDate date];  //not pause
                }
                [self displayAlertSettingsInfo:pauseUntil];
            }
        } cancelButtonTitle:@"Cancel" otherButtonTitles:nil];
        for (NSString *option in options)
        {
            [alertView addButtonWithTitle:option];
        }
        [alertView show];
    }
    else
    {
        self.pauseMinutes = 0;
        [self displayAlertSettingsInfo:[NSDate date]];
    }
}

- (IBAction)buttonSaveClicked:(id)sender
{
    self.buttonSave.enabled = NO;
    self.buttonCancel.enabled = NO;
    [StreetHawk shSetAlertSetting:self.pauseMinutes finish:^(NSObject *result, NSError *error)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            shPresentErrorAlert(error, YES);
            self.buttonSave.enabled = YES;
            self.buttonCancel.enabled = YES;
            if (error == nil)
            {
                [self dismissModalDialogViewController];
            }
        });
    }];
}

- (IBAction)buttonCancelClicked:(id)sender
{
    [self dismissModalDialogViewController];
}

#pragma mark - private functions

- (void)displayAlertSettingsInfo:(NSDate *)pauseUntil
{
    if (self.isViewLoaded)
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [self.switchPause removeTarget:self action:@selector(switchPauseValueChanged:) forControlEvents:UIControlEventValueChanged];
            self.switchPause.on = self.pauseMinutes > 0;
            [self.switchPause addTarget:self action:@selector(switchPauseValueChanged:) forControlEvents:UIControlEventValueChanged];
            self.labelPause.hidden = !self.switchPause.on;
            if (self.pauseMinutes < SHAlertSettings_Forever && self.pauseMinutes > 0)
            {
                NSDateFormatter *dateFormat = shGetDateFormatter(nil, [NSTimeZone localTimeZone], nil);
                self.labelPause.text = [NSString stringWithFormat:@"Pause till %@", [dateFormat stringFromDate:pauseUntil]];
            }
            else
            {
                self.labelPause.text = @"Pause forever";
            }
        });
    }
}

@end
