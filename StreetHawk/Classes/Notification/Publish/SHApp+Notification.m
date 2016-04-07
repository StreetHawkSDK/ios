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

#import "SHApp+Notification.h"
//header from StreetHawk
#import "SHNotificationHandler.h"
#import "SHFriendlyNameObject.h"
#import "InteractivePush.h"
#import "SHInstallHandler.h" //for registerForNotificationAndNotifyServer
#import "SHUtils.h"  //for SHLog
#import "SHHTTPSessionManager.h" //for sending request
#import "SHAppStatus.h" //for appStatusChange
#import "SHInteractiveButtons.h" //for interactive pair buttons
//header from System
#import <objc/runtime.h> //for associate object

#define APNS_DEVICE_TOKEN                   @"APNS_DEVICE_TOKEN"
#define ENABLE_PUSH_NOTIFICATION            @"ENABLE_PUSH_NOTIFICATION"  //key for record user manually set isNotificationEnabled. Although it's used for both remote and local, key not change name to be compatible with old version.
#define ALERTSETTINGS_MINUTES   @"ALERTSETTINGS_MINUTES"  //Get and set alert settings is asynchronous, but need an synchronous API in SHApp. Store this locally. It's int value of pause minutes.

@implementation SHApp (NotificationExt)

#pragma mark - properties

@dynamic isDefaultNotificationEnabled;
@dynamic isNotificationEnabled;
@dynamic notificationTypes;
@dynamic notificationHandler;
@dynamic arrayCustomisedHandler;
@dynamic arrayPGObservers;
@dynamic systemPreferenceDisableNotification;

- (BOOL)isDefaultNotificationEnabled
{
    NSNumber *value = objc_getAssociatedObject(self, @selector(isDefaultNotificationEnabled));
    return [value boolValue];
}

