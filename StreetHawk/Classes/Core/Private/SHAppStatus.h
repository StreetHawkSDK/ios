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

#import <Foundation/Foundation.h>
#import "SHHTTPSessionManager.h" //for enum SHHostVersion

/**
 Notification sent when server returns `app_status` different from local. Its user info is empty, read singletone `[SHAppStatus sharedInstance]` to get current situation.
 */
extern NSString * const SHAppStatusChangeNotification;

/**
 StreetHawk server can control each install's status by request return `app_status` section. This object is the central management of app status. It has property for server controls, and send notification if anything changes.
 */
@interface SHAppStatus : NSObject

/** @name Creator */

/**
 Singleton for get app status instance.
 */
+ (SHAppStatus *)sharedInstance;

/** @name Properties */

/**
 Match to `app_status` dictionary's `streethawk`. If set to NO, all visible functions of SDK are disabled, only leave minimum subset functions which for recover to enable.
 */
@property (nonatomic) BOOL streethawkEnabled;

/**
 Default host url. Set by `[StreetHawk setDefaultStartingUrl:]` if need to change. This url not contain version, for example "https://api.streethawk.com".
 */
@property (nonatomic, strong) NSString *defaultHost;

/**
 The current alive host url. It can be switched to other host at runtime by app_status. This function return the local cached alive host root url, if it's empty return default one `defaultHost`. It also contains version, for example @"https://api.streethawk.com/v1". Use `makeBaseUrlString([[SHAppStatus sharedInstance] aliveHostForVersion:SHHostVersion_V1], @"install/details/")` to create request path.
 */
- (NSString *)aliveHostForVersion:(SHHostVersion)hostVersion;

/**
 Set: if set nil or empty or same host url, nothing happen; otherwise the alive host root url is changed to new one. Set function should NOT contain version, just be @"https://api.streethawk.com".
 */
- (void)setAliveHost:(NSString *)aliveHost;

/**
 Match to `app_status` dictionary's `location_updates`. If set to NO install/log not upload location change, although location manager still works locally.
 */
@property (nonatomic) BOOL uploadLocationChange;

/**
 Match to `app_status` dictionary's `submit_views`. If set to YES local can submit friendly names. Server set it to YES when a new client version uploaded, once accept friendly name for this client version, server return NO. Note: for debugging convenience, friendly name always submit when debugMode=YES regardless of this flag.
 */
@property (nonatomic) BOOL allowSubmitFriendlyNames;

/**
 Match to `app_status` dictionary's `submit_interactive_button`. If set to YES local can submit interactive pair button. Server set it to YES when a new client version uploaded, once accept interactive pair button for this client version, server return NO. Note: for debugging convenience, interactive pair button always submit when debugMode=YES regardless of this flag.
 */
@property (nonatomic) BOOL allowSubmitInteractiveButton;

/**
 Match to `app_status` dictionary's `ibeacon`. It's a time stamp of server provided iBeacon list. If the time stamp is newer than client fetch time, client should fetch iBeacon list again and monitor new list; if the time stamp is NULL, client should clear cached iBeacon and stop monitor.
 */
@property (nonatomic, strong) NSString *iBeaconTimestamp;

/**
 Match to `app_status` dictionary's `geofences`. It's a time stamp of server provided geofence list. If the time stamp is newer than client fetch time, client should fetch geofence list again and monitor new list; if the time stamp is NULL or empty, client should clear cached geofence and stop monitor.
 */
@property (nonatomic, strong) NSString *geofenceTimestamp;

/**
 Match to `app_status` dictionary's `feed`. It's a time stamp of server last modify feeds. If the time stamp is newer than client fetch time, client should fetch feeds again and trigger customer's callback; if the time stamp is NULL or older than client fetch time, do nothing.
 */
@property (nonatomic, strong) NSString *feedTimestamp;

/**
 Match to `app_status` dictionary's `reregister`. In case it is given and set to true let the install register one more time.
 */
@property (nonatomic) BOOL reregister;

/**
 Match to `app_status` dictionary's `app_store_id`. It's for console to push itunes id to client side. The itunes id will be used for rate and upgrade App.
 */
@property (nonatomic, strong) NSString *appstoreId;

/**
 Match to `app_status` dictionary's `disable_logs`. It's for setting up disabled logline code. It would be nil means clear, or array of code list.
 */
@property (nonatomic, strong) NSObject *logDisableCodes;

/**
 Match to `app_status` dictionary's `priority`. It's for setting up priority logline code. It would be nil means clear, or array of code list.
 */
@property (nonatomic, strong) NSObject *logPriorityCodes;

/** @name Functions */

/**
 App status could change for some reason, so the App needs to check current one in some situation, (start to run, from background to foreground, handle push message 8003), these are handled by StreetHawk automatically. This call is a utility function to do the check. Although all request may contain "app_status", this send "/apps/status" request.
 @param force If NO do not check for a. `streethawkEnabled`=YES as request send often; b. previous check in a day. If YES do check whatever.
 */
- (void)sendAppStatusCheckRequest:(BOOL)force;

/**
 Save this check time to avoid frequent check. No matter any property changed or not, record the time.
 */
- (void)recordCheckTime;

@end
