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

#import "BeaconRegionInputViewController.h"

@interface BeaconRegionInputViewController ()

@end

@implementation BeaconRegionInputViewController

#pragma mark - life cycle

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        self.isViewAdjustForKeyboard = YES;
    }
    return self;
}

- (void)dealloc
{
    self.textboxUUID.delegate = nil;
    self.textboxMajor.delegate = nil;
    self.textboxMinor.delegate = nil;
    self.textboxIdentifier.delegate = nil;
}

- (void)viewDidUnload
{
    [self setTextboxUUID:nil];
    [self setTextboxMajor:nil];
    [self setTextboxMinor:nil];
    [self setTextboxIdentifier:nil];
    [super viewDidUnload];
}

#pragma mark - event handler

- (IBAction)buttonAddClicked:(id)sender
{
    NSString *uuid = [self.textboxUUID.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (uuid == nil || uuid.length == 0)
    {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Warning" message:@"Please input Proximity UUID." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alertView show];
        return;
    }
    NSUUID *proximityUUID = [[NSUUID alloc] initWithUUIDString:uuid];
    NSInteger major = -1; //valid iBeacon major is from 0~65535, if input -1 major=65535, if input 65536 major=0. Defined as CLBeaconMajorValue.
    if (self.textboxMajor.text != nil && self.textboxMajor.text.length > 0)
    {
        major = [self.textboxMajor.text integerValue];  //input field is number, cannot input others
        if (major < 0 || major > 65535)
        {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Warning" message:@"Major is from 0 to 65535." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alertView show];
            return;
        }
    }
    NSInteger minor = -1; //valid iBeacon minor is from 0~65535, if input -1 minor=65535, if input 65536 minor=0. Defined as CLBeaconMinorValue.
    if (self.textboxMinor.text != nil && self.textboxMinor.text.length > 0)
    {
        minor = [self.textboxMinor.text integerValue];   //input field is number, cannot input others
        if (minor < 0 || minor > 65535)
        {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Warning" message:@"Minor is from 0 to 65535." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alertView show];
            return;
        }
    }
    if (major == -1 && minor != -1)
    {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Warning" message:@"Please input major if you want to use minor." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alertView show];
        return;
    }
    CLBeaconRegion *region = nil;
    if (minor >= 0)
    {
        region = [[CLBeaconRegion alloc] initWithProximityUUID:proximityUUID major:major minor:minor identifier:NONULL(self.textboxIdentifier.text)];
    }
    else if (major >= 0)
    {
        region = [[CLBeaconRegion alloc] initWithProximityUUID:proximityUUID major:major identifier:NONULL(self.textboxIdentifier.text)];
    }
    else
    {
        region = [[CLBeaconRegion alloc] initWithProximityUUID:proximityUUID identifier:NONULL(self.textboxIdentifier.text)];
    }
    if (region == nil)
    {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Warning" message:@"Your input value is not valid for an iBeacon range, check UUID." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alertView show];
        return;
    }
    if (self.inputHandler)
    {
        self.inputHandler(region);
    }
    [self dismissOnTop];
}

- (IBAction)buttonCancelClicked:(id)sender
{
    [self dismissOnTop];
}

#pragma mark - UITextFieldDelegate handler

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

@end
