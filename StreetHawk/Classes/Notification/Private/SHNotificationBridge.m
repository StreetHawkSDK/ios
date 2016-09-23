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

#import "SHNotificationBridge.h"
//header from StreetHawk
#import "SHApp+Notification.h" //for SHApp extension
#import "SHPushDataCallback.h" //for create instance
#import "SHNotificationHandler.h" //for create instance
#import "SHHTTPSessionManager.h" //for SMART_PUSH_PAYLOAD definition
//header from System
#import <UserNotifications/UserNotifications.h>  //for notification since iOS 10

@interface SHNotificationBridge ()

+ (void)setBadgeHandler:(NSNotification *)notification;  //Set Application badge. notification name: SH_PushBridge_SetBadge_Notification; user info: @{badge, <int_number>}.
+ (void)registerNotificationHandler:(NSNotification *)notification; //Register for Apple's notification. notification name: SH_PushBridge_Register_Notification; user info: empty.
+ (void)setInteractivePairButtonsNotificationHandler:(NSNotification *)notification; //Set and submit predefined interactive pair buttons. notification name: SH_PushBridge_SetInteractivePairButtons_Notification; user info: empty.
+ (void)smartPushHandler:(NSNotification *)notification; //for handle smart push. notification name: SH_PushBridge_Smart_Notification; user info: empty.
+ (void)didRegisterUserNotificationHandler:(NSNotification *)notification; //for handle system delegate `- (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings`. notification name: SH_PushBridge_DidRegisterUserNotification; user info: @{notificationSettings: <value>}.
+ (void)didReceiveDeviceTokenHandler:(NSNotification *)notification; //for handle system delegate `- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken`. notification name: SH_PushBridge_ReceiveToken_Notification; user info: @{token: <NSData_token>}.
+ (void)receiveRemoteNotificationHandler:(NSNotification *)notification; //for handle system delegate `- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler`. notification name: SH_PushBridge_ReceiveRemoteNotification; user info: @{@"payload": userInfo, @"fgbg": @(SHAppFGBG_Unknown), @"needComplete": @(!customerAppResponse), @"fetchCompletionHandler": completionHandler}.
+ (void)handleRemoteNotificationActionHandler:(NSNotification *)notification; //for handle system delegate `- (void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo completionHandler:(void (^)())completionHandler`. notification name: SH_PushBridge_HandleRemoteActionButton; user info: @{@"payload": userInfo, @"actionid": identifier, @"needComplete": <bool>, @"completionHandler": completionHandler}.
+ (void)receiveLocalNotificationHandler:(NSNotification *)notification; //for handle system delegate `- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification`. notification name: SH_PushBridge_ReceiveLocalNotification; user info: @{@"notification": notification, @"fgbg": @(SHAppFGBG_Unknown), @"needComplete": @(YES)}.
+ (void)handleLocalNotificationActionHandler:(NSNotification *)notification; //for handle system delegate `- (void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forLocalNotification:(UILocalNotification *)notification completionHandler:(void (^)())completionHandler`. notification name: SH_PushBridge_HandleLocalActionButton; user info: @{@"notification": notification, @"actionid": identifier, @"needComplete": <bool>, @"completionHandler": completionHandler}.
+ (void)sendPushResultHandler:(NSNotification *)notification; //for using register callback to send push result. notification name: @"SH_PushBridge_SendResult_Notification"; user info: @{@"pushdata": self, @"result": @(result)};
+ (void)handlePushDataHandler:(NSNotification *)notification; //for handle push data. notification name: SH_PushBridge_HandlePushData; user info: @{@"pushdata": self, @"clickbutton": clickbuttonhandler}.

@end

@implementation SHNotificationBridge

#pragma mark - public

