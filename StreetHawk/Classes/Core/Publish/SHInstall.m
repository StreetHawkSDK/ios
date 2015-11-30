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

#import "SHInstall.h"
//header from StreetHawk
#import "SHApp.h" //for StreetHawk
#import "SHLogger.h" //for sending logline
#import "SHRequest.h" //for sending register request
#import "SHUtils.h" //for shParseDate
//header from Third-party
#import "SHUIDevice-Hardware.h"

NSString * const SHInstallRegistrationSuccessNotification = @"SHInstallRegistrationSuccessNotification";
NSString * const SHInstallRegistrationFailureNotification = @"SHInstallRegistrationFailureNotification";
NSString * const SHInstallUpdateSuccessNotification = @"SHInstallUpdateSuccessNotification";
NSString * const SHInstallUpdateFailureNotification = @"SHInstallUpdateFailureNotification";

NSString * const SHInstallNotification_kInstall = @"Install";
NSString * const SHInstallNotification_kError = @"Error";

@implementation SHInstall

#pragma mark - life cycle


- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p> - Install id: %@, App: %@, Access data: %@, Revoked: %@.", [self class], self, self.suid, self.appKey, self.pushNotificationToken, self.revoked];
}

#pragma mark - override

- (NSString *)serverLoadURL
{
    return @"installs/details/";
}

- (void)loadFromDictionary:(NSDictionary *)dict
{
    self.appKey = NONULL(dict[@"app_key"]);
    NSAssert(!shStrIsEmpty(self.appKey), @"App key cannot be empty. Return json: %@.", dict);
    self.sh_cuid = NONULL(dict[@"sh_cuid"]);
    self.clientVersion = NONULL(dict[@"client_version"]);
    self.shVersion = NONULL(dict[@"sh_version"]);
    self.operatingSystem = NONULL(dict[@"operating_system"]);
    self.osVersion = NONULL(dict[@"os_version"]);
    self.live = [NONULL(dict[@"live"]) boolValue];
    self.developmentPlatform = NONULL(dict[@"development_platform"]);
    self.created = shParseDate(NONULL(dict[@"created"]), 0);
    self.modified = shParseDate(NONULL(dict[@"modified"]), 0);
    self.replaced = NONULL(dict[@"replaced"]);
    self.uninstalled = shParseDate(NONULL(dict[@"uninstalled"]), 0);
    self.featureLocation = [NONULL(dict[@"feature_locations"]) boolValue];
    self.featurePush = [NONULL(dict[@"feature_push"]) boolValue];
    self.featureiBeacons = [NONULL(dict[@"feature_ibeacons"]) boolValue];
    self.supportiBeacons = [NONULL(dict[@"ibeacons"]) boolValue];
    self.mode = NONULL(dict[@"mode"]);
    self.pushNotificationToken = NONULL(dict[@"access_data"]);
    self.negativeFeedback = NONULL(dict[@"negative_feedback"]);
    self.revoked = NONULL(dict[@"revoked"]);
    self.smart = [NONULL(dict[@"smart"]) boolValue];
    self.feed = NONULL(dict[@"feed"]);
    self.latitude = NONULL(dict[@"latitude"]);
    self.longitude = NONULL(dict[@"longitude"]);
    self.utcOffset = [NONULL(dict[@"utc_offset"]) integerValue];
    self.model = NONULL(dict[@"model"]);
    self.ipAddress = NONULL(dict[@"ipaddress"]);
    self.macAddress = NONULL(dict[@"macaddress"]);
    self.identifierForVendor = NONULL(dict[@"identifier_for_vendor"]);
    self.advertisingIdentifier = NONULL(dict[@"advertising_identifier"]);
    self.carrierName = NONULL(dict[@"carrier_name"]);
    self.resolution = NONULL(dict[@"resolution"]);
}

- (NSString *)serverSaveURL
{
    return @"installs/update/";
}

