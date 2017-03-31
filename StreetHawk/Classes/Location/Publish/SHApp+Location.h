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

#import "SHApp.h" //for extension SHApp

/**
 Notification sent when start standard geolocation monitor, called by `startMonitorGeoLocationStandard:YES`. UserInfo is nil. Use `geolocationMonitorState` to know current geo location state.
 */
extern NSString * const SHLMStartStandardMonitorNotification;

/**
 Notification sent when stop standard geolocation monitor, called by `stopMonitorGeoLocation`. UserInfo is nil. Use `geolocationMonitorState` to know current geo location state.
 */
extern NSString * const SHLMStopStandardMonitorNotification;

/**
 Notification sent when start significant geolocation monitor, called by `startMonitorGeoLocationStandard:NO`. UserInfo is nil. Use `geolocationMonitorState` to know current geo location state.
 */
extern NSString * const SHLMStartSignificantMonitorNotification;

/**
 Notification sent when stop significant geolocation monitor, called by `stopMonitorGeoLocation`. UserInfo is nil. Use `geolocationMonitorState` to know current geo location state.
 */
extern NSString * const SHLMStopSignificantMonitorNotification;

/**
 Notification sent when start monitor a region, called by `startMonitorRegion:`. The user information contains `SHLMNotification_kRegion` for start region.
 */
extern NSString * const SHLMStartMonitorRegionNotification;

/**
 Notification sent when stop monitor a regioin, called by `stopMonitorRegion:`. The user information contains `SHLMNotification_kRegion` for stopped region.
 */
extern NSString * const SHLMStopMonitorRegionNotification;

/**
 Notification sent when start range an iBeacon region. The user information contains `SHLMNotification_kRegion` for start region.
 */
extern NSString * const SHLMStartRangeiBeaconRegionNotification;

/**
 Notification sent when stop monitoring an iBeacon region. The user information contains `SHLMNotification_kRegion` for stopped region.
 */
extern NSString * const SHLMStopRangeiBeaconRegionNotification;

/**
 Notification sent when successfully update to a new location, equal `- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation` before iOS 6 or `- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations` since iOS 6. The user information contains `StreetHawkLocationNotification_kNewLocation` and `StreetHawkLocationNotification_kOldLocation` representing CLLocatioin.
 */
extern NSString * const SHLMUpdateLocationSuccessNotification;

/**
 Notification sent when fail to update location, equal `- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error`. The user information contains `StreetHawkLocationNotification_kError` representing NSError.
 */
extern NSString * const SHLMUpdateFailNotification;

/**
 Notification sent when enter one region, equal `- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region`. It's called both for geo region or iBeacon region. Use `SHLMBeaconFoundNotification` for iBeacon. The user information contains `SHLMNotification_kRegion` representing CLRegion.
 */
extern NSString * const SHLMEnterRegionNotification;

/**
 Notification sent when exit one region, equal `- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region`. It's called both for geo region or iBeacon region. The user information contains `SHLMNotification_kRegion` representing CLRegion.
 */
extern NSString * const SHLMExitRegionNotification;

/**
 Notification sent when region state change, equal `- (void)locationManager:(CLLocationManager *)manager didDetermineState:(CLRegionState)state forRegion:(CLRegion *)region`. The user information contains `SHLMNotification_kRegion` representing CLRegion and `SHLMNotification_kRegionState` representing region state enum.
 */
extern NSString * const SHLMRegionStateChangeNotification;

/**
 Notification sent when successfully start to monitor one region, equal `- (void)locationManager:(CLLocationManager *)manager didStartMonitoringForRegion:(CLRegion *)region`. It's called both for geo region or iBeacon region. The user information contains `SHLMNotification_kRegion` representing CLRegion.
 */
extern NSString * const SHLMMonitorRegionSuccessNotification;

/**
 Notification sent when fail to monitor one region, equal `- (void)locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region withError:(NSError *)error`. It's called both for geo region or iBeacon region. The user information contains `SHLMNotification_kRegion` representing CLRegion and `SHLMNotification_kError` representing NSError.
 */
extern NSString * const SHLMMonitorRegionFailNotification;

/**
 Notification sent when beacons changes, equal `- (void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray *)beacons inRegion:(CLBeaconRegion *)region`. The user information contains `SHLMNotification_kRegion` representing CLRegion and `SHLMNotification_kBeacons` representing NSArray of CLBeacon. If beacons array is empty, it means no beacons nearby can reach the device. Note: this notification happen frequently when App in foreground, almost update once a second, and it runs forever; when App goes to background it runs for a while and stop when device locked, but it can trigger if start range iBeacon region when enter region. Because it runs so frequently, a normal usage is:
 
 - when enter region, start range iBeacon region.
 - when exit region, stop range iBeacon region.
 - beacause enter/exit region wake up App in background, above range code triggered in background.
 */
extern NSString * const SHLMRangeiBeaconChangedNotification;

/**
 Notification sent when fail to monitor one iBeacon region, equal `- (void)locationManager:(CLLocationManager *)manager rangingBeaconsDidFailForRegion:(CLBeaconRegion *)region withError:(NSError *)error`. The user information contains `SHLMNotification_kRegion` representing CLRegion and `SHLMNotification_kError` representing NSError.
 */
