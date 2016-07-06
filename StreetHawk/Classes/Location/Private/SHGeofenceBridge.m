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
#import "SHLogger.h" //for sendLogForCode
#import "SHGeofenceStatus.h"

#define SH_GEOFENCE_LATLNG_SENTTIME @"SH_GEOFENCE_LATLNG_SENTTIME" //timestamp for recording last lat/lng sent time

@interface SHGeofenceBridge ()

+ (void)createLocationManagerHandler:(NSNotification *)notification;
+ (void)setGeofenceTimestampHandler:(NSNotification *)notification; //handle app_status set geofence timestamp. notification name: SH_LMBridge_SetGeofenceTimestamp; user info: @{@"timestamp": NONULL(geofenceTimestamp)}.

+ (void)startMonitorGeoLocationHandler:(NSNotification *)notification; //for start location monitor for lat/lng. notification name: SH_LMBridge_StartMonitorGeoLocation; user info: empty.
+ (void)stopMonitorGeoLocationHandler:(NSNotification *)notification; //for stop location monitor for lat/lng. notification name: SH_LMBridge_StopMonitorGeoLocation; user info: empty.
+ (void)updateGeolocationCacheHandler:(NSNotification *)notification; //for updating local NSUserDefaults to pass values between modules, use notification to update when necessary, not refresh local cache too often. notification name: SH_LMBridge_UpdateGeoLocation; user info: empty.
+ (void)sendGeolocationUpdateHandler:(NSNotification *)notification; //for sending logline 20. notification name: SH_LMBridge_SendGeoLocationLogline; user info: @{comment: <json_comment>}.

@end

@implementation SHGeofenceBridge

+ (void)bridgeHandler:(NSNotification *)notification
{
    //initialise variables, move from SHApp's init.
    StreetHawk.isDefaultLocationServiceEnabled = YES;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(createLocationManagerHandler:) name:@"SH_LMBridge_CreateLocationManager" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setGeofenceTimestampHandler:) name:@"SH_LMBridge_SetGeofenceTimestamp" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startMonitorGeoLocationHandler:) name:@"SH_LMBridge_StartMonitorGeoLocation" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopMonitorGeoLocationHandler:) name:@"SH_LMBridge_StopMonitorGeoLocation" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateGeolocationCacheHandler:) name:@"SH_LMBridge_UpdateGeoLocation" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sendGeolocationUpdateHandler:) name:@"SH_LMBridge_SendGeoLocationLogline" object:nil];
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

+ (void)startMonitorGeoLocationHandler:(NSNotification *)notification
{
    //Geofence does not need location latitude/longitude (log code 19, 20) actually, but server would like to have 19 and 20 to help generate geofence tree.
    if (NSClassFromString(@"SHLocationBridge") == nil) //Geofence only do this when Locations module is absent.
    {
        [StreetHawk.locationManager startMonitorGeoLocationStandard:NO]; //Geofence always uses significant location change to reduce cost.
    }
}

+ (void)stopMonitorGeoLocationHandler:(NSNotification *)notification
{
    if (NSClassFromString(@"SHLocationBridge") == nil) //Geofence only do this when Locations module is absent.
    {
        [StreetHawk.locationManager stopMonitorGeoLocation];
    }
}

+ (void)updateGeolocationCacheHandler:(NSNotification *)notification
{
    if (NSClassFromString(@"SHLocationBridge") == nil) //Geofence only do this when Locations module is absent.
    {
        [[NSUserDefaults standardUserDefaults] setObject:@(StreetHawk.locationManager.currentGeoLocation.latitude) forKey:SH_GEOLOCATION_LAT];
        [[NSUserDefaults standardUserDefaults] setObject:@(StreetHawk.locationManager.currentGeoLocation.longitude) forKey:SH_GEOLOCATION_LNG];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

+ (void)sendGeolocationUpdateHandler:(NSNotification *)notification
{
    if (NSClassFromString(@"SHLocationBridge") == nil) //Geofence only do this when Locations module is absent.
    {
        //Geofence lat/lng logline 19, 20 is sent every one hour.
        NSObject *sentTime = [[NSUserDefaults standardUserDefaults] objectForKey:SH_GEOFENCE_LATLNG_SENTTIME];
        if (sentTime != nil && [sentTime isKindOfClass:[NSNumber class]])
        {
            double sentTimestamp = [(NSNumber *)sentTime doubleValue];
            if ([[NSDate date] timeIntervalSince1970] - sentTimestamp < 60 * 60/*one hour*/)
            {
                return;
            }
        }
        NSString *comment = notification.userInfo[@"comment"];
        NSAssert(comment != nil, @"\"comment\" in sendGeolocationUpdateHandler should not be nil.");
        [StreetHawk sendLogForCode:LOG_CODE_LOCATION_MORE withComment:comment]; //send logline 19
        [StreetHawk sendLogForCode:LOG_CODE_LOCATION_GEO withComment:comment]; //send logline 20
        [[NSUserDefaults standardUserDefaults] setObject:@([[NSDate date] timeIntervalSince1970]) forKey:SH_GEOFENCE_LATLNG_SENTTIME];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

@end
