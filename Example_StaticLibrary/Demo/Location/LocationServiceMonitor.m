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

#import "LocationServiceMonitor.h"
#import <CoreLocation/CoreLocation.h>

@interface LocationServiceMonitor ()

- (void)startStandardUpdateHandler:(NSNotification *)notification;
- (void)stopStandardUpdateHandler:(NSNotification *)notification;
- (void)startSignificantUpdateHandler:(NSNotification *)notification;
- (void)stopSignificantUpdateHandler:(NSNotification *)notification;
- (void)startMonitorRegionHandler:(NSNotification *)notification;
- (void)stopMonitorRegionHandler:(NSNotification *)notification;
- (void)startRangeBeaconRegionHandler:(NSNotification *)notification;
- (void)stopRangeBeaconRegionHandler:(NSNotification *)notification;

- (void)locationUpdateSuccessHandler:(NSNotification *)notification;
- (void)locationUpdateFailHandler:(NSNotification *)notification;
- (void)enterRegionHandler:(NSNotification *)notification;
- (void)exitRegionHandler:(NSNotification *)notification;
- (void)regionStateChangeHandler:(NSNotification *)notification;
- (void)monitorRegionSuccessHandler:(NSNotification *)notification;
- (void)monitorRegionFailHandler:(NSNotification *)notification;
- (void)beaconFoundHandler:(NSNotification *)notification;
- (void)rangeBeaconFailHandler:(NSNotification *)notification;
- (void)changeAuthStatusHandler:(NSNotification *)notification;

@end

@implementation LocationServiceMonitor

#pragma mark - life cycle

+ (id)shared
{
    static LocationServiceMonitor *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^ {
        instance = [[LocationServiceMonitor alloc] init];
    });
    return instance;
}

- (id)init
{
    if (self = [super initWithLogFileName:@"LocationLogs"])
    {
        //listen to location service notification
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startStandardUpdateHandler:) name:SHLMStartStandardMonitorNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopStandardUpdateHandler:) name:SHLMStopStandardMonitorNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startSignificantUpdateHandler:) name:SHLMStartSignificantMonitorNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopSignificantUpdateHandler:) name:SHLMStopSignificantMonitorNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startMonitorRegionHandler:) name:SHLMStartMonitorRegionNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopMonitorRegionHandler:) name:SHLMStopMonitorRegionNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startRangeBeaconRegionHandler:) name:SHLMStartRangeiBeaconRegionNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopRangeBeaconRegionHandler:) name:SHLMStopRangeiBeaconRegionNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(locationUpdateSuccessHandler:) name:SHLMUpdateLocationSuccessNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(locationUpdateFailHandler:) name:SHLMUpdateFailNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(enterRegionHandler:) name:SHLMEnterRegionNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(exitRegionHandler:) name:SHLMExitRegionNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(regionStateChangeHandler:) name:SHLMRegionStateChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(monitorRegionSuccessHandler:) name:SHLMMonitorRegionSuccessNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(monitorRegionFailHandler:) name:SHLMMonitorRegionFailNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(beaconFoundHandler:) name:SHLMRangeiBeaconChangedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rangeBeaconFailHandler:) name:SHLMRangeiBeaconFailNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeAuthStatusHandler:) name:SHLMChangeAuthorizationStatusNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - location service notification handler

- (void)startStandardUpdateHandler:(NSNotification *)notification
{
    [self writeToLogFileAndPostNotification:@"Start monitoring standard geolocation change."];
}

- (void)stopStandardUpdateHandler:(NSNotification *)notification
{
    [self writeToLogFileAndPostNotification:@"Stop monitoring standard geolocation change."];
}

- (void)startSignificantUpdateHandler:(NSNotification *)notification
{
    [self writeToLogFileAndPostNotification:@"Start monitoring significant geolocation change."];
}

- (void)stopSignificantUpdateHandler:(NSNotification *)notification
{
    [self writeToLogFileAndPostNotification:@"Stop monitoring significant geolocation change."];
}

- (void)startMonitorRegionHandler:(NSNotification *)notification
{
    CLRegion *region = (notification.userInfo)[SHLMNotification_kRegion];
    [self writeToLogFileAndPostNotification:[NSString stringWithFormat:@"Start to monitor region: %@.", region.description]];
}

