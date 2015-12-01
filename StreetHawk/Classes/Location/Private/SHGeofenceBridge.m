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

#import "SHGeofenceBridge.h"
//header from StreetHawk
#import "SHApp+Location.h"
#import "SHLocationManager.h"
#import "SHGeofenceStatus.h"

@interface SHGeofenceBridge ()

+ (void)createLocationManagerHandler:(NSNotification *)notification;
+ (void)setGeofenceTimestampHandler:(NSNotification *)notification; //handle app_status set geofence timestamp. notification name: SH_LMBridge_SetGeofenceTimestamp; user info: @{@"timestamp": NONULL(geofenceTimestamp)}.

@end

@implementation SHGeofenceBridge

+ (void)bridgeHandler:(NSNotification *)notification
{
    //initialise variables, move from SHApp's init.
    StreetHawk.isDefaultLocationServiceEnabled = YES;
    StreetHawk.reportWorkHomeLocationOnly = NO;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(createLocationManagerHandler:) name:@"SH_LMBridge_CreateLocationManager" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setGeofenceTimestampHandler:) name:@"SH_LMBridge_SetGeofenceTimestamp" object:nil];
}

#pragma mark - private functions

+ (void)createLocationManagerHandler:(NSNotification *)notification
{
    if (StreetHawk.locationManager == nil)
    {
        StreetHawk.locationManager = [SHLocationManager sharedInstance];  //cannot move to `init` because it starts `startMonitorGeoLocationStandard` when create.
    }
}

+ (void)setGeofenceTimestampHandler:(NSNotification *)notification
{
    NSString *timestamp = notification.userInfo[@"timestamp"];
    [SHGeofenceStatus sharedInstance].geofenceTimestamp = timestamp;
}

@end
