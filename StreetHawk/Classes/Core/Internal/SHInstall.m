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
#import "SHLogger.h" //for sending logline
#import "SHRequest.h" //for sending register request
#import "SHUtils.h" //for shParseDate
#ifdef SH_FEATURE_NOTIFICATION
#import "SHApp+Notification.h" //for access_token
#endif
#if defined(SH_FEATURE_LATLNG) || defined(SH_FEATURE_GEOFENCE) || defined(SH_FEATURE_IBEACON)
#import "SHApp+Location.h"
#endif
#ifdef SH_FEATURE_IBEACON
#import "SHLocationManager.h" //for check iBeacon status
#endif
//header from Third-party
#import "SHUIDevice-Hardware.h"

NSString * const SHInstallRegistrationSuccessNotification = @"SHInstallRegistrationSuccessNotification";
NSString * const SHRegistrationFailureNotification = @"SHRegistrationFailureNotification";
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
    self.created = shParseDate(dict[@"created"], 0);
    self.modified = shParseDate(dict[@"modified"], 0);
    self.appKey = dict[@"app_key"];
    NSAssert(self.appKey != nil && self.appKey.length > 0, @"App key cannot be empty. Return json: %@.", dict);
    self.model = dict[@"model"];
    self.mode = dict[@"mode"];
    self.clientVersion = dict[@"client_version"];
    self.shVersion = dict[@"sh_version"];
    self.pushNotificationToken = dict[@"access_data"];
    self.ipAddress = dict[@"ipaddress"];
    self.macAddress = dict[@"macaddress"];
    self.negativeFeedback = dict[@"negative_feedback"];
    self.revoked = dict[@"revoked"];
    self.carrierName = dict[@"carrier_name"];
    self.resolution = dict[@"resolution"];
    self.operatingSystem = dict[@"operating_system"];
    self.osVersion = dict[@"os_version"];
    self.identifierForVendor = dict[@"identifier_for_vendor"];
}

- (NSString *)serverSaveURL
{
    return @"installs/update/";
}

- (NSObject *)saveBody
{
    //The default post parameters when do /install/register or /install/update. It contains "app_key", "client_version", "model", "mode", "user", "access_data", "carrier_name", "resolution", "revoked", "macaddress".
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
    [params addObject:@"resolution"];
    [params addObject:[NSString stringWithFormat:@"%.0f * %.0f", screenWidth, screenHeight]];
    NSString *developmentPlatform = shDevelopmentPlatformString();
    if (developmentPlatform != nil && developmentPlatform.length > 0 && [developmentPlatform compare:@"unknown" options:NSCaseInsensitiveSearch] != NSOrderedSame)
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
#ifdef SH_FEATURE_NOTIFICATION
    NSString *token = StreetHawk.apnsDeviceToken;
    if (token != nil && token.length > 0)
    {
        [params addObject:@"access_data"];
        [params addObject:token];
    }
#endif
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
    if (StreetHawk.advertisingIdentifier != nil && StreetHawk.advertisingIdentifier.length > 0)
    {
        [params addObject:@"advertising_identifier"];
        [params addObject:StreetHawk.advertisingIdentifier];
    }
#ifdef SH_FEATURE_IBEACON
    switch (StreetHawk.locationManager.iBeaconSupportState)
    {
        case SHiBeaconState_Unknown:
        {
            //not get accurate iBeacon state, do nothing.
        }
            break;
        case SHiBeaconState_Support:
        {
            [params addObject:@"ibeacons"];
            [params addObject:@"true"];
        }
            break;
        case SHiBeaconState_NotSupport:
        {
            [params addObject:@"ibeacons"];
            [params addObject:@"false"];
        }
            break;
        default:
        {
            NSAssert(NO, @"Unexpected iBeacon state: %d.", StreetHawk.locationManager.iBeaconSupportState);
        }
            break;
    }
#endif
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
    [params addObject:@"feature_locations"];
#if defined(SH_FEATURE_LATLNG) || defined(SH_FEATURE_GEOFENCE) || defined(SH_FEATURE_IBEACON)
    [params addObject:StreetHawk.isLocationServiceEnabled ? @"true" : @"false"];
#else
    [params addObject:@"false"];
#endif
    [params addObject:@"feature_push"];
#ifdef SH_FEATURE_NOTIFICATION
    [params addObject:StreetHawk.isNotificationEnabled ? @"true" : @"false"];
#else
    [params addObject:@"false"];
#endif
    [params addObject:@"feature_ibeacons"];
#ifdef SH_FEATURE_IBEACON
    [params addObject:@"true"];
#else
    [params addObject:@"false"];
#endif
    return params;
}