- (void)stopMonitorRegionHandler:(NSNotification *)notification
{
    CLRegion *region = (notification.userInfo)[SHLMNotification_kRegion];
    [self writeToLogFileAndPostNotification:[NSString stringWithFormat:@"Stop monitoring region: %@.", region.description]];
}

- (void)startRangeBeaconRegionHandler:(NSNotification *)notification
{
    CLRegion *region = (notification.userInfo)[SHLMNotification_kRegion];
    [self writeToLogFileAndPostNotification:[NSString stringWithFormat:@"Start to range one iBeacon region: %@.", region.description]];
}

- (void)stopRangeBeaconRegionHandler:(NSNotification *)notification
{
    CLRegion *region = (notification.userInfo)[SHLMNotification_kRegion];
    [self writeToLogFileAndPostNotification:[NSString stringWithFormat:@"Stop ranging one iBeacon region: %@.", region.description]];
}

- (void)locationUpdateSuccessHandler:(NSNotification *)notification
{
    CLLocation *newLocation = (notification.userInfo)[SHLMNotification_kNewLocation];
    CLLocation *oldLocation = (notification.userInfo)[SHLMNotification_kOldLocation];
    [self writeToLogFileAndPostNotification:[NSString stringWithFormat:@"Update success from (%.4f, %.4f) to (%.4f, %.4f).", oldLocation.coordinate.latitude, oldLocation.coordinate.longitude, newLocation.coordinate.latitude, newLocation.coordinate.longitude]];
}

- (void)locationUpdateFailHandler:(NSNotification *)notification
{
    NSError *error = (notification.userInfo)[SHLMNotification_kError];
    [self writeToLogFileAndPostNotification:[NSString stringWithFormat:@"Update fail: %@.", error.localizedDescription]];
}

- (void)enterRegionHandler:(NSNotification *)notification
{
    CLRegion *region = (notification.userInfo)[SHLMNotification_kRegion];
    [self writeToLogFileAndPostNotification:[NSString stringWithFormat:@"Enter region: %@.", region.description]];
}

- (void)exitRegionHandler:(NSNotification *)notification
{
    CLRegion *region = (notification.userInfo)[SHLMNotification_kRegion];
    [self writeToLogFileAndPostNotification:[NSString stringWithFormat:@"Exit region: %@.", region.description]];
}

- (void)regionStateChangeHandler:(NSNotification *)notification
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
    [self writeToLogFileAndPostNotification:[NSString stringWithFormat:@"State change to %@ for region: %@.", strState, region.description]];
}

- (void)monitorRegionSuccessHandler:(NSNotification *)notification
{
    CLRegion *region = (notification.userInfo)[SHLMNotification_kRegion];
    [self writeToLogFileAndPostNotification:[NSString stringWithFormat:@"Successfully start monitoring region: %@.", region.description]];
}

- (void)monitorRegionFailHandler:(NSNotification *)notification
{
    CLRegion *region = (notification.userInfo)[SHLMNotification_kRegion];
    NSError *error = (notification.userInfo)[SHLMNotification_kError];
    [self writeToLogFileAndPostNotification:[NSString stringWithFormat:@"Fail to monitor region %@ due to error: %@.", region.description, error.localizedDescription]];
}

- (void)beaconFoundHandler:(NSNotification *)notification
{
    CLRegion *region = (notification.userInfo)[SHLMNotification_kRegion];
    NSArray *arrayBeacons = (notification.userInfo)[SHLMNotification_kBeacons];
    [self writeToLogFileAndPostNotification:[NSString stringWithFormat:@"Found beacons in region %@: %@.", region.description, arrayBeacons]];
}
     
- (void)rangeBeaconFailHandler:(NSNotification *)notification
{
    CLRegion *region = (notification.userInfo)[SHLMNotification_kRegion];
    NSError *error = (notification.userInfo)[SHLMNotification_kError];
    [self writeToLogFileAndPostNotification:[NSString stringWithFormat:@"Fail to range iBeacon region %@ due to error: %@.", region.description, error.localizedDescription]];
}

- (void)changeAuthStatusHandler:(NSNotification *)notification
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
    [self writeToLogFileAndPostNotification:[NSString stringWithFormat:@"Authorization status change to: %@.", authStatus]];
}

@end
