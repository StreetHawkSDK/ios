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

#import "SHApp+Location.h"
//header from StreetHawk
#import "SHLocationManager.h"
//header from System
#import <objc/runtime.h> //for associate object

NSString * const SHLMStartStandardMonitorNotification = @"SHLMStartStandardMonitorNotification";
NSString * const SHLMStopStandardMonitorNotification = @"SHLMStopStandardMonitorNotification";
NSString * const SHLMStartSignificantMonitorNotification = @"SHLMStartSignificantMonitorNotification";
NSString * const SHLMStopSignificantMonitorNotification = @"SHLMStopSignificantMonitorNotification";
NSString * const SHLMStartMonitorRegionNotification = @"SHLMStartMonitorRegionNotification";
NSString * const SHLMStopMonitorRegionNotification = @"SHLMStopMonitorRegionNotification";
NSString * const SHLMStartRangeiBeaconRegionNotification = @"SHLMStartRangeiBeaconRegionNotification";
NSString * const SHLMStopRangeiBeaconRegionNotification = @"SHLMStopRangeiBeaconRegionNotification";

NSString * const SHLMUpdateLocationSuccessNotification = @"SHLMUpdateLocationSuccessNotification";
NSString * const SHLMUpdateFailNotification = @"SHLMUpdateFailNotification";
NSString * const SHLMEnterRegionNotification = @"SHLMEnterRegionNotification";
NSString * const SHLMExitRegionNotification = @"SHLMExitRegionNotification";
NSString * const SHLMRegionStateChangeNotification = @"SHLMRegionStateChangeNotification";
NSString * const SHLMMonitorRegionSuccessNotification = @"SHLMMonitorRegionSuccessNotification";
NSString * const SHLMMonitorRegionFailNotification = @"SHLMMonitorRegionFailNotification";
NSString * const SHLMRangeiBeaconChangedNotification = @"SHLMRangeiBeaconChangedNotification";
NSString * const SHLMRangeiBeaconFailNotification = @"SHLMRangeiBeaconFailNotification";
NSString * const SHLMChangeAuthorizationStatusNotification = @"SHLMChangeAuthorizationStatusNotification";

NSString * const SHLMEnterExitGeofenceNotification = @"SHLMEnterExitGeofenceNotification";
NSString * const SHLMEnterExitBeaconNotification = @"SHLMEnterExitBeaconNotification";

NSString * const SHLMNotification_kNewLocation = @"NewLocation";
NSString * const SHLMNotification_kOldLocation = @"OldLocation";
NSString * const SHLMNotification_kError = @"Error";
NSString * const SHLMNotification_kRegion = @"Region";
NSString * const SHLMNotification_kRegionState = @"RegionState";
NSString * const SHLMNotification_kBeacons = @"Beacons";
NSString * const SHLMNotification_kAuthStatus = @"AuthStatus";

int const SHLocation_FG_Interval = 1;
int const SHLocation_FG_Distance = 100;
int const SHLocation_BG_Interval = 5;
int const SHLocation_BG_Distance = 500;

#define ENABLE_LOCATION_SERVICE             @"ENABLE_LOCATION_SERVICE"  //key for record user manually set isLocationServiceEnabled

@implementation SHApp (LocationExt)

#pragma mark - properties

@dynamic isDefaultLocationServiceEnabled;
@dynamic isLocationServiceEnabled;
@dynamic locationManager;
@dynamic systemPreferenceDisableLocation;

- (BOOL)isDefaultLocationServiceEnabled
{
    NSNumber *value = objc_getAssociatedObject(self, @selector(isDefaultLocationServiceEnabled));
    return [value boolValue];
}

- (void)setIsDefaultLocationServiceEnabled:(BOOL)isDefaultLocationServiceEnabled
{
    objc_setAssociatedObject(self, @selector(isDefaultLocationServiceEnabled), [NSNumber numberWithBool:isDefaultLocationServiceEnabled], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)isLocationServiceEnabled
{
    //if never manually set isLocationServiceEnabled, use default value
    NSObject *setObj = [[NSUserDefaults standardUserDefaults] objectForKey:ENABLE_LOCATION_SERVICE];
    if (setObj == nil || ![setObj isKindOfClass:[NSNumber class]])
    {
        return self.isDefaultLocationServiceEnabled;
    }
    //otherwise use manually set value
    return [(NSNumber *)setObj boolValue];
}

- (void)setIsLocationServiceEnabled:(BOOL)isLocationServiceEnabled
{
    if (self.isLocationServiceEnabled != isLocationServiceEnabled)
    {
        if (isLocationServiceEnabled) //This assumes to start location, not consider `StreetHawk.reportWorkHomeLocationOnly`, even it enables standard location service, next FG/BG will correct it.
        {
            //if enable update first, as next part will consider it.
            [[NSUserDefaults standardUserDefaults] setBool:isLocationServiceEnabled forKey:ENABLE_LOCATION_SERVICE];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [StreetHawk.locationManager requestPermissionSinceiOS8];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_LMBridge_StartMonitorGeoLocation" object:nil];
        }
        else
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_LMBridge_StopMonitorGeoLocation" object:nil];
            //if disable update after take effect, otherwise above function will ignore it.
            [[NSUserDefaults standardUserDefaults] setBool:isLocationServiceEnabled forKey:ENABLE_LOCATION_SERVICE];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        [StreetHawk registerOrUpdateInstallWithHandler:nil]; //update "feature_locations"
    }
}

- (BOOL)reportWorkHomeLocationOnly
{
    NSNumber *value = objc_getAssociatedObject(self, @selector(reportWorkHomeLocationOnly));
    return [value boolValue];
}

- (void)setReportWorkHomeLocationOnly:(BOOL)reportWorkHomeLocationOnly
{
    objc_setAssociatedObject(self, @selector(reportWorkHomeLocationOnly), [NSNumber numberWithBool:reportWorkHomeLocationOnly], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_LMBridge_StartMonitorGeoLocation" object:nil];
}

- (SHLocationManager *)locationManager
{
    return objc_getAssociatedObject(self, @selector(locationManager));
}

- (void)setLocationManager:(SHLocationManager *)locationManager
{
    objc_setAssociatedObject(self, @selector(locationManager), locationManager, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)systemPreferenceDisableLocation
{
    BOOL globalDisable = ![CLLocationManager locationServicesEnabled];
    BOOL appDisable = [CLLocationManager authorizationStatus] == kCLAuthorizationStatusDenied;
    return (globalDisable || appDisable);
}

- (void)setLocationUpdateFrequencyForFGInterval:(int)fgInterval forFGDistance:(int)fgDistance forBGInterval:(int)bgInterval forBGDistance:(int)bgDistance
{
    StreetHawk.locationManager.fgMinTimeBetweenEvents = fgInterval;
    StreetHawk.locationManager.fgMinDistanceBetweenEvents = fgDistance;
    StreetHawk.locationManager.bgMinTimeBetweenEvents = bgInterval;
    StreetHawk.locationManager.bgMinDistanceBetweenEvents = bgDistance;
}

@end