@end

@interface SHApp (private)//This category private interface declaration must have "private" to avoid warning: category is implementing a method which will also be implemented by its primary class

//Registers a new installation.
- (void)registerInstallWithHandler:(SHCallbackHandler)handler;

@end

@implementation SHApp (InstallExt)

#pragma mark - public functions

-(void)registerOrUpdateInstallWithHandler:(SHCallbackHandler)handler
{
    if (!streetHawkIsEnabled())
    {
        if (handler)
        {
            handler(nil, nil);
        }
        return;
    }
    handler = [handler copy];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^
    {
        NSAssert(![NSThread isMainThread], @"registerOrUpdateInstallWithHandler wait in main thread.");
        if (![NSThread isMainThread])
        {
            dispatch_semaphore_wait(self.install_semaphore, DISPATCH_TIME_FOREVER);
            // This is the global one stop shop for registering or updating info about the current installation to the server.  The first time the app is installed, no installation object is created, so a "nil" request is sent to the server to register a new installation. Once this is done, the installation ID is stored in user defaults and is loaded everytime the app is restarted.  After this each time, this method is called, the stored installation ID is used and only "update" requests are sent to the server (ie when APNS tokens have changed or "modes" have changed etc).    
            SHCallbackHandler handlerCopy = [handler copy];
            if (self.currentInstall)  // install exists so save the params
            {
                return [self.currentInstall saveToServer:^(NSObject *result, NSError *error)
                {
                    if (error == nil)
                    {
                        self.currentInstall = (SHInstall *)result;
                        dispatch_semaphore_signal(self.install_semaphore); //make sure currentInstall is set to latest.
                        //check client version upgrade, must do it before update local cache.
                        NSString *sentClientVersion = [[NSUserDefaults standardUserDefaults] objectForKey:SentInstall_ClientVersion];
                        if (sentClientVersion != nil && sentClientVersion.length > 0 && ![sentClientVersion isEqualToString:StreetHawk.clientVersion])
                        {
                            [StreetHawk sendLogForCode:LOG_CODE_CLIENTUPGRADE withComment:sentClientVersion];
                        }
                        //save sent install parameters for later compare, because install does not have local cache, and avoid query install/details/ from server. Only save it after successfully install/update.
                        [[NSUserDefaults standardUserDefaults] setObject:NONULL(StreetHawk.appKey) forKey:SentInstall_AppKey];
                        [[NSUserDefaults standardUserDefaults] setObject:StreetHawk.clientVersion forKey:SentInstall_ClientVersion];
                        [[NSUserDefaults standardUserDefaults] setObject:StreetHawk.version forKey:SentInstall_ShVersion];
                        [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:shAppMode()] forKey:SentInstall_Mode];
                        [[NSUserDefaults standardUserDefaults] setObject:shGetCarrierName() forKey:SentInstall_Carrier];
                        [[NSUserDefaults standardUserDefaults] setObject:[UIDevice currentDevice].systemVersion forKey:SentInstall_OSVersion];
#ifdef SH_FEATURE_IBEACON
                        [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:StreetHawk.locationManager.iBeaconSupportState] forKey:SentInstall_IBeacon];
#endif
                        [[NSUserDefaults standardUserDefaults] synchronize];
                        NSDictionary *userInfo = @{SHInstallNotification_kInstall: self.currentInstall};
                        [[NSNotificationCenter defaultCenter] postNotificationName:SHInstallUpdateSuccessNotification object:self userInfo:userInfo];
                    }
                    else
                    {
                        dispatch_semaphore_signal(self.install_semaphore);
                        NSDictionary *userInfo = @{SHInstallNotification_kInstall: self.currentInstall, SHInstallNotification_kError: error};
                        [[NSNotificationCenter defaultCenter] postNotificationName:SHInstallUpdateFailureNotification object:self userInfo:userInfo];
                    }
                    if (handlerCopy)
                    {
                        handlerCopy(self.currentInstall, error);
                    }
                }];
            }
            else    //install does not exist and we have no prior install id so create one
            {
                return [self registerInstallWithHandler:^(NSObject *result, NSError *error)
                {
                    if (error == nil)
                    {
                        self.currentInstall = (SHInstall *)result;
                        dispatch_semaphore_signal(self.install_semaphore); //make sure currentInstall is set to latest.
                        //save sent install parameters for later compare, because install does not have local cache, and avoid query install/details/ from server. Only save it after successfully install/register. 
                        [[NSUserDefaults standardUserDefaults] setObject:NONULL(StreetHawk.appKey) forKey:SentInstall_AppKey];
                        [[NSUserDefaults standardUserDefaults] setObject:StreetHawk.clientVersion forKey:SentInstall_ClientVersion];
                        [[NSUserDefaults standardUserDefaults] setObject:StreetHawk.version forKey:SentInstall_ShVersion];
                        [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:shAppMode()] forKey:SentInstall_Mode];
                        [[NSUserDefaults standardUserDefaults] setObject:shGetCarrierName() forKey:SentInstall_Carrier];
                        [[NSUserDefaults standardUserDefaults] setObject:[UIDevice currentDevice].systemVersion forKey:SentInstall_OSVersion];
#ifdef SH_FEATURE_IBEACON
                        [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:StreetHawk.locationManager.iBeaconSupportState] forKey:SentInstall_IBeacon];
#endif
                        [[NSUserDefaults standardUserDefaults] synchronize];
                        NSDictionary *userInfo = @{SHInstallNotification_kInstall: self.currentInstall};
                        [[NSNotificationCenter defaultCenter] postNotificationName:SHInstallRegistrationSuccessNotification object:self userInfo:userInfo];
                    }
                    else
                    {
                        dispatch_semaphore_signal(self.install_semaphore);
                        NSDictionary *userInfo = @{SHInstallNotification_kError: error};
                        [[NSNotificationCenter defaultCenter] postNotificationName:SHRegistrationFailureNotification object:self userInfo:userInfo];
                    }
                    if (handlerCopy)
                    {
                        handlerCopy(self.currentInstall, error);
                    }
                }];
            }
        }
    });
}

