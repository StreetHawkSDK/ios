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
#import <CoreLocation/CoreLocation.h>

/**
 The state of current geolocation update.
 */
enum SHGeoLocationMonitorState
{
    /**
     Not monitor geolocation.
     */
    SHGeoLocationMonitorState_Stopped,
    /**
     Monitor geolocation in standard way, called by `startUpdatingLocation`.
     */
    SHGeoLocationMonitorState_MonitorStandard,
    /**
     Monitor geolocation in significant change way, called by `startMonitoringSignificantLocationChanges`.
     */
    SHGeoLocationMonitorState_MonitorSignificant,
};
typedef enum SHGeoLocationMonitorState SHGeoLocationMonitorState;

/**
 The status of current device's iBeacon support.
 */
enum SHiBeaconState
{
    /**
     Bluetooth state not determined yet, unknown at this moment.
     */
    SHiBeaconState_Unknown,
    /**
     Current device is ready to use iBeacon, means it's iOS 7.0+, location service enabled, Bluetooth on.
     */
    SHiBeaconState_Support,
    /**
     Current device not ready to use iBeacon, one condition not match.
     */
    SHiBeaconState_NotSupport,
};
typedef enum SHiBeaconState SHiBeaconState;

/**
A core class to monitor location change. By default process of StreetHawk SDK, it works in the following way:

- When the App is in foreground, it uses startUpdatingLocation to monitor location position and change. The SHLocationManagerUpdateLocation notification is sent after fgMinTimeBetweenEvents (default: 1 minute) and fgMinDistanceBetweenEvents (default: 100 meters).
- When App is in background, it uses startMonitoringSignificantLocationChanges to monitor location change. The SHLocationManagerUpdateLocation notification sent after bgMinTimeBetweenEvents (default: 5 minute) and bgMinDistanceBetweenEvents (default: 500 meters).
- These defaults can be overriden for your specific application.
- The SHLocationManager automatically manages/monitors the foreground/background state, so there is no requirement from the App developer. It should be noted that if the screen is turned off while the App is in the foreground, this is treated as a transition to background.
- Even if the App crashes or is terminated, or phone power off/on, the App will be woken up and put in background because significant location monitoring.
- Once location update notification occur, (according to the algorithm above) logs are post to server immediately, and install updated.
 
 **Default Values by Application state**
 <table>
    <tr>
        <th>Parameter</th>
        <th>Background</th>
        <th>Foreground</th>
    </tr>
    <tr>
        <td>(bg/fg)MinDistanceBetweenEvents</td>
        <td>500m</td>
        <td>100m</td>
    </tr>
    <tr>
        <td>(bg/fg)MinTimeBetweenEvents</td>
        <td>5mins</td>
        <td>1min</td>
    </tr>
 </table>
 
 **Related project settings:**
    In "Required background modes" there is a choice for location service (Location updates). Note: this is ONLY for keeping standard location service to run at background; it has NO effect for significant location service. With or without this setting checked, significant location service keeps running at background, or even App is terminated or Phone power off/on. Because StreetHawk SDK uses standard location update in foreground, uses significant location update in background, there is NO need to check this setting.
 
 **Debug Tips:**
 * Xcode can simulate location, but it only works for standard location service, not works for significant location service (both simulator and device). To test significant location update, the only way is to travel with device.
 * Even without background mode checked, standard location service not stop immediately when click home button to put App go to background. When the App is in background, you can still see location update delegate triggered. But once you lock screen, the standard location service stop.
 * If kill App in Xcode, significant location cannot wake up automatically. Need to turn App on, even manually kill it in device.
 
 Normally caller does not need to start/stop location service, or set the properties. Caller just need to visit the location properties. But the control API also provided.
 */
@interface SHLocationManager : NSObject<CLLocationManagerDelegate>

/** @name Creator */

