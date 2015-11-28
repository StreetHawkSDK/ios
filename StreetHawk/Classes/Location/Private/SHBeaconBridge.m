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

#import "SHBeaconBridge.h"
//header from StreetHawk
#import "SHApp+Location.h"
#import "SHLocationManager.h"
#import "SHTypes.h" //for SH_BEACON_BLUETOOTH

@interface SHBeaconBridge (private)

+ (void)createLocationManagerHandler:(NSNotification *)notification;
+ (void)updateBluetoothStatusHandler:(NSNotification *)notification; //update bluetooth status to NSUserDefaults "SH_BEACON_BLUETOOTH". notification name: SH_LMBridge_UpdateBluetoothStatus; user info: empty.

@end

@implementation SHBeaconBridge

+ (void)bridgeHandler:(NSNotification *)notification
{
    //initialise variables, move from SHApp's init.
    StreetHawk.isDefaultLocationServiceEnabled = YES;
    StreetHawk.reportWorkHomeLocationOnly = NO;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(createLocationManagerHandler:) name:@"SH_LMBridge_CreateLocationManager" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateBluetoothStatusHandler:) name:@"SH_LMBridge_UpdateBluetoothStatus" object:nil];
}

#pragma mark - private functions

+ (void)createLocationManagerHandler:(NSNotification *)notification
{
    if (StreetHawk.locationManager == nil)
    {
        StreetHawk.locationManager = [SHLocationManager sharedInstance];  //cannot move to `init` because it starts `startMonitorGeoLocationStandard` when create.
    }
}

+ (void)updateBluetoothStatusHandler:(NSNotification *)notification
{
    [[NSUserDefaults standardUserDefaults] setObject:@(StreetHawk.locationManager.bluetoothState) forKey:SH_BEACON_BLUETOOTH];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end