extern NSString * const SHLMRangeiBeaconFailNotification;

/**
 Notification sent when authorization status change, equal `- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status`. The user information contains `SHLMNotification_kAuthStatus` representing CLAuthorizationStatus.
 */
extern NSString * const SHLMChangeAuthorizationStatusNotification;

/**
 Notification sent when enter or exit a server monitoring geofence. The geofences are configured in web console. The user information contains NSDictionary representing one server monitor geofence.
 */
extern NSString * const SHLMEnterExitGeofenceNotification;

/**
 Notification sent when enter or exit a server monitoring beacon. The beacons are configured in web console. The user information contains NSDictionary representing one server monitor beacon.
 */
extern NSString * const SHLMEnterExitBeaconNotification;

/**
 Keys for StreetHawkLocation notifications.
 */
extern NSString * const SHLMNotification_kNewLocation; //string @"NewLocation", get CLLocation.
extern NSString * const SHLMNotification_kOldLocation; //string @"OldLocation", get CLLocation.
extern NSString * const SHLMNotification_kError; //string @"Error", get NSError.
extern NSString * const SHLMNotification_kRegion; //string @"Region", get CLRegion.
extern NSString * const SHLMNotification_kRegionState; //string @"RegionState", get CLRegionState enum.
extern NSString * const SHLMNotification_kBeacons; //string @"Beacons", get NSArray for CLBeacon.
extern NSString * const SHLMNotification_kAuthStatus;  //string @"AuthStatus", get NSNumber for int representing CLAuthorizationStatus.

extern int const SHLocation_FG_Interval; //Default minimum time interval for updating location when App in FG, 1 mins.
extern int const SHLocation_FG_Distance; //Default minimum distance for updating location when App in FG, 100 meters.
extern int const SHLocation_BG_Interval; //Default minimum time interval for updating location when App in BG, 5 mins.
extern int const SHLocation_BG_Distance; //Default minimum distance for updating location when App in BG, 500 meters.

@class SHLocationManager;

/**
 Extension for Crash API.
 */
@interface SHApp (LocationExt)

/**
 Default value to initialise `isLocationServiceEnabled`, it's called once when App first launch to set to `isLocationServiceEnabled`. A typical usage is to delay asking for location allow permission (*** would like to use your current location (Don't allow/OK)):
 
 `StreetHawk.isDefaultLocationServiceEnabled = NO; //not trigger location service when App launch.`
 `[registerInstallForApp... ];   //do register without trigger location service`
 `StreetHawk.isLocationServiceEnabled = YES; //later trigger location service when need it.`
 */
@property (nonatomic) BOOL isDefaultLocationServiceEnabled;

/**
 Property to control using location service or not. Geo-location update, iBeacon, region update needs this to be enabled to work. Internal CLLocation is not released when disable location service, but all functions not trigger StreetHawk's notification.
 */
@property (nonatomic) BOOL isLocationServiceEnabled;

/**
 A flag to only sends logline 19, stop logline 20. Keep consistent with Android to save battery. Default is `NO` to report 20 logline normally, FG uses standard and BG uses significant. If set to `YES` to save battery and meantime can detect location for logline 19, always uses significant location, not use standard location even in FG.
 */
@property (nonatomic) BOOL reportWorkHomeLocationOnly;

/**
 An instance to deal with location.
 */
@property (nonatomic, strong) SHLocationManager *locationManager;

/**
 Does user disable location permission for this App in system preference settings App. It's used to check before promote settings dialog by calling `- (void)launchSystemPreferenceSettings` to let user reset location since iOS 8, or before iOS 8 needs to show self made instruction. It's only return YES when make sure global location is disabled or App location is disabled. If this App not has location required (for example not have location key in Info.plist), or not ask for location service by prevent enable it, return NO.
 */
@property (nonatomic, readonly) BOOL systemPreferenceDisableLocation;

/**
 StreetHawk SDK sends logline to server to report current location. The frequency can be controlled by this API. By default the frequency is following.
 
 <table>
 <tr>
 <th>Parameter</th>
 <th>Background</th>
 <th>Foreground</th>
 </tr>
 <tr>
 <td>(bg/fg)MinDistanceBetweenEvents</td>
 <td>500m `SHLocation_BG_Distance`</td>
 <td>100m `SHLocation_FG_Distance`</td>
 </tr>
 <tr>
 <td>(bg/fg)MinTimeBetweenEvents</td>
 <td>5mins `SHLocation_BG_Interval`</td>
 <td>1min `SHLocation_FG_Interval`</td>
 </tr>
 </table>
 
 @param fgInterval Minimum time interval for sending location logline when App in FG, measured in minutes.
 @param fgDistance Minimum distance for sending location logline when App in FG, measured in meters.
 @param bgInterval Minimum time interval for sending location logline when App in BG, measured in minutes.
 @param bgDistance Minimum distance for sending location logline when App in BG, measured in meters.
 */
- (void)setLocationUpdateFrequencyForFGInterval:(int)fgInterval forFGDistance:(int)fgDistance forBGInterval:(int)bgInterval forBGDistance:(int)bgDistance;

@end

