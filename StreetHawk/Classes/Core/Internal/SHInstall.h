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
#import "SHApp.h" //for extension SHApp

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
extern NSString * const SHRegistrationFailureNotification;

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

/**
 The client application ID that this log message is associated with. It's same as StreetHawk.hostAppId, which should match server's database.
 */
@property (nonatomic, strong) NSString *appKey;

/**
 Descriptive text for the device model. You should get this from either the android or iphone libraries so a consistent description is logged. i.e if the client is an android the model string must start with android.
 */
@property (nonatomic, strong) NSString *model;

/**
 For iPhone: ‘prod’ or ‘dev’. For Android: ‘c2dm’ only. This is used for push notification services, and log lines.
 */
@property (nonatomic, strong) NSString *mode;

/**
 The version of the client application.
 */
@property (nonatomic, strong) NSString *clientVersion;

/**
 The version of StreetHawkCore framework SDK.
 */
@property (nonatomic, strong) NSString *shVersion;

/**
 The actual access data required to message the device.
 */
@property (nonatomic, strong) NSString *pushNotificationToken;

/**
 The UTC time this install was created in %Y-%m-%d %H:%M:%S format
 */
@property (nonatomic, strong) NSDate *created;

/**
 The UTC time this install was created in %Y-%m-%d %H:%M:%S format
 */
@property (nonatomic, strong) NSDate *modified;

/**
 Ip address of current device. It's known by server, not sent from client.
 */
@property (nonatomic, strong) NSString *ipAddress;

/**
 Mac address sent to server by client. 
 */
@property (nonatomic, strong) NSString *macAddress;

/**
 Since iOS 7.0 mac address in unavailable, it always returns 02:00:00:00:00:00. Add identifierForVendor as another way to identifier vendor.
 */
@property (nonatomic, strong) NSString *identifierForVendor;

/**
 Negative feedback got from server. It set to time stamp once get error from Apple's push notification server.
 */
@property (nonatomic, strong) NSString *negativeFeedback;

/**
 The date when register push message but don't successfully got token. If got token this is set to empty.
 */
@property (nonatomic, strong) NSString *revoked;

/**
 Carrier of current device. It's sent from client to server.
 */
@property (nonatomic, strong) NSString *carrierName;

/**
 Screen resolution of current device. It's sent from client to server.
 */
@property (nonatomic, strong) NSString *resolution;

/**
 Operating system in lower case. Examples: “android”, “ios”, “windows”. Because this is iOS SDK, it's hard coded as "ios".
 */
@property (nonatomic, strong) NSString *operatingSystem;

/**
 The version of the operating system. Example: “7.0”.
 */
@property (nonatomic, strong) NSString *osVersion;

@end

/**
 **Extension for install register or update:**
 
 Call `registerOrUpdateInstallWithHandler:` to register or update install attributes.
 */
@interface SHApp (InstallExt)

/** @name Install */

/**
 Update the current install or create a new one if one does not exist.
 @param save_handler Callback for result.
 */
- (void)registerOrUpdateInstallWithHandler:(SHCallbackHandler)handler;

/**
 Some attribute maybe changed when re-launch this App, check them with pre-sent install when App launch. They include: app_key, client_version, sh_version, mode, carrier_name, os_version.
 @return If any of above attributes changes compared with previous install/register or install/update return YES; If not sent before or nothing change, return NO.
 */
- (BOOL)checkInstallChangeForLaunch;

@end