+ (void)bridgeHandler:(NSNotification *)notification
{
    //initialise variables, move from SHApp's init.
    StreetHawk.isDefaultNotificationEnabled = YES;  //default value, user can change it by StreetHawk.isDefaultNotificationEnabled = NO. Default value only used to initialize isNotificationEnabled one time, once user manually set StreetHawk.isNotificationEnabled, default value is ignored.
    StreetHawk.notificationTypes = UNAuthorizationOptionAlert | UNAuthorizationOptionBadge | UNAuthorizationOptionSound;
    StreetHawk.arrayCustomisedHandler = [NSMutableArray array];
    [StreetHawk shSetCustomiseHandler:[[SHPushDataCallback alloc] init]]; //streethawk's add first, so customer's will insert before it.
    StreetHawk.arrayPGObservers = [NSMutableArray array];
    StreetHawk.notificationHandler = [[SHNotificationHandler alloc] init]; //Phonegap do streethawkinit() later, but need notification handler to available to process 8004 set view name at first time.
    
    //further handler
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setBadgeHandler:) name:@"SH_PushBridge_SetBadge_Notification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(registerNotificationHandler:) name:SHInstallRegistrationSuccessNotification object:nil]; //first registerForRemoteNotification need be called after register install, because it needs to be updated to an install id.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(registerNotificationHandler:) name:@"SH_PushBridge_Register_Notification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setInteractivePairButtonsNotificationHandler:) name:@"SH_PushBridge_SetInteractivePairButtons_Notification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(smartPushHandler:) name:@"SH_PushBridge_Smart_Notification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didRegisterUserNotificationHandler:) name:@"SH_PushBridge_DidRegisterUserNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveDeviceTokenHandler:) name:@"SH_PushBridge_ReceiveToken_Notification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveRemoteNotificationHandler:) name:@"SH_PushBridge_ReceiveRemoteNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleRemoteNotificationActionHandler:) name:@"SH_PushBridge_HandleRemoteActionButton" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveLocalNotificationHandler:) name:@"SH_PushBridge_ReceiveLocalNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleLocalNotificationActionHandler:) name:@"SH_PushBridge_HandleLocalActionButton" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sendPushResultHandler:) name:@"SH_PushBridge_SendResult_Notification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handlePushDataHandler:) name:@"SH_PushBridge_HandlePushData" object:nil];
    //Post a notification to notify push module is ready. This is used in Titanium for adding customise handler and phonegap observer.
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PushModule_Ready" object:nil];
}

#pragma mark - private

+ (void)setBadgeHandler:(NSNotification *)notification
{
    [StreetHawk setApplicationBadge:[notification.userInfo[@"badge"] integerValue]];
}

+ (void)registerNotificationHandler:(NSNotification *)notification
{
    [StreetHawk registerForNotificationAndNotifyServer];
}

+ (void)setInteractivePairButtonsNotificationHandler:(NSNotification *)notification
{
    //This should only happen once to submit out-of-box pair buttons. It should not call again otherwise customer's pair button will be override, controlled by app_status/submit_interactive_button.
    [StreetHawk setInteractivePushBtnPairs:nil];
}

+ (void)smartPushHandler:(NSNotification *)notification
{
    NSObject *smartpushObj = [[NSUserDefaults standardUserDefaults] objectForKey:SMART_PUSH_PAYLOAD];
    if (smartpushObj != nil && [smartpushObj isKindOfClass:[NSDictionary class]])
    {
        [[NSUserDefaults standardUserDefaults] setObject:@"" forKey:SMART_PUSH_PAYLOAD]; //clear, not launch next time.
        [[NSUserDefaults standardUserDefaults] synchronize];
        NSDictionary *payload = (NSDictionary *)smartpushObj;
        if ([StreetHawk.notificationHandler isDefinedCode:payload])
        {
            [StreetHawk.notificationHandler handleDefinedUserInfo:payload withAction:SHNotificationActionResult_Unknown treatAppAs:SHAppFGBG_FG forNotificationType:SHNotificationType_SmartPush];
        }
    }
}

+ (void)didRegisterUserNotificationHandler:(NSNotification *)notification
{
    UIUserNotificationSettings *notificationSettings = notification.userInfo[@"notificationSettings"];
    NSAssert(notificationSettings != nil, @"\"notificationSettings\" in didRegisterUserNotificationHandler should not be nil.");
    [StreetHawk handleUserNotificationSettings:notificationSettings];
}