/**
 Singleton instance. Caller normally only needs to use [SHLocationManager sharedInstance], or StreetHawk.locationManager (they are same) to visit the location properties. 
 */
+ (SHLocationManager *)sharedInstance;

/** @name Check location service is enabled for this App. This includes System Preference Settings, while location service is enabled, this App's permission is allowed or not determined. This also include code level control `StreetHawk.isLocationServiceEnabled`.
 @param allowNotDetermined If user not determine shall continue as enabled. Sometimes need to treat not determined as allowed, otherwise first location permission won't promote.
 */
+ (BOOL)locationServiceEnabledForApp:(BOOL)allowNotDetermined;

/** @name Geo Location Detection Result */

@property (nonatomic, readonly) SHGeoLocationMonitorState geolocationMonitorState;

/**
 Device's geo location. It returns (lat, lng) after location service detect geo location after launch; if location service is disabled, or not detech since launch, it returns (0, 0).
 */
@property (nonatomic, readonly) CLLocationCoordinate2D currentGeoLocation;

/** @name Set Geo Location Service Properties */

/**
 Properties for setting up CLLocationManager.
 */
@property (nonatomic) CLLocationAccuracy desiredAccuracy;

/**
 Properties for setting up CLLocationManager.
 */
@property (nonatomic) CLLocationDistance distanceFilter;

/**
 Foreground minimum time between events, if last event till now less than this, location update notification will not happen. default = 60 (seconds)
 */
@property (nonatomic) NSTimeInterval fgMinTimeBetweenEvents;

/**
 Background minimum time between events, if last event till now less than this, location update notification will not happen. default = 300 (seconds)
 */
@property (nonatomic) NSTimeInterval bgMinTimeBetweenEvents;

/**
 Foreground minimum distance between events, if last event to current location less than this, location update notification will not happen. default = 100.0 (metres)
 */
@property (nonatomic) float fgMinDistanceBetweenEvents;

/**
 Background minimum distance between events, if last event to current location less than this, location update notification will not happen. default = 500.0 (metres)
 */
@property (nonatomic) float bgMinDistanceBetweenEvents;

/**
 iBeacon is supported by iOS 7.0 and above, device need have BLE 4.0 and turn Bluetooth on, location service must by enabled. This property determines whether current device support iBeacons.
 */
@property (nonatomic, readonly) SHiBeaconState iBeaconSupportState;

/**
 Get current status of bluetooth. Return is an enum refer to `CBCentralManagerState`.
 */
@property (nonatomic, readonly) NSInteger bluetoothState;

/**
 Current monitoring regions, either geo-location region or iBeacon region. This returns system internal `CLLocationManager.monitoredRegions`. When App re-launch previously monitored region recover, so only system knows what are the real monitored regions. Add it by `- (BOOL)startMonitorRegion:(CLRegion *)region` and removed by `- (void)stopmonitorRegion:(CLRegion *)region`.
 */
@property (weak, nonatomic, readonly) NSArray *monitoredRegions;

/** @name Operation */

/**
 Since iOS 8 needs obviously asking for permission for a type.
 */
- (void)requestPermissionSinceiOS8 NS_AVAILABLE_IOS(8_0);

/**
 Start detecting the location change. Normally you don't need to call this because the SHApp will call this and related functions based on application state (foreground uses standard location service, background uses significant location service). However you may wish to control this, for example in foreground you may wish to switch to significant location service, so call `startDetectingLocationStandard:NO inForeground:YES`. After detecting successfully, observe `SHLMUpdateLocationSuccessNotification` to get the result.
 @param standard - use standard GPS style location tracking otherwise significant.
 @return YES if started OK. NO if failed - this is usually due to a user disabling location services. Your application should check and prompt the user to change this option.
 */
- (BOOL)startMonitorGeoLocationStandard:(BOOL)standard;

/**
 Stop geo location detection if it is in progress. It stops standard location service or significant location service. If the location service is not started yet, call this do nothing without error.
 */
