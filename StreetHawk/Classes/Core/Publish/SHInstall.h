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

#import "SHObject.h"

#define APNS_DISABLE_TIMESTAMP              @"APNS_DISABLE_TIMESTAMP"
#define APNS_SENT_DISABLE_TIMESTAMP         @"APNS_SENT_DISABLE_TIMESTAMP"

/**
 System Notification for confirmation install register successfully. If a device run and local has not install id, it will register a new one.
 The userInfo dictionary format is: {SHInstallNotification_kInstall, [newly registered install]}.
 
 The event is usually called as a result of the App's first run from registerInstallForApp, typical usage:
    `[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(installRegistrationSucceeded:) SHInstallRegistrationSuccessNotification object:nil];`
 */
extern NSString * const SHInstallRegistrationSuccessNotification;

/**
 System Notification for the device failed register install.
 The userInfo dictionary format is: {SHInstallNotification_kError, [the NSError object]}.
 */
extern NSString * const SHInstallRegistrationFailureNotification;

/**
 System Notification for the device update existing intall successfully.
 The userInfo dictionary format is: {SHInstallNotification_kInstall, [the updated install]}.
 */
extern NSString * const SHInstallUpdateSuccessNotification;

/**
 System Notification for the device failed update existing install.
 The userInfo dictionary format is: {SHInstallNotification_kInstall, [the updated install], SHInstallNotification_kError, [the NSError object]}.
 */
extern NSString * const SHInstallUpdateFailureNotification;

extern NSString * const SHInstallNotification_kInstall; //string @"Install", get SHInstall.
extern NSString * const SHInstallNotification_kError;  //string @"Error", get NSError.

/**
 An installed device in the StreetHawk system. 
 @discuss Apple has made announcements in 2012 that device IDs (UDIDs) are a not to be used for privacy reasons. However what all StreetHawk powered applications/clients need a way to identify installations. So the client side will be responsible for “requesting” a new device GUID when it first starts and then will store it over time. This ID is recorded here. Unfortunately every app deletion and re-install will request/create a new install ID.
 */
@interface SHInstall : SHObject

/** @name General properties */

/**
Customer developer register app_key in streethawk server. It's same as `StreetHawk.appKey`.
*/
@property (nonatomic, strong) NSString *appKey;

/**
 Your unique identifier for this Client. Tagged by API `[StreetHawk tagString:<unique_value> forKey:@"sh_cuid"];`
 */
@property (nonatomic, strong) NSString *sh_cuid;

/**
 The version of the client application.
 */
@property (nonatomic, strong) NSString *clientVersion;

/**
 identifier for segment.io. Tagged by API `[StreetHawk tagString:<unique_value> segmentId:[[SEGAnalytics sharedAnalytics] forKey:@"sh_cuid"];`
 */
@property (nonatomic, strong) NSString *segmentId;

/**
 The version of StreetHawkCore framework SDK.
 */
@property (nonatomic, strong) NSString *shVersion;

/**
 Operating system in lower case. Examples: “android”, “ios”, “windows”. Because this is iOS SDK, it's hard coded as "ios".
 */
@property (nonatomic, strong) NSString *operatingSystem;

/**
 The version of the operating system. Example: “7.0”.
 */
@property (nonatomic, strong) NSString *osVersion;

/**
 If this App is AppStore or Enterprise provisioning profile, it's true; otherwise it's false.
 */
@property (nonatomic) BOOL live;

/**
 Development platform, hardcoded in StreetHawk SDK.
 */
@property (nonatomic, strong) NSString *developmentPlatform;

/**
 The UTC time this install was created in year-month-day hour:minute:second format.
 */
@property (nonatomic, strong) NSDate *created;

/**
 The UTC time this install was modified in year-month-day hour:minute:second format.
 */
@property (nonatomic, strong) NSDate *modified;

/**
 If current App deleted and re-install again, install id changes. This property is the Install this Install has been replaced by.
 */
@property (nonatomic, strong) NSString *replaced;