NSString *SentInstall_AppKey = @"SentInstall_AppKey";
NSString *SentInstall_ClientVersion = @"SentInstall_ClientVersion";
NSString *SentInstall_ShVersion = @"SentInstall_ShVersion";
NSString *SentInstall_Mode = @"SentInstall_Mode";
NSString *SentInstall_Carrier = @"SentInstall_Carrier";
NSString *SentInstall_OSVersion = @"SentInstall_OSVersion";
#ifdef SH_FEATURE_IBEACON
NSString *SentInstall_IBeacon = @"SentInstall_IBeacon";
#endif

-(BOOL)checkInstallChangeForLaunch
{
    NSString *sentAppKey = [[NSUserDefaults standardUserDefaults] objectForKey:SentInstall_AppKey];
    NSString *sentClientVersion = [[NSUserDefaults standardUserDefaults] objectForKey:SentInstall_ClientVersion];
    NSString *sentShVersion = [[NSUserDefaults standardUserDefaults] objectForKey:SentInstall_ShVersion];
    NSString *sentCarrier = [[NSUserDefaults standardUserDefaults] objectForKey:SentInstall_Carrier];
    NSString *sentOsVersion = [[NSUserDefaults standardUserDefaults] objectForKey:SentInstall_OSVersion];
#ifdef SH_FEATURE_IBEACON
    SHiBeaconState sentiBeacon = [[[NSUserDefaults standardUserDefaults] objectForKey:SentInstall_IBeacon] intValue];
    SHiBeaconState currentiBeacon = StreetHawk.locationManager.iBeaconSupportState;
    return ((sentAppKey != nil && sentAppKey.length > 0 && ![sentAppKey isEqualToString:StreetHawk.appKey])
            || (sentClientVersion != nil && sentClientVersion.length > 0 && ![sentClientVersion isEqualToString:StreetHawk.clientVersion])
            || (sentShVersion != nil && sentShVersion.length > 0 && ![sentShVersion isEqualToString:StreetHawk.version])
            || (sentCarrier != nil && sentCarrier.length > 0 && ![sentCarrier isEqualToString:shGetCarrierName()])
            || (sentOsVersion != nil && sentOsVersion.length > 0 && ![sentOsVersion isEqualToString:[UIDevice currentDevice].systemVersion])
            || (sentiBeacon == SHiBeaconState_Unknown)/*sent is unknown, update install and refresh sent again*/ || (currentiBeacon != SHiBeaconState_Unknown && sentiBeacon != currentiBeacon/*current change*/));
#else
    return ((sentAppKey != nil && sentAppKey.length > 0 && ![sentAppKey isEqualToString:StreetHawk.appKey])
            || (sentClientVersion != nil && sentClientVersion.length > 0 && ![sentClientVersion isEqualToString:StreetHawk.clientVersion])
            || (sentShVersion != nil && sentShVersion.length > 0 && ![sentShVersion isEqualToString:StreetHawk.version])
            || (sentCarrier != nil && sentCarrier.length > 0 && ![sentCarrier isEqualToString:shGetCarrierName()])
            || (sentOsVersion != nil && sentOsVersion.length > 0 && ![sentOsVersion isEqualToString:[UIDevice currentDevice].systemVersion]));
#endif
}