- (void)setIsDefaultNotificationEnabled:(BOOL)isDefaultNotificationEnabled
{
    objc_setAssociatedObject(self, @selector(isDefaultNotificationEnabled), [NSNumber numberWithBool:isDefaultNotificationEnabled], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)isNotificationEnabled
{
    //if never manually set isPushNotificationEnabled, use default value
    NSObject *setObj = [[NSUserDefaults standardUserDefaults] objectForKey:ENABLE_PUSH_NOTIFICATION];
    if (setObj == nil || ![setObj isKindOfClass:[NSNumber class]])
    {
        return self.isDefaultNotificationEnabled;
    }
    //otherwise use manually set value
    return [(NSNumber *)setObj boolValue];
}

- (void)setIsNotificationEnabled:(BOOL)isNotificationEnabled
{
    if (self.isNotificationEnabled != isNotificationEnabled)
    {
        //update StreetHawk.isPushNotificationEnable first, as next part will consider it. By setting user defaults above get method will use it.
        [[NSUserDefaults standardUserDefaults] setBool:isNotificationEnabled forKey:ENABLE_PUSH_NOTIFICATION];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [StreetHawk registerForNotificationAndNotifyServer];  //handle system register or revoke update
    }
}

- (NSUInteger)notificationTypes
{
    NSNumber *value = objc_getAssociatedObject(self, @selector(notificationTypes));
    return [value unsignedIntegerValue];
}

- (void)setNotificationTypes:(NSUInteger)notificationTypes
{
    objc_setAssociatedObject(self, @selector(notificationTypes), [NSNumber numberWithUnsignedInteger:notificationTypes], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (SHNotificationHandler *)notificationHandler
{
    return objc_getAssociatedObject(self, @selector(notificationHandler));
}

- (void)setNotificationHandler:(SHNotificationHandler *)notificationHandler
{
    objc_setAssociatedObject(self, @selector(notificationHandler), notificationHandler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSMutableArray *)arrayCustomisedHandler
{
    return objc_getAssociatedObject(self, @selector(arrayCustomisedHandler));
}

- (void)setArrayCustomisedHandler:(NSMutableArray *)arrayCustomisedHandler
{
    objc_setAssociatedObject(self, @selector(arrayCustomisedHandler), arrayCustomisedHandler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSMutableArray *)arrayPGObservers
{
    return objc_getAssociatedObject(self, @selector(arrayPGObservers));
}

- (void)setArrayPGObservers:(NSMutableArray *)arrayPGObservers
{
    objc_setAssociatedObject(self, @selector(arrayPGObservers), arrayPGObservers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)systemPreferenceDisableNotification
{
    BOOL notificationDisabled;
    UIApplication *application = [UIApplication sharedApplication];
    if ([[UIDevice currentDevice].systemVersion doubleValue] >= 8.0)
    {
        notificationDisabled = (!application.isRegisteredForRemoteNotifications || (application.currentUserNotificationSettings.types == UIUserNotificationTypeNone));
    }
    else
    {
        notificationDisabled = (application.enabledRemoteNotificationTypes == UIRemoteNotificationTypeNone || application.enabledRemoteNotificationTypes == UIRemoteNotificationTypeNewsstandContentAvailability/*this is not settable in UI*/);
    }
    return notificationDisabled;
}

#pragma mark - public functions

- (BOOL)setInteractivePushBtnPairs:(NSArray *)arrayPairs
{
    if (!streetHawkIsEnabled())
    {
        return NO;
    }
    //clean and save whole user customized pairs.
    NSMutableArray *array = [NSMutableArray array];
    for (InteractivePush *obj in arrayPairs)
    {
        NSAssert(!shStrIsEmpty(obj.pairTitle), @"pairTitle shouldn't be empty.");
        if (shStrIsEmpty(obj.pairTitle))
        {
            SHLog(@"WARNING: pairTitle shouldn't be empty.");
            return NO;
        }
        if ([SHInteractiveButtons pairTitle:obj.pairTitle andButton1:nil andButton2:nil isUsed:array] || [SHInteractiveButtons pairTitle:obj.pairTitle andButton1:nil andButton2:nil isUsed:[SHInteractiveButtons predefinedLocalPairs]])
        {
            SHLog(@"WARNING: pairTitle \"%@\" is already used, please choose another one.", obj.pairTitle);
            return NO;
        }
        NSAssert(!shStrIsEmpty(obj.b1Title) || !shStrIsEmpty(obj.b2Title), @"b1 and b2 cannot both empty.");
        if (shStrIsEmpty(obj.b1Title) && shStrIsEmpty(obj.b2Title))
        {
            SHLog(@"WARNING: b1 and b2 cannot both empty.");
            return NO;
        }
        NSMutableDictionary *dictPair = [NSMutableDictionary dictionary];
        dictPair[SH_INTERACTIVEPUSH_PAIR] = NONULL(obj.pairTitle);
        dictPair[SH_INTERACTIVEPUSH_BUTTON1] = NONULL(obj.b1Title);
        dictPair[SH_INTERACTIVEPUSH_BUTTON2] = NONULL(obj.b2Title);
        [array addObject:dictPair];
    }
    //Not check whether it's changed, when upgrade client App version it must submit again whatever the pair is changed or not.
    //A concern is submit too much. System predefined only submit when app_status/submit_interactive_button=1, client only submit in debug mode, so wide used production will not submit too much.
    if (arrayPairs.count > 0) //system automatically submit should not override customer's.
    {
        [[NSUserDefaults standardUserDefaults] setObject:array forKey:SH_INTERACTIVEPUSH_KEY]; //remember customer's.
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    //Re-register categories locally.
    [self registerForNotificationAndNotifyServer];
    //Following should NOT trigger on an Apple Store version, it should ONLY happen on debug.
    if (StreetHawk.isDebugMode && shAppMode() != SHAppMode_AppStore && shAppMode() != SHAppMode_Enterprise /*Some customer always set debug mode = YES, but AppStore version should not always send friendly names*/
        && ([UIApplication sharedApplication].applicationState != UIApplicationStateBackground)/*avoid send when App wake up in background. Here cannot use Active, its status is InActive for normal launch, Background for location launch.*/)
    {
        //In debug mode, each "setInteractivePushBtnPairs" do submit regardless "submit_interactive_button"; in production mode, only submit when "submit_interactive_button"=true.
        //By doing this, SDK user won't feel inconvenient when debugging App, because pair submitted without any condition; final release won't submit useless request (actually final release won't submit any request, because debug mode fill that client_version).
        [SHInteractiveButtons submitInteractivePairButtons];
    }
    return YES;
}

- (void)registerForNotificationAndNotifyServer
{
    //This is called when App from background to foreground to check notification status: is it enabled, is the access_token need update.
    //It's possible to know notification for this App is disabled, set the time stamp for the earliest disable time.
    BOOL notificationDisabled = !StreetHawk.isNotificationEnabled/*customer disable StreetHawk, send revoked*/;
    UIApplication *application = [UIApplication sharedApplication];
    if (!notificationDisabled)
    {
        //customer not disable it, check system settings
        if ([[UIDevice currentDevice].systemVersion doubleValue] >= 8.0)
        {
            notificationDisabled = (!application.isRegisteredForRemoteNotifications || (application.currentUserNotificationSettings.types == UIUserNotificationTypeNone));
        }
        else
        {
            notificationDisabled = (application.enabledRemoteNotificationTypes == UIRemoteNotificationTypeNone/*none type enabled means it's turn off. when App first launch, even enabled before and no permission dialog promote, it gets 0, but does not matter as next set access token clean it; and it never happen in next launch.*/ || application.enabledRemoteNotificationTypes == UIRemoteNotificationTypeNewsstandContentAvailability/*this is not settable in UI*/);
        }
        if (notificationDisabled)
        {
            SHLog(@"Notification is disabled by system preferrence settings, or fail to configure in project.");
        }
    }
    else
    {
        SHLog(@"Notification is disabled by `StreetHawk.isNotificationEnabled=NO`.");
    }
    if (notificationDisabled)
    {
        BOOL needUpdate = NO;
        NSNumber *disableTimestamp = [[NSUserDefaults standardUserDefaults] objectForKey:APNS_DISABLE_TIMESTAMP];
        if (disableTimestamp == nil || [disableTimestamp doubleValue] == 0)
        {
            [[NSUserDefaults standardUserDefaults] setDouble:[[NSDate date] timeIntervalSince1970] forKey:APNS_DISABLE_TIMESTAMP];
            [[NSUserDefaults standardUserDefaults] synchronize];
            needUpdate = YES;
        }
        else
        {
            NSNumber *sentDisableTimestamp = [[NSUserDefaults standardUserDefaults] objectForKey:APNS_SENT_DISABLE_TIMESTAMP];
            if (sentDisableTimestamp == nil || sentDisableTimestamp.doubleValue != disableTimestamp.doubleValue)
            {
                needUpdate = YES;  //for some reason (is registering and may ignore one update) not upload previous one successful, double check here.
            }
        }
        if (needUpdate)
        {
            [StreetHawk registerOrUpdateInstallWithHandler:nil];
            SHLog(@"Upload notification disable info `revoked` to server.");
        }
    }
    if (StreetHawk.isNotificationEnabled)  //not call this for customer disable notification to avoid permission message, work both for remote and location notification.
    {
        //No matter system enabled or disabled, register it. For a fresh new App system is not enabled, if check `notificationDisabled` it will never register notification.
        if ([application respondsToSelector:@selector(registerUserNotificationSettings:)])  //iOS 8 uses totally new way to register remote notification.
        {
            if (StreetHawk.notificationTypes > (UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound))
            {
                StreetHawk.notificationTypes = (UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound); //compatible for pre-iOS 8 user settings.
            }
            NSMutableSet *categories = [NSMutableSet set];
            if (StreetHawk.developmentPlatform != SHDevelopmentPlatform_Unity) //Unity sample AngryBots: if App not launch, send push, click action button App will hang. It not happen if click banner, it not happen if App already launch and in BG. To avoid this stop working issue, Unity not have action button.
            {
                //Add system predefined categories first
                for (SHInteractiveButtons *obj in [SHInteractiveButtons predefinedPairs])
                {
                    [SHInteractiveButtons addCategory:[obj createNotificationCategory] toSet:categories];
                }
                //Read customized button pairs and add to categories too.
                [SHInteractiveButtons addCustomisedButtonPairsToSet:categories];
            }
            UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:StreetHawk.notificationTypes categories:categories];
            [application registerUserNotificationSettings:settings];
            SHLog(@"Register user notification since iOS 8.");
        }
        else
        {
            [[UIApplication sharedApplication] registerForRemoteNotificationTypes:StreetHawk.notificationTypes];
            SHLog(@"Register remote notification before iOS 8.");
        }
    }
}

- (void)handleUserNotificationSettings:(UIUserNotificationSettings *)settings
{
    if (settings.types != UIUserNotificationTypeNone)
    {
        [[UIApplication sharedApplication] registerForRemoteNotifications];
        SHLog(@"Register remote notification since iOS 8.");
    }
}

- (void)setApnsDeviceToken:(NSData *)value
{
    if (self.currentInstall == nil || self.currentInstall.suid == nil)
    {
        return;  //in normal App register remote notification happen after get install, however in Titanium uses `Ti.Network.registerForPushNotifications` and this is possible happen before get install. not save local cache so that next time it takes effect again.
    }
    //get callback, clear time stamp. it can happen when App is in background and enable system settings.
    [[NSUserDefaults standardUserDefaults] setDouble:0 forKey:APNS_DISABLE_TIMESTAMP];
    [[NSUserDefaults standardUserDefaults] synchronize];
    BOOL needUpdateInstall = NO;
    if (value != nil)
    {
        NSString *deviceTokenStr = shDataToHexString(value);
        NSString *savedDeviceTokenStr = [[NSUserDefaults standardUserDefaults] objectForKey:APNS_DEVICE_TOKEN];
        if (savedDeviceTokenStr == nil || ![savedDeviceTokenStr isEqualToString:deviceTokenStr])  //only save if the device token changed
        {
            [[NSUserDefaults standardUserDefaults] setValue:deviceTokenStr forKey:APNS_DEVICE_TOKEN];
            [[NSUserDefaults standardUserDefaults] synchronize];
            needUpdateInstall = YES;
            SHLog(@"Assign notification token %@.", deviceTokenStr);
        }
    }
    needUpdateInstall = needUpdateInstall/*token changed*/ || (self.currentInstall.revoked != nil && self.currentInstall.revoked.length > 0)/*server has revoked to be clear*/;
    if (needUpdateInstall)
    {
        [self registerOrUpdateInstallWithHandler:nil];
    }
}

- (NSString *)apnsDeviceToken
{
    return [[NSUserDefaults standardUserDefaults] objectForKey:APNS_DEVICE_TOKEN];
}

- (void)handleRemoteNotification:(NSDictionary *)userInfo treatAppAs:(SHAppFGBG)appFGBG needComplete:(BOOL)needComplete fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    BOOL isDefinedCode = [StreetHawk.notificationHandler isDefinedCode:userInfo];
    if (isDefinedCode)
    {
        [StreetHawk.notificationHandler handleDefinedUserInfo:userInfo withAction:SHNotificationActionResult_Unknown treatAppAs:appFGBG forNotificationType:SHNotificationType_Remote];
    }
    if (needComplete && completionHandler != nil)
    {
        completionHandler(UIBackgroundFetchResultNoData);
    }
}

- (void)handleRemoteNotification:(NSDictionary *)userInfo withActionId:(NSString *)identifier needComplete:(BOOL)needComplete completionHandler:(void (^)())completionHandler
{
    BOOL isDefinedCode = [StreetHawk.notificationHandler isDefinedCode:userInfo];
    if (isDefinedCode)
    {
        SHNotificationActionResult action = [identifier intValue]; //defined code uses `action` as identifier.
        NSAssert(action != SHNotificationActionResult_Unknown, @"Unknown action id for defined payload: %@.", userInfo);
        [StreetHawk.notificationHandler handleDefinedUserInfo:userInfo withAction:action treatAppAs:SHAppFGBG_BG/*this only trigger when App in BG, now app state is inactive*/ forNotificationType:SHNotificationType_Remote];
    }
    if (needComplete && completionHandler != nil)
    {
        completionHandler();
    }
}

- (void)handleLocalNotification:(UILocalNotification *)notification treatAppAs:(SHAppFGBG)appFGBG needComplete:(BOOL)needComplete fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    if (notification.userInfo != nil) //currently only support `userInfo`. local can do more such as location based notification.
    {
        BOOL isDefinedCode = [StreetHawk.notificationHandler isDefinedCode:notification.userInfo];
        if (isDefinedCode)
        {
            [StreetHawk.notificationHandler handleDefinedUserInfo:notification.userInfo withAction:SHNotificationActionResult_Unknown treatAppAs:appFGBG forNotificationType:SHNotificationType_Local];
        }
    }
    if (needComplete && completionHandler != nil)
    {
        completionHandler(UIBackgroundFetchResultNoData);
    }
}

- (void)handleLocalNotification:(UILocalNotification *)notification withActionId:(NSString *)identifier needComplete:(BOOL)needComplete completionHandler:(void (^)())completionHandler
{
    if (notification.userInfo != nil) //currently only support `userInfo`. local can do more such as location based notification.
    {
        BOOL isDefinedCode = [StreetHawk.notificationHandler isDefinedCode:notification.userInfo];
        if (isDefinedCode)
        {
            SHNotificationActionResult action = [identifier intValue]; //defined code uses `action` as identifier.
            NSAssert(action != SHNotificationActionResult_Unknown, @"Unknown action id for defined payload: %@.", notification.userInfo);
            [StreetHawk.notificationHandler handleDefinedUserInfo:notification.userInfo withAction:action treatAppAs:SHAppFGBG_BG/*this only trigger when App in BG, now app state is inactive*/ forNotificationType:SHNotificationType_Local];
        }
        if (needComplete)
        {
            completionHandler();
        }
    }
}

- (BOOL)setApplicationBadge:(NSInteger)badgeNumber
{
    UIApplication *application = [UIApplication sharedApplication];
    if ([application respondsToSelector:@selector(currentUserNotificationSettings)])  //since iOS 8
    {
        if (application.currentUserNotificationSettings.types & UIUserNotificationTypeBadge) //has badge permission
        {
            [application setApplicationIconBadgeNumber:badgeNumber];
            return YES;
        }
        else
        {
            return NO;
        }
    }
    else
    {
        [application setApplicationIconBadgeNumber:badgeNumber]; //before iOS 8 no permisson check
        return YES;
    }
}

- (void)shSetAlertSetting:(NSInteger)pauseMinutes finish:(SHCallbackHandler)handler
{
    if (StreetHawk.currentInstall.suid == nil || StreetHawk.currentInstall.suid.length == 0)
    {
        if (handler)
        {
            handler(nil, [NSError errorWithDomain:SHErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey: @"Not install to server."}]);
        }
        return;
    }
    handler = [handler copy];
    [[SHHTTPSessionManager sharedInstance] POST:@"installs/alert_settings/" hostVersion:SHHostVersion_V1 body:@{@"pause_minutes": @(pauseMinutes)} success:^(NSURLSessionDataTask * _Nullable task, id  _Nullable responseObject)
    {
        //save local cache
        [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInteger:pauseMinutes] forKey:ALERTSETTINGS_MINUTES];
        [[NSUserDefaults standardUserDefaults] synchronize];
        if (handler)
        {
            handler(nil, nil);
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nullable error)
    {
        if (handler)
        {
            handler(nil, error);
        }
    }];
}

- (NSInteger)getAlertSettingMinutes
{
    //read from server is asynchronous, but Phonegap etc needs synchronous immediately return, so just read from local cache. Currently once delete and re-install, server not keep alert settings, so read local cache is enough.
    NSInteger alertSetting = 0; //not pause
    NSObject *alertSettingVal = [[NSUserDefaults standardUserDefaults] objectForKey:ALERTSETTINGS_MINUTES];
    if (alertSettingVal != nil && [alertSettingVal isKindOfClass:[NSNumber class]])
    {
        alertSetting = [(NSNumber *)alertSettingVal integerValue];
    }
    return alertSetting;
}

- (void)getAlertSettingPauseUntil:(SHCallbackHandler)handler
{
    //first need check saved alert settings before, otherwise query will meet 404 error.
    NSObject *alertSettingVal = [[NSUserDefaults standardUserDefaults] objectForKey:ALERTSETTINGS_MINUTES];
    if (alertSettingVal == nil) //never save before
    {
        if (handler)
        {
            handler([NSDate date], nil);
        }
        return;
    }
    //server should have record, read calculated value from server.
    handler = [handler copy];
    [[SHHTTPSessionManager sharedInstance] GET:@"installs/alert_settings/" hostVersion:SHHostVersion_V1 parameters:nil success:^(NSURLSessionDataTask * _Nullable task, id  _Nullable responseObject)
    {
        NSDate *pauseUntil = nil;
        NSError *error = nil;
        NSAssert(responseObject != nil && [responseObject isKindOfClass:[NSDictionary class]], @"Load from server get wrong result value: %@.", responseObject);  //load request suppose to get json dictionary
        if (responseObject != nil && [responseObject isKindOfClass:[NSDictionary class]])
        {
            pauseUntil = shParseDate(((NSDictionary *)responseObject)[@"pause_until"], 0);
            //By the way, sync minute local cache
            [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInteger:[((NSDictionary *)responseObject)[@"pause_minutes"] integerValue]] forKey:ALERTSETTINGS_MINUTES];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        else
        {
            error = [NSError errorWithDomain:SHErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Load from server get wrong result value: %@.", responseObject]}];
        }
        if (handler)
        {
            handler(pauseUntil, error);
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nullable error)
    {
        if (handler)
        {
            handler(nil, error);
        }
    }];
}

- (void)shSetCustomiseHandler:(id<ISHCustomiseHandler>)handler
{
    NSAssert(handler != nil, @"Customise handler is nil");
    if (handler != nil)
    {
        if (![self.arrayCustomisedHandler containsObject:handler])
        {
            [self.arrayCustomisedHandler insertObject:handler atIndex:0];
        }
    }
}

- (void)handlePushDataForAppCallback:(PushDataForApplication *)pushData clickButton:(ClickButtonHandler)handler
{
    for (int i = 0; i < self.arrayCustomisedHandler.count; i ++)
    {
        id<ISHCustomiseHandler> callback = self.arrayCustomisedHandler[i];
        BOOL isHandled = NO;
        if ([callback respondsToSelector:@selector(onReceive:clickButton:)])
        {
            isHandled = [callback onReceive:pushData clickButton:handler];
        }
        if (isHandled)
        {
            return; //find one can handle it
        }
    }
    NSAssert(NO, @"Cannot find one handler for notification: %@.", pushData);
}

- (void)shPGHtmlReceiver:(id<ISHPhonegapObserver>)phonegapObserver
{
    //Not check ![SHAppStatus sharedInstance].streethawkEnabled, this is used for Phonegap.
    NSAssert(phonegapObserver != nil, @"Phonegap observer is nil");
    if (phonegapObserver != nil)
    {
        if (![self.arrayPGObservers containsObject:phonegapObserver])
        {
            [self.arrayPGObservers addObject:phonegapObserver];
        }
    }
}

- (NSString *)shGetViewName
{
    //Not check ![SHAppStatus sharedInstance].streethawkEnabled, this is used for Phonegap.
    NSString *storedView = [[NSUserDefaults standardUserDefaults] objectForKey:PHONEGAP_8004_PAGE];
    if (storedView != nil && storedView.length > 0)
    {
        NSDictionary *dictPushData = [[NSUserDefaults standardUserDefaults] objectForKey:PHONEGAP_8004_PUSHDATA];
        if (dictPushData != nil && [dictPushData isKindOfClass:[NSDictionary class]])
        {
            PushDataForApplication *pushData = [PushDataForApplication fromDictionary:dictPushData];
            [pushData sendPushResult:SHResult_Accept withHandler:nil];
        }
        //clear local stored views to avoid next launch
        [[NSUserDefaults standardUserDefaults] setObject:@"" forKey:PHONEGAP_8004_PAGE];
        [[NSUserDefaults standardUserDefaults] setObject:@"" forKey:PHONEGAP_8004_PUSHDATA];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    return storedView;
}

- (void)shPGLoadHtml:(NSString *)htmlFile
{
    //Not check ![SHAppStatus sharedInstance].streethawkEnabled, this is used for Phonegap.
    for (id<ISHPhonegapObserver> observer in self.arrayPGObservers)
    {
        [observer shPGDisplayHtmlFileName:htmlFile];
    }
}

@end