/**
 An estimated timestamp (UTC) when the Install has been uninstalled, nil otherwise.
 */
@property (nonatomic, strong) NSDate *uninstalled;

/** @name Capability properties */

/**
 Customer developer uses location related SDK functions, technically when his pod include `streethawk/Locations` or `streethawk/Geofence` or `streethawk/Beacons` and set `StreetHawk.isLocationServiceEnabled = YES` this is true; otherwise this is false.
 */
@property (nonatomic) BOOL featureLocation;

/**
 Customer developer uses notification related SDK functions, technically when his pod include `streethawk/Push` and set `StreetHawk.isNotificationEnabled = YES` this is true; otherwise this is false.
 */
@property (nonatomic) BOOL featurePush;

/**
 Customer developer uses iBeacon related SDK functions, technically when his pod include `streethawk/Beacons` this is true; otherwise this is false.
 */
@property (nonatomic) BOOL featureiBeacons;

/**
 When `featureiBeacons == YES` and end user's device supports iBeacon (iOS version >= 7.0, location service enabled and bluetooth enabled), it's true.
 */
@property (nonatomic) BOOL supportiBeacons;

/** @name Notification properties */

/**
 If iOS App use development provisioning, it's `dev`; if use simulator, it's `simulator`; if use ad-hoc or AppStore or Enterprise distribution provisioning, it's `prod`.
 */
@property (nonatomic, strong) NSString *mode;

/**
 The access data for remote notification.
 */
@property (nonatomic, strong) NSString *pushNotificationToken;

/**
 It set to time stamp once get error from Apple's push notification server. If empty means Apple not reply error.
 */
@property (nonatomic, strong) NSString *negativeFeedback;

/**
 Timestamp when end user refuse to receive notification. If notification is approved it's empty.
 */
@property (nonatomic, strong) NSString *revoked;

/**
 Whether use "smart push".
 */
@property (nonatomic) BOOL smart;

/**
 Timestamp for feed. If not nil and local fetch time is older than this, SDK will fetch feed.
 */
@property (nonatomic, strong) NSString *feed;

/** @name Device properties */

/**
 Device's latitude. It's nil if not get latitude. StreetHawk server try to guess location by ip even when device disable location, thus it may not be nil even device disable location.
 */
@property (nonatomic, strong) NSNumber *latitude;

/**
 Device's longitude. It's nil if not get longitude. StreetHawk server try to guess location by ip even when device disable location, thus it may not be nil even device disable location.
 */
@property (nonatomic, strong) NSNumber *longitude;

/**
 UTC offset in minutes.
 */
@property (nonatomic) NSInteger utcOffset;

/**
 Descriptive text for the device model, e.g. `iPhone 6`. You should get this from either the android or iphone libraries so a consistent description is logged. i.e if the client is an android the model string must start with android.
 */
@property (nonatomic, strong) NSString *model;

/**
 Ip address of current device. It's known by server, not sent from client.
 */
@property (nonatomic, strong) NSString *ipAddress;

/**
 Mac address sent to server by client. It's not available since iOS 7 device, which always returns 02:00:00:00:00:00.
 */
@property (nonatomic, strong) NSString *macAddress;

/**
 Since iOS 7.0 mac address in unavailable, it always returns 02:00:00:00:00:00. Add identifierForVendor as another way to identifier vendor.
 */
@property (nonatomic, strong) NSString *identifierForVendor;

/**
 If customer developer pass in advertise identifier, submit to StreetHawk server. It requires App to approve IDFA when submitting to AppStore, thus StreetHawk SDK cannot positively read this property. Set up by `StreetHawk.advertisingIdentifier = ...`.
 */
@property (nonatomic, strong) NSString *advertisingIdentifier;

/**
 Carrier of current device. It's sent from client to server.
 */
@property (nonatomic, strong) NSString *carrierName;

/**
 Screen resolution of current device. It's sent from client to server.
 */
@property (nonatomic, strong) NSString *resolution;

@end