#pragma mark - private functions

-(void)registerInstallWithHandler:(SHCallbackHandler)handler
{
    //create a fake SHInstall to get save body
    SHInstall *fakeInstall = [[SHInstall alloc] initWithSuid:@"fake_install"];
    handler = [handler copy];
    NSAssert(StreetHawk.currentInstall == nil, @"Install should not exist when call installs/register/.");
    SHRequest *request = [SHRequest requestWithPath:@"installs/register/" withVersion:SHHostVersion_V1 withParams:nil withMethod:@"POST" withHeaders:nil withBodyOrStream:[fakeInstall saveBody]];
    request.requestHandler = ^(SHRequest *registerRequest)
    {
        SHInstall *new_install = nil;
        NSError *error = registerRequest.error;
        if (registerRequest.error == nil)
        {
            NSAssert(registerRequest.resultValue != nil && [registerRequest.resultValue isKindOfClass:[NSDictionary class]], @"Register install return wrong json: %@.", registerRequest.resultValue);
            if (registerRequest.resultValue != nil && [registerRequest.resultValue isKindOfClass:[NSDictionary class]])
            {
                NSDictionary *dict = (NSDictionary *)registerRequest.resultValue;
                new_install = [[SHInstall alloc] initWithSuid:dict[@"installid"]];
                [new_install loadFromDictionary:dict];
            }
            else
            {
                error = [NSError errorWithDomain:SHErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Register install return wrong json: %@.", registerRequest.resultValue]}];
            }
        }
        if (handler)
        {
            handler(new_install, error);
        }
    };
    [request startAsynchronously];
}

@end
