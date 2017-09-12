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

#import "LocationViewController.h"
#import <CoreLocation/CoreLocation.h>

@interface LocationViewController ()

@property (strong, nonatomic) IBOutlet UIButton *buttonEnable;

- (IBAction)buttonOpenSettingsClicked:(id)sender;
- (IBAction)buttonEnableClicked:(id)sender;

- (void)updateLocationSuccessNotificationHandler:(NSNotification *)notification;
- (void)updateFailNotificationHandler:(NSNotification *)notification;
- (void)enterRegionNotificationHandler:(NSNotification *)notification;
- (void)exitRegionNotificationHandler:(NSNotification *)notification;
- (void)regionStateChangeNotificationHandler:(NSNotification *)notification;
- (void)monitorRegionSuccessNotificationHandler:(NSNotification *)notification;
- (void)monitorRegionFailNotificationHandler:(NSNotification *)notification;
- (void)rangeiBeaconNotificationHandler:(NSNotification *)notification;
- (void)rangeiBeaconFailNotificationHandler:(NSNotification *)notification;
- (void)authorizationStatusChangeNotificationHandler:(NSNotification *)notification;

- (void)startStandardLocationMonitorNotificationHandler:(NSNotification *)notification;
- (void)stopStandardLocationMonitorNotificationHandler:(NSNotification *)notification;
- (void)startSignificantLocationMonitorNotificationHandler:(NSNotification *)notification;
- (void)stopSignificantLocationMonitorNotificationHandler:(NSNotification *)notification;
- (void)startMonitorRegionNotificationHandler:(NSNotification *)notification;
- (void)stopMonitorRegionNotificationHandler:(NSNotification *)notification;
- (void)startRangeiBeaconRegionNotificationHandler:(NSNotification *)notification;
- (void)stopRangeiBeaconRegionNotificationHandler:(NSNotification *)notification;

@end

@implementation LocationViewController

#pragma mark - life cycle

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLocationSuccessNotificationHandler:) name:SHLMUpdateLocationSuccessNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateFailNotificationHandler:) name:SHLMUpdateFailNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(enterRegionNotificationHandler:) name:SHLMEnterRegionNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(exitRegionNotificationHandler:) name:SHLMExitRegionNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(regionStateChangeNotificationHandler:) name:SHLMRegionStateChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(monitorRegionSuccessNotificationHandler:) name:SHLMMonitorRegionSuccessNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(monitorRegionFailNotificationHandler:) name:SHLMMonitorRegionFailNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rangeiBeaconNotificationHandler:) name:SHLMRangeiBeaconChangedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rangeiBeaconFailNotificationHandler:) name:SHLMRangeiBeaconFailNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(authorizationStatusChangeNotificationHandler:) name:SHLMChangeAuthorizationStatusNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startStandardLocationMonitorNotificationHandler:) name:SHLMStartStandardMonitorNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopStandardLocationMonitorNotificationHandler:) name:SHLMStopStandardMonitorNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startSignificantLocationMonitorNotificationHandler:) name:SHLMStartSignificantMonitorNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopSignificantLocationMonitorNotificationHandler:) name:SHLMStopSignificantMonitorNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startMonitorRegionNotificationHandler:) name:SHLMStartMonitorRegionNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopMonitorRegionNotificationHandler:) name:SHLMStopMonitorRegionNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startRangeiBeaconRegionNotificationHandler:) name:SHLMStartRangeiBeaconRegionNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopRangeiBeaconRegionNotificationHandler:) name:SHLMStopRangeiBeaconRegionNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.buttonEnable setTitle:StreetHawk.isLocationServiceEnabled ? @"SDK API enables Location now" : @"SDK API disables Location now" forState:UIControlStateNormal];
}

#pragma mark - event handler

- (IBAction)buttonEnableClicked:(id)sender
{
    StreetHawk.isLocationServiceEnabled = !StreetHawk.isLocationServiceEnabled;
    [self.buttonEnable setTitle:StreetHawk.isLocationServiceEnabled ? @"SDK API enables Location now" : @"SDK API disables Location now" forState:UIControlStateNormal];
}

- (IBAction)buttonOpenSettingsClicked:(id)sender
{
    if (StreetHawk.systemPreferenceDisableLocation)
    {
        if (![StreetHawk launchSystemPreferenceSettings])
        {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Info" message:@"Pre-iOS 8 show self made instruction." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alertView show];
        }
    }
    else
    {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Info" message:@"System preference enables location now. No need to show location preference." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alertView show];
    }
}

#pragma mark - Location notification console log

- (void)updateLocationSuccessNotificationHandler:(NSNotification *)notification
{
    CLLocation *newLocation = (notification.userInfo)[SHLMNotification_kNewLocation];
    CLLocation *oldLocation = (notification.userInfo)[SHLMNotification_kOldLocation];
    NSLog(@"Update success from (%.4f, %.4f) to (%.4f, %.4f).", oldLocation.coordinate.latitude, oldLocation.coordinate.longitude, newLocation.coordinate.latitude, newLocation.coordinate.longitude);
}