- (void)stopMonitorGeoLocation;

/**
 Start monitor a region, either geo-location region or iBeacon region. 
 
 **Important notice:**
 
 1. If there is already a region with same type and same `identifier`, monitor a region will cause previous one removed!!! For example, following code:
    `CLRegion *r1 = [[CLRegion alloc] initWith... identifier:@"123"];`
    `[StreetHawk.locationManager startMonitoriBeacon:r1];`
    `CLRegion *r2 = [[CLRegion alloc] initWith... identifier:@"123"];`
    `[StreetHawk.locationManager startMonitoriBeacon:r2];`
    Result is: ONLY r2 region is monitored!!! r1 is not monitored because they share same `identifier` (not `proximity uuid`). Must change r2's identifier to another one, for example @"12345", then both r1 and r2 are monitored. To assist user find this StreetHawk prints console warning log to let user know. System CLLocationManager has no feedback for this.
 
 2. Match to a region does not consider `identifier`, only `proximity UUID`, `major` and `minor` considered. For example, iBeacon UUID="abc", major=1, minor=2 matches region UUID="abc", identifier = "123", and it matches region UUID="abc", identifier = "456".
 
 3. `region` property decides the callback delegate:
   - region.notifyOnEntry decide whether `- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region` is called when enter this region. Default is YES.
   - region.notifyOnExit decide whether `- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region` is called when exit the region. Default is YES.
   - if it's CLBeaconRegion, region.notifyEntryStateOnDisplay decide how `- (void)locationManager:(CLLocationManager *)manager didDetermineState:(CLRegionState)state forRegion:(CLRegion *)region` is called. Default is NO. If YES it's called when region enter or exit (same as didEnterRegion and didExitRegion), and also when screen turn on (not App go FG), all "inside" region is called; if NO it's called only when enter or exit a region.
 
 4. If an App start monitor region and no code to stop, kill the App, launch it again, it continue monitoring and trigger delegate, no need to start monitoring again. In iOS 7 the App need to manually launch; since iOS 7.1 the App automatically launch.
 
 5. When call `startMonitorRegion`, only `didDetermineState` calls, no `didEnterRegion` or `didExitRegion` called!!! Later when enter/exit region, they all called. Enter and exit must cross boundary, while state not need.
 
 6. Must have "Background App Refresh" enabled, otherwise none of `didDetermineState` nor `didEnterRegion` nor `didExitRegion` delegate get called. It starts monitor and then slient.
 
 @param region The region to be monitor.
 @return If this region starts to monitor, return YES; otherwise return NO for example SDK not enabled, system location service disabled, not support monitor this region etc.
 */
- (BOOL)startMonitorRegion:(CLRegion *)region;

/**
 Stop monitor region. When stop monitor a region, none of `didDetermineState` or `didEnterRegion` or `didExitRegion` called. Just stop silently.
 */
- (void)stopMonitorRegion:(CLRegion *)region;

#ifdef SH_FEATURE_IBEACON

/**
 Start to range one iBeacon region.
 
 **Important notice:**
 
 1. When a region is ranging and App killed, after App re-launch, it does NOT automatically recover ranging again. Normally put range iBeacon region in enter/exit region or state change, so that re-launch App can continue to range iBeacon.
 
 @return YES if the beacon region is not monitoring yet. NO cannot range iBeacon, for example device not support, location service disabled etc.
 */
- (BOOL)startRangeiBeaconRegion:(CLBeaconRegion *)iBeaconRegion __OSX_AVAILABLE_STARTING(__MAC_NA,__IPHONE_7_0);

/**
 Stop monitoring one iBeacon region. Nothing happen even the iBeacon is not monitoring now. 
 */
- (void)stopRangeiBeaconRegion:(CLBeaconRegion *)iBeaconRegion __OSX_AVAILABLE_STARTING(__MAC_NA,__IPHONE_7_0);

#endif

@end
