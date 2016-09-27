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
#import "SHBeaconStatus.h"
//header from System
#import <CoreBluetooth/CoreBluetooth.h>

@interface SHBeaconBridge ()

+ (void)createLocationManagerHandler:(NSNotification *)notification;
+ (void)updateBluetoothStatusHandler:(NSNotification *)notification; //update bluetooth status to NSUserDefaults "SH_BEACON_BLUETOOTH". notification name: SH_LMBridge_UpdateBluetoothStatus; user info: empty.
+ (void)updateiBeaconStatusHandler:(NSNotification *)notification; //update iBeacon support status to NSUserDefaults "SH_BEACON_iBEACON". notification name: SH_LMBridge_UpdateiBeaconStatus; user info: empty.
+ (void)setIBeaconTimestampStatusHandler:(NSNotification *)notification; //for handle app_status's iBeacon timestamp. notification name: SH_LMBridge_SetIBeaconTimestamp; user info: @{@"timestamp": NONULL(iBeaconTimestamp)}].
+ (void)updateLocationPermissionStatusHandler:(NSNotification *)notification; //update location permission status to NSUserDefauts "SH_LOCATION_STATUS". notification name: SH_LMBridge_UpdateLocationPermissionStatus; user info: empty.
+ (void)launchBluetoothSettingsPreference:(NSNotification *)notification; //launch blue settings in system preference page. notification name: SH_LMBridge_LaunchBluetoothSettings; user info: empty.

@end

@implementation SHBeaconBridge

+ (void)bridgeHandler:(NSNotification *)notification
{
    //initialise variables, move from SHApp's init.
    StreetHawk.isDefaultLocationServiceEnabled = YES;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(createLocationManagerHandler:) name:@"SH_LMBridge_CreateLocationManager" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateBluetoothStatusHandler:) name:@"SH_LMBridge_UpdateBluetoothStatus" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateiBeaconStatusHandler:) name:@"SH_LMBridge_UpdateiBeaconStatus" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setIBeaconTimestampStatusHandler:) name:@"SH_LMBridge_SetIBeaconTimestamp" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLocationPermissionStatusHandler:) name:@"SH_LMBridge_UpdateLocationPermissionStatus" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(launchBluetoothSettingsPreference:) name:@"SH_LMBridge_LaunchBluetoothSettings" object:nil];
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
    [[NSUserDefaults standardUserDefaults] setObject:@([SHBeaconStatus sharedInstance].bluetoothState) forKey:SH_BEACON_BLUETOOTH];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (void)updateiBeaconStatusHandler:(NSNotification *)notification
{
    [[NSUserDefaults standardUserDefaults] setObject:@([SHBeaconStatus sharedInstance].iBeaconSupportState) forKey:SH_BEACON_iBEACON];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (void)setIBeaconTimestampStatusHandler:(NSNotification *)notification
{
    NSString *timestamp = notification.userInfo[@"timestamp"];
    [SHBeaconStatus sharedInstance].iBeaconTimestamp = timestamp;
}

+ (void)updateLocationPermissionStatusHandler:(NSNotification *)notification
{
    [[NSUserDefaults standardUserDefaults] setObject:@(StreetHawk.systemPreferenceDisableLocation) forKey:SH_LOCATION_STATUS];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (void)launchBluetoothSettingsPreference:(NSNotification *)notification
{
    if ([CBCentralManager instancesRespondToSelector:@selector(initWithDelegate:queue:options:)])  //`options` since iOS 7.0, this push is to warning user to turn on Bluetooth for iBeacon, available since iOS 7.0.
    {
        CBCentralManager *tempManager = [[CBCentralManager alloc] initWithDelegate:nil queue:nil options:@{CBCentralManagerOptionShowPowerAlertKey: @(1/*show setting*/)}];
        tempManager = nil;
    }
}

@end