- (void)updateFailNotificationHandler:(NSNotification *)notification
{
    NSError *error = (notification.userInfo)[SHLMNotification_kError];
    NSLog(@"Update fail: %@.", error.localizedDescription);
}

- (void)enterRegionNotificationHandler:(NSNotification *)notification
{
    CLRegion *region = (notification.userInfo)[SHLMNotification_kRegion];
    NSLog(@"Enter region: %@.", region.description);
}

- (void)exitRegionNotificationHandler:(NSNotification *)notification
{
    CLRegion *region = (notification.userInfo)[SHLMNotification_kRegion];
    NSLog(@"Exit region: %@.", region.description);
}

- (void)regionStateChangeNotificationHandler:(NSNotification *)notification
{
    CLRegion *region = (notification.userInfo)[SHLMNotification_kRegion];
    CLRegionState regionState = [(notification.userInfo)[SHLMNotification_kRegionState] intValue];
    NSString *strState = nil;
    switch (regionState)
    {
        case CLRegionStateUnknown:
            strState = @"\"unknown\"";
            break;
        case CLRegionStateInside:
            strState = @"\"inside\"";
            break;
        case CLRegionStateOutside:
            strState = @"\"outside\"";
            break;
        default:
            break;
    }
    NSLog(@"State change to %@ for region: %@.", strState, region.description);
}

- (void)monitorRegionSuccessNotificationHandler:(NSNotification *)notification
{
    CLRegion *region = (notification.userInfo)[SHLMNotification_kRegion];
    NSLog(@"Successfully start monitoring region: %@.", region.description);
}

- (void)monitorRegionFailNotificationHandler:(NSNotification *)notification
{
    CLRegion *region = (notification.userInfo)[SHLMNotification_kRegion];
    NSError *error = (notification.userInfo)[SHLMNotification_kError];
    NSLog(@"Fail to monitor region %@ due to error: %@.", region.description, error.localizedDescription);
}

- (void)rangeiBeaconNotificationHandler:(NSNotification *)notification
{
    CLRegion *region = (notification.userInfo)[SHLMNotification_kRegion];
    NSArray *arrayBeacons = (notification.userInfo)[SHLMNotification_kBeacons];
    NSLog(@"Found beacons in region %@: %@.", region.description, arrayBeacons);
}
          
- (void)rangeiBeaconFailNotificationHandler:(NSNotification *)notification
{
    CLRegion *region = (notification.userInfo)[SHLMNotification_kRegion];
    NSError *error = (notification.userInfo)[SHLMNotification_kError];
    NSLog(@"Fail to range iBeacon region %@ due to error: %@.", region.description, error.localizedDescription);
}

- (void)authorizationStatusChangeNotificationHandler:(NSNotification *)notification
{
    CLAuthorizationStatus status = [(notification.userInfo)[SHLMNotification_kAuthStatus] intValue];
    NSString *authStatus = nil;
    switch (status)
    {
        case kCLAuthorizationStatusNotDetermined:
            authStatus = @"Not determinded";
            break;
        case kCLAuthorizationStatusRestricted:
            authStatus = @"Restricted";
            break;
        case kCLAuthorizationStatusDenied:
            authStatus = @"Denied";
            break;
        case kCLAuthorizationStatusAuthorizedAlways: //equal kCLAuthorizationStatusAuthorized (3)
            authStatus = @"Always Authorized";
            break;
        case kCLAuthorizationStatusAuthorizedWhenInUse:
            authStatus = @"When in Use";
            break;
        default:
            break;
    }
    NSLog(@"Authorization status change to: %@.", authStatus);
}

- (void)startStandardLocationMonitorNotificationHandler:(NSNotification *)notification
{
    NSLog(@"Start monitoring standard geolocation change.");
}

- (void)stopStandardLocationMonitorNotificationHandler:(NSNotification *)notification
{
    NSLog(@"Stop monitoring standard geolocation change.");
}

- (void)startSignificantLocationMonitorNotificationHandler:(NSNotification *)notification
{
    NSLog(@"Start monitoring significant geolocation change.");
}

- (void)stopSignificantLocationMonitorNotificationHandler:(NSNotification *)notification
{
    NSLog(@"Stop monitoring significant geolocation change.");
}

- (void)startMonitorRegionNotificationHandler:(NSNotification *)notification
{
    CLRegion *region = (notification.userInfo)[SHLMNotification_kRegion];
    NSLog(@"Start to monitor region: %@.", region.description);
}

- (void)stopMonitorRegionNotificationHandler:(NSNotification *)notification
{
    CLRegion *region = (notification.userInfo)[SHLMNotification_kRegion];
    NSLog(@"Stop monitoring region: %@.", region.description);
}

- (void)startRangeiBeaconRegionNotificationHandler:(NSNotification *)notification
{
    CLRegion *region = (notification.userInfo)[SHLMNotification_kRegion];
    NSLog(@"Start to range one iBeacon region: %@.", region.description);
}

- (void)stopRangeiBeaconRegionNotificationHandler:(NSNotification *)notification
{
    CLRegion *region = (notification.userInfo)[SHLMNotification_kRegion];
    NSLog(@"Stop ranging one iBeacon region: %@.", region.description);
}

@end