+ (void)didReceiveDeviceTokenHandler:(NSNotification *)notification
{
    NSData *deviceToken = notification.userInfo[@"token"];
    NSAssert(deviceToken != nil, @"\"deviceToken\" in didReceiveDeviceTokenHandler should not be nil.");
    [StreetHawk setApnsDeviceToken:deviceToken];
}

+ (void)receiveRemoteNotificationHandler:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo[@"payload"];
    NSAssert(userInfo != nil, @"\"userInfo\" in receiveRemoteNotificationHandler should not be nil.");
    SHAppFGBG fgbg = [notification.userInfo[@"fgbg"] intValue];
    BOOL needComplete = [notification.userInfo[@"needComplete"] boolValue];
    [StreetHawk handleRemoteNotification:userInfo treatAppAs:fgbg needComplete:needComplete fetchCompletionHandler:notification.userInfo[@"fetchCompletionHandler"]];
}

+ (void)handleRemoteNotificationActionHandler:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo[@"payload"];
    NSAssert(userInfo != nil, @"\"userInfo\" in handleRemoteNotificationActionHandler should not be nil.");
    NSString *actionIdentifier = notification.userInfo[@"actionid"];
    NSAssert(actionIdentifier != nil, @"\"actionIdentifier\" in handleRemoteNotificationActionHandler should not be nil.");
    BOOL needComplete = [notification.userInfo[@"needComplete"] boolValue];
    [StreetHawk handleRemoteNotification:userInfo withActionId:actionIdentifier needComplete:needComplete completionHandler:notification.userInfo[@"completionHandler"]];
}

+ (void)receiveLocalNotificationHandler:(NSNotification *)notification
{
    UILocalNotification *localNotification = notification.userInfo[@"notification"];
    NSAssert(localNotification != nil, @"\"localNotification\" in receiveLocalNotificationHandler should not be nil.");
    SHAppFGBG fgbg = [notification.userInfo[@"fgbg"] intValue];
    BOOL needComplete = [notification.userInfo[@"needComplete"] boolValue];
    [StreetHawk handleLocalNotification:localNotification treatAppAs:fgbg needComplete:needComplete fetchCompletionHandler:nil];
}

+ (void)handleLocalNotificationActionHandler:(NSNotification *)notification
{
    UILocalNotification *localNotification = notification.userInfo[@"notification"];
    NSAssert(localNotification != nil, @"\"localNotification\" in handleLocalNotificationActionHandler should not be nil.");
    NSString *actionIdentifier = notification.userInfo[@"actionid"];
    NSAssert(actionIdentifier != nil, @"\"actionIdentifier\" in handleLocalNotificationActionHandler should not be nil.");
    BOOL needComplete = [notification.userInfo[@"needComplete"] boolValue];
    [StreetHawk handleLocalNotification:localNotification withActionId:actionIdentifier needComplete:needComplete completionHandler:notification.userInfo[@"completionHandler"]];
}

+ (void)sendPushResultHandler:(NSNotification *)notification
{
    PushDataForApplication *pushData = notification.userInfo[@"pushdata"];
    NSAssert(pushData != nil, @"\"pushData\" in sendPushResultHandler should not be nil.");
    SHResult result = [notification.userInfo[@"result"] intValue];
    for (id<ISHCustomiseHandler> callback in StreetHawk.arrayCustomisedHandler)
    {
        if ([callback respondsToSelector:@selector(onReceiveResult:withResult:)]) //implementation is optional
        {
            [callback onReceiveResult:pushData withResult:result];
        }
    }
}

+ (void)handlePushDataHandler:(NSNotification *)notification
{
    PushDataForApplication *pushData = notification.userInfo[@"pushdata"];
    NSAssert(pushData != nil, @"\"pushData\" in handlePushDataHandler should not be nil.");
    ClickButtonHandler handler = notification.userInfo[@"clickbutton"];
    [StreetHawk handlePushDataForAppCallback:pushData clickButton:handler];
}

@end