- (NSObject *)saveBody
{
    UIDevice *uiDevice = [UIDevice currentDevice];
    SHUIDevice *shDevice = [[SHUIDevice alloc] init];
    NSMutableArray *params = [NSMutableArray arrayWithObjects:
                              @"app_key", NONULL(StreetHawk.appKey),
                              @"client_version", StreetHawk.clientVersion,
                              @"sh_version", StreetHawk.version,
                              @"model", NONULL(shDevice.platformString), //rename class not use UIDevice extension, to avoid link to wrong obj
                              @"carrier_name", shGetCarrierName(),
                              @"operating_system", @"ios",
                              @"os_version", uiDevice.systemVersion, nil];
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    CGFloat screenWidth = screenRect.size.width;
    CGFloat screenHeight = screenRect.size.height;
    if (screenWidth > screenHeight)  //since iOS 8 main screen bounds include orientation, but install/update always wants width*heigth.
    {
        CGFloat temp = screenHeight;
        screenHeight = screenWidth;
        screenWidth = temp;
    }
    [params addObject:@"width"];
    [params addObject:@(screenWidth)];
    [params addObject:@"height"];
    [params addObject:@(screenHeight)];
    NSString *developmentPlatform = shDevelopmentPlatformString();
    if (!shStrIsEmpty(developmentPlatform) && [developmentPlatform compare:@"unknown" options:NSCaseInsensitiveSearch] != NSOrderedSame)
    {
        [params addObject:@"development_platform"];
        [params addObject:developmentPlatform];
    }
    switch (shAppMode())
    {
        case SHAppMode_AdhocProvisioning:
        case SHAppMode_AppStore:
        case SHAppMode_Enterprise:
        {
            [params addObject:@"mode"];
            [params addObject:@"prod"]; //use StreetHawk server's production certificate
        }
            break;
        case SHAppMode_DevProvisioning:
        {
            [params addObject:@"mode"];
            [params addObject:@"dev"]; //use StreetHawk server's development certificate
        }
            break;
        case SHAppMode_Simulator:
        {
            [params addObject:@"mode"];
            [params addObject:@"simulator"]; //simulator cannot register remote notification
        }
            break;
        default:
            //for SHAppMode_Unknown not submit.
            break;
    }
    NSString *token = [[NSUserDefaults standardUserDefaults] objectForKey:@"APNS_DEVICE_TOKEN"]; //cannot access notification module API `StreetHawk.apnsDeviceToken`, use direct value.
    if (token != nil && token.length > 0)
    {
        [params addObject:@"access_data"];
        [params addObject:token];
    }
    [params addObject:@"revoked"];
    NSNumber *disablePushTimeVal = [[NSUserDefaults standardUserDefaults] objectForKey:APNS_DISABLE_TIMESTAMP];
    [[NSUserDefaults standardUserDefaults] setObject:disablePushTimeVal != nil ? disablePushTimeVal : @0.0 forKey:APNS_SENT_DISABLE_TIMESTAMP];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [params addObject:(disablePushTimeVal == nil || [disablePushTimeVal doubleValue] == 0) ? @"" : shFormatStreetHawkDate([NSDate dateWithTimeIntervalSince1970:disablePushTimeVal.doubleValue])];
    NSString *macAddress = shGetMacAddress();  //mac address cannot be got since iOS 7.0, always return "02:00:00:00:00:00".
    if (macAddress != nil && [macAddress compare:@"02:00:00:00:00:00"] != NSOrderedSame)
    {
        [params addObject:@"macaddress"];
        [params addObject:macAddress];
    }
    if ([uiDevice respondsToSelector:@selector(identifierForVendor)])  //identifierForVendor available since iOS 6.0
    {
        NSUUID *identifierForVendor = uiDevice.identifierForVendor;
        if (identifierForVendor != nil && [identifierForVendor UUIDString] != nil && [identifierForVendor UUIDString].length > 0)
        {
            [params addObject:@"identifier_for_vendor"];
            [params addObject:[identifierForVendor UUIDString]];
        }
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_LMBridge_UpdateiBeaconStatus" object:nil];
    int iBeaconSupportStatus = [[[NSUserDefaults standardUserDefaults] objectForKey:SH_BEACON_iBEACON] intValue];
    switch (iBeaconSupportStatus)
    {
        case 0/*SHiBeaconState_Unknown*/:
        {
            //not get accurate iBeacon state, do nothing.
        }
            break;
        case 1/*SHiBeaconState_Support*/:
        {
            [params addObject:@"ibeacons"];
            [params addObject:@"true"];
        }
            break;
        case 2/*SHiBeaconState_NotSupport*/:
        {
            [params addObject:@"ibeacons"];
            [params addObject:@"false"];
        }
            break;
        case 3/*SHiBeaconState_Ignore*/:
        {
            [params addObject:@"ibeacons"]; //if remove streetHawk/Beacons module, refresh otherwise server still treat as it supports iBeacons.
            [params addObject:@"false"];
        }
            break;
        default:
        {
            NSAssert(NO, @"Unexpected iBeacon state: %d.", iBeaconSupportStatus);
        }
            break;
    }
    switch (shAppMode())
    {
        case SHAppMode_AppStore:
        case SHAppMode_Enterprise:
        {
            [params addObject:@"live"];
            [params addObject:@"true"];
        }
            break;
        case SHAppMode_AdhocProvisioning:
        case SHAppMode_DevProvisioning:
        case SHAppMode_Simulator:
        case SHAppMode_Unknown:
        {
            [params addObject:@"live"];
            [params addObject:@"false"];
        }
            break;
        default:
        {
            NSAssert(NO, @"Unexpected App mode: %d.", shAppMode());
        }
            break;
    }
    return params;
}

@end
