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

#import "SHLocationBridge.h"
//header from StreetHawk
#import "SHApp+Location.h"
#import "SHLocationManager.h"
#import "SHLogger.h" //for sendLogForCode
#import "SHUtils.h" //for shSerializeObjToJson

@interface SHLocationBridge ()

+ (void)createLocationManagerHandler:(NSNotification *)notification;
+ (void)startMonitorGeoLocationHandler:(NSNotification *)notification; //for start location monitor for lat/lng. notification name: SH_LMBridge_StartMonitorGeoLocation; user info: empty.
+ (void)stopMonitorGeoLocationHandler:(NSNotification *)notification; //for stop location monitor for lat/lng. notification name: SH_LMBridge_StopMonitorGeoLocation; user info: empty.
+ (void)regularTaskHandler:(NSNotification *)notification; //for sending regular logline for heart beat and more location. notification name: SH_LMBridge_RegularTask; user info: {@"needHeartbeatLog": <bool>, @"needComplete": <bool>, @"completionHandler": <completionHandler>}.
+ (void)updateGeolocationCacheHandler:(NSNotification *)notification; //for updating local NSUserDefaults to pass values between modules, use notification to update when necessary, not refresh local cache too often. notification name: SH_LMBridge_UpdateGeoLocation; user info: empty.
+ (void)sendGeolocationUpdateHandler:(NSNotification *)notification; //for sending logline 20. notification name: SH_LMBridge_SendGeoLocationLogline; user info: @{comment: <json_comment>}.

@end

@implementation SHLocationBridge

+ (void)bridgeHandler:(NSNotification *)notification
{
    //initialise variables, move from SHApp's init.
    StreetHawk.isDefaultLocationServiceEnabled = YES;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(createLocationManagerHandler:) name:@"SH_LMBridge_CreateLocationManager" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startMonitorGeoLocationHandler:) name:@"SH_LMBridge_StartMonitorGeoLocation" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopMonitorGeoLocationHandler:) name:@"SH_LMBridge_StopMonitorGeoLocation" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(regularTaskHandler:) name:@"SH_LMBridge_RegularTask" object:nil];
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

+ (void)startMonitorGeoLocationHandler:(NSNotification *)notification
{
    [StreetHawk.locationManager startMonitorGeoLocationStandard:(!StreetHawk.reportWorkHomeLocationOnly && [UIApplication sharedApplication].applicationState == UIApplicationStateActive)];
}

+ (void)stopMonitorGeoLocationHandler:(NSNotification *)notification
{
    [StreetHawk.locationManager stopMonitorGeoLocation];
}

typedef void (^RegularTaskCompletionHandler)(UIBackgroundFetchResult);

+ (void)regularTaskHandler:(NSNotification *)notification
{
    BOOL needHeartbeatLog = [notification.userInfo[@"needHeartbeatLog"] boolValue];
    BOOL needComplete = [notification.userInfo[@"needComplete"] boolValue];
    RegularTaskCompletionHandler completionHandler = notification.userInfo[@"completionHandler"];
    BOOL needLocationLog = ([SHLocationManager locationServiceEnabledForApp:NO/*must allowed location already*/] && StreetHawk.locationManager.currentGeoLocation.latitude != 0 && StreetHawk.locationManager.currentGeoLocation.longitude != 0); //log current geo location if location service is enabled and already detect location.
    if (needLocationLog)
    {
        NSObject *lastPostLocationLogsVal = [[NSUserDefaults standardUserDefaults] objectForKey:REGULAR_LOCATION_LOGTIME];
        if (lastPostLocationLogsVal != nil && [lastPostLocationLogsVal isKindOfClass:[NSNumber class]])
        {
            NSTimeInterval lastPostLocationLogs = [(NSNumber *)lastPostLocationLogsVal doubleValue];
            if ([[NSDate date] timeIntervalSinceReferenceDate] - lastPostLocationLogs < 60*60) //more location time interval is 1 hour
            {
                needLocationLog = NO;
            }
        }
    }
    if (!needHeartbeatLog && !needLocationLog) //nothing to do
    {
        if (needComplete && completionHandler != nil)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(UIBackgroundFetchResultNewData);
            });
        }
    }
    else if (needHeartbeatLog && needLocationLog)  //send both
    {
        NSDictionary *dictLoc = @{@"lat": @(StreetHawk.locationManager.currentGeoLocation.latitude), @"lng": @(StreetHawk.locationManager.currentGeoLocation.longitude)};
        [StreetHawk sendLogForCode:LOG_CODE_LOCATION_MORE withComment:shSerializeObjToJson(dictLoc)];
        [StreetHawk sendLogForCode:LOG_CODE_HEARTBEAT withComment:@"Heart beat." forAssocId:nil withResult:100/*ignore*/ withHandler:^(NSObject *result, NSError *error)
         {
             if (needComplete && completionHandler != nil)
             {
                 dispatch_async(dispatch_get_main_queue(), ^{
                     completionHandler(UIBackgroundFetchResultNewData);
                 });
             }
         }];
    }
    else if (needHeartbeatLog)  //only send heart beat
    {
        [StreetHawk sendLogForCode:LOG_CODE_HEARTBEAT withComment:@"Heart beat." forAssocId:nil withResult:100/*ignore*/ withHandler:^(NSObject *result, NSError *error)
         {
             if (needComplete && completionHandler != nil)
             {
                 dispatch_async(dispatch_get_main_queue(), ^{
                     completionHandler(UIBackgroundFetchResultNewData);
                 });
             }
         }];
    }
    else  //only send more location
    {
        NSDictionary *dictLoc = @{@"lat": @(StreetHawk.locationManager.currentGeoLocation.latitude), @"lng": @(StreetHawk.locationManager.currentGeoLocation.longitude)};
        [StreetHawk sendLogForCode:LOG_CODE_LOCATION_MORE withComment:shSerializeObjToJson(dictLoc) forAssocId:nil withResult:100/*ignore*/ withHandler:^(NSObject *result, NSError *error)
         {
             if (needComplete && completionHandler != nil)
             {
                 dispatch_async(dispatch_get_main_queue(), ^{
                     completionHandler(UIBackgroundFetchResultNewData);
                 });
             }
         }];
    }
}

+ (void)updateGeolocationCacheHandler:(NSNotification *)notification
{
    [[NSUserDefaults standardUserDefaults] setObject:@(StreetHawk.locationManager.currentGeoLocation.latitude) forKey:SH_GEOLOCATION_LAT];
    [[NSUserDefaults standardUserDefaults] setObject:@(StreetHawk.locationManager.currentGeoLocation.longitude) forKey:SH_GEOLOCATION_LNG];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (void)sendGeolocationUpdateHandler:(NSNotification *)notification
{
    NSString *comment = notification.userInfo[@"comment"];
    NSAssert(comment != nil, @"\"comment\" in sendGeolocationUpdateHandler should not be nil.");
    [StreetHawk sendLogForCode:LOG_CODE_LOCATION_GEO withComment:comment];
}

@end
