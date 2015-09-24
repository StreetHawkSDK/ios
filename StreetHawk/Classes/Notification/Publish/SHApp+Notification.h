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
#import "ISHCustomiseHandler.h" //for protocol
#import "ISHPhonegapObserver.h" //for protocol

@class SHNotificationHandler;

/**
 Extension for Notification API.
 */
@interface SHApp (NotificationExt)

/**
 Default value to initialise `isNotificationEnabled`, it's called once when App first launch to set to `isNotificationEnabled`. A typical usage is to delay asking for notification permission:
 
 `StreetHawk.isDefaultNotificationEnabled = NO; //not trigger remote/local notification when App launch.`
 `[registerInstallForApp... ];   //do register, it will not register notification.`
 `StreetHawk.isNotificationEnabled = YES; //later trigger remote/local notification when need it.`
 */
@property (nonatomic) BOOL isDefaultNotificationEnabled;

/**
 Property to control enabling remote/local notification.
 
 1. If user set `isDefaultNotificationEnabled = NO` before calling `registerInstallForApp...`, notification is not register and system permission dialog not promote.
 2. Call `registerInstallForApp... `, it will not register notification.
 3. Later when user wants to do register, set `isNotificationEnabled = YES` and system permission dialog promote.
 4. Step 1 is optional. If not manually set `isDefaultNotificationEnabled = NO`, it's YES by default and system permission dialog show when `registerInstallForApp` called at very first launch.
 5. Set `isNotificationEnabled = NO` again after `isNotificationEnabled = YES` makes StreetHawk server receive `revoked`, and cause StreetHawk server not send notification to client. But it does not call system unregisterForRemoteNotification, so this App can still receive remote notification from other way.
 */
@property (nonatomic) BOOL isNotificationEnabled;

/**
 Property to define what kind of types will display for notification.
 
 * Before iOS 8, it's combine of UIRemoteNotificationType, default value is UIRemoteNotificationTypeAlert|UIRemoteNotificationTypeBadge|UIRemoteNotificationTypeSound|UIRemoteNotificationTypeNewsstandContentAvailability.
 * Since iOS 8, it's combine of UIUserNotificationType, default value is UIUserNotificationTypeAlert|UIUserNotificationTypeBadge|UIUserNotificationTypeSound.
 
 Customer is free to change the types, and make sure setting up this property before registering for remote notification, such as before calling [registerForInstall...].
 */
@property (nonatomic) NSUInteger notificationTypes;

/**
 Property for customer to add their own interactive notification. It's same as iOS 8 defined categories set. Code snippet:
 
 // Define an action for the category
 UIMutableUserNotificationAction *action = [[UIMutableUserNotificationAction alloc] init];
 action.destructive = NO;
 action.activationMode = UIUserNotificationActivationModeForeground;
 action.authenticationRequired = YES;
 action.title = @"Action!";
 action.identifier = @"custom_action";
 // Define the category
 UIMutableUserNotificationCategory *category = [[UIMutableUserNotificationCategory alloc] init];
 [category setActions:@[action] forContext:UIUserNotificationActionContextMinimal];
 [category setActions:@[action] forContext:UIUserNotificationActionContextDefault];
 category.identifier = @"custom_category";
 // Set the custom categories
 StreetHawk.notificationCategories = [NSSet setWithArray:@[category]];
 
 Customer is free to add their own categories, make sure categories' `identifier` is not same as StreetHawk's pre-defined code such as 8000, 8004 etc. In case customer's category uses same `identifier` as StreetHawk's predefined code, StreetHawk's function will be override. Customer's categories, combined with StreetHawk's predefined categories, work side by side. Customer needs to handle their own category by their own code, usually needs to implement their own AppDelegate functions, check document http://api.streethawk.com/v1/docs/ios-manualsetup.html#ios-manualsetup. Make sure setting up this property before registering for remote notification, such as before calling [registerForInstall...].
 */
@property (nonatomic, strong) NSSet *notificationCategories NS_AVAILABLE_IOS(8_0);

/**
 Handler for notification stuff.
 */
@property (nonatomic, strong) SHNotificationHandler *notificationHandler;

/**
 According to system and customer code's setting, call system API to register notification <both for remote notification and local notification> or update revoked.
 
 * Call system API to register notification unless `StreetHawk.isEnableNotification=NO`.
 * Check system enable notification or `StreetHawk.isEnableNotification=NO` to update flag `revoked` in StreetHawk server. This flag can stop StreetHawk server from sending remote notification.
 */
-(void)registerForNotificationAndNotifyServer;

/**
 Handle user notification settings callback. Call this in customer App's UIApplicationDelegate if NOT auto-integrate. If `StreetHawk.autoIntegrateAppDelegate = YES;` make sure NOT call this otherwise cause dead loop. Code snippet:
 
 `- (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings`
 `{`
 `[StreetHawk handleUserNotificationSettings:notificationSettings];`
 `}`
 */
- (void)handleUserNotificationSettings:(UIUserNotificationSettings *)settings NS_AVAILABLE_IOS(8_0);

/**
 Set StreetHawk SDK the token assigned by Apple for push notification. Previous device token is cached in NSUserDefaults key "APNS_DEVICE_TOKEN". If current data is nil, it's ignored and previous used. When setting a different device token, an install update sent immediately for updating server's token. Call this in customer App's UIApplicationDelegate if NOT auto-integrate. If `StreetHawk.autoIntegrateAppDelegate = YES;` make sure NOT call this otherwise cause dead loop. Code snippet:
 
 `-(void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken`
 `{`
 `[StreetHawk setApnsDeviceToken:deviceToken];`
 `}`
 
 @param value Device token got from Apple's register remote notification.
 */
- (void)setApnsDeviceToken:(NSData *)value;

/**
 Get current saved apns device token as NSString.
 */
- (NSString *)apnsDeviceToken;

/**
 Customer Application should implement this in UIApplicationDelegate to forward handling to StreetHawk library if NOT auto-integrate. If `StreetHawk.autoIntegrateAppDelegate = YES;` make sure NOT call this otherwise cause dead loop. Code snippet:
 
 `-(void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
 {
 [StreetHawk handleRemoteNotification:userInfo needComplete:YES fetchCompletionHandler:nil];
 }`
 
 or
 
 `-(void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
 {
 [StreetHawk handleRemoteNotification:userInfo needComplete:YES fetchCompletionHandler:completionHandler];
 }`
 
 @param userInfo Payload passed in by remote notification.
 @param appFGBG The App in FG or BG when notification arrives. If not sure put unknown.
 @param needComplete Whether need to call `completionHandler` when task finish. If `completionHandler`=nil this does not matter YES or NO.
 @param completionHandler Pass in system's to finish when task is done.
 */
- (void)handleRemoteNotification:(NSDictionary *)userInfo treatAppAs:(SHAppFGBG)appFGBG needComplete:(BOOL)needComplete fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler;

/**
 Customer Application should implement this in UIApplicationDelegate to forward handling to StreetHawk library if NOT auto-integrate. If `StreetHawk.autoIntegrateAppDelegate = YES;` make sure NOT call this otherwise cause dead loop. Code snippet:
 
 `- (void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo completionHandler:(void (^)())completionHandler
 {
 [StreetHawk handleRemoteNotification:userInfo withActionId:identifier needComplete:YES completionHandler:completionHandler];
 }`
 
 @param userInfo Payload passed in by remote notification.
 @param identifier Action button's identifier.
 @param needComplete Whether need to call `completionHandler` when task finish. If `completionHandler`=nil this does not matter YES or NO.
 @param completionHandler Pass in system's to finish when task is done.
 */
- (void)handleRemoteNotification:(NSDictionary *)userInfo withActionId:(NSString *)identifier needComplete:(BOOL)needComplete completionHandler:(void (^)())completionHandler NS_AVAILABLE_IOS(8_0);

/**
 Customer Application should implement this in UIApplicationDelegate to forward handling to StreetHawk library if NOT auto-integrate. If `StreetHawk.autoIntegrateAppDelegate = YES;` make sure NOT call this otherwise cause dead loop. Code snippet:
 
 `- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification`
 {
 [StreetHawk handleLocalNotification:notification needComplete:YES fetchCompletionHandler:nil];
 }`
 
 @param notification Object passed in by local notification.
 @param appFGBG The App in FG or BG when notification arrives. If not sure put unknown.
 @param needComplete Whether need to call `completionHandler` when task finish. If `completionHandler`=nil this does not matter YES or NO.
 @param completionHandler Pass in system's to finish when task is done.
 */
- (void)handleLocalNotification:(UILocalNotification *)notification treatAppAs:(SHAppFGBG)appFGBG needComplete:(BOOL)needComplete fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler;

/**
 Customer Application should implement this in UIApplicationDelegate to forward handling to StreetHawk library if NOT auto-integrate. If `StreetHawk.autoIntegrateAppDelegate = YES;` make sure NOT call this otherwise cause dead loop. Code snippet:
 
 `- (void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forLocalNotification:(UILocalNotification *)notification completionHandler:(void (^)())completionHandler
 {
 [StreetHawk handleLocalNotification:notification withActionId:identifier needComplete:YES completionHandler:completionHandler];
 }`
 
 @param notification Object passed in by local notification.
 @param identifier Action button's identifier.
 @param needComplete Whether need to call `completionHandler` when task finish. If `completionHandler`=nil this does not matter YES or NO.
 @param completionHandler Pass in system's to finish when task is done.
 */
- (void)handleLocalNotification:(UILocalNotification *)notification withActionId:(NSString *)identifier needComplete:(BOOL)needComplete completionHandler:(void (^)())completionHandler NS_AVAILABLE_IOS(8_0);

/**
 Set badge number on Application icon. In iOS 8 it needs to check permission, if not have permission return NO.
 @param badgeNumber Number shown on App icon.
 @return If set successfully return YES, else return NO in case no permission.
 */
- (BOOL)setApplicationBadge:(NSInteger)badgeNumber;

/**
 If set pause_minutes >= StreetHawk_AlertSettings_Forever, it treats as pause forever.
 */
#define SHAlertSettings_Forever 129600     //3 month

/**
 Set alert settings times measured by minutes.
 @param pauseMinutes Minute measured pause time. If `pauseMinutes` <= 0 means not pause, if `pauseMinutes` >= `StreetHawk_AlertSettings_Forever` means pause forever.
 @param handler Callback for finish.
 */
- (void)shSetAlertSetting:(NSInteger)pauseMinutes finish:(SHCallbackHandler)handler;

/**
 Get alert settings times measured by minutes.
 @return Integer value, measured in minutes. If `return` <= 0 means not pause, if `return` >= `StreetHawk_AlertSettings_Forever` means pause forever.
 */
- (NSInteger)getAlertSettingMinutes;

/**
 Client setup minutes pass to server. Server will calculate pause time according to it. `pause_until` is calculated by current time and `pause_minutes`. For example if current time is 8:00 and set `pause_minutes` = 60 (1 hour), `pause_until` will be 9:00. Later when time pass and now is 8:30, `pause_minutes` is still 60, but must relay on `pause_until`(9:00) to know the stop time, cannot use current time + `pause_minutes`.
 
 * `pause_minutes` is minute value.
 * If set `pause_minutes` >= `SH_AlertSettings_Forever`, it treats as pause forever.
 * If set `pause_minutes` <= 0, it treats as not paused.
 
 @handler Need to read from server, use this asynchronous callback. It's (NSDate* pauseUntil, NSError *error). If never set, return ([NSDate date], nil).
 */
- (void)getAlertSettingPauseUntil:(SHCallbackHandler)handler;

/**
 Array for hosting customised handler.
 */
@property (nonatomic, strong) NSMutableArray *arrayCustomisedHandler;

/**
 Register handler for customised tasks.
 @param handler Instance class of `ISHCustomiseHandler` to let customer implement their own code.
 */
- (void)shSetCustomiseHandler:(id<ISHCustomiseHandler>)handler;

/**
 Go through register `ISHCustomiseHandler` until find one which can handle this notitication.
 @param pushData Payload from this notification.
 @param handler Callback with result.
 */
- (void)handlePushDataForAppCallback:(PushDataForApplication *)pushData clickButton:(ClickButtonHandler)handler;

/**
 Register observer for phonegap App to load html page when receive 8004 push notification.
 @param phonegapObserver Instance class of `ISHPhonegapObserver` to load html on customer's phonegap web view.
 */
- (void)shPGHtmlReceiver:(id<ISHPhonegapObserver>)phonegapObserver;

/**
 Array for hosting PG observers. Set it by `- (void)shPGHtmlReceiver:(id<ISHPhonegapObserver>)phonegapObserver`.
 */
@property (nonatomic, strong) NSMutableArray *arrayPGObservers;

/**
 Get stored view name for push 8004, this is used for App launches and check whether a 8004 push notification occured. If this App is waken up by 8004 push notification, the view name is stored locally and read by this function, so that App knows a specific page should be loaded.
 @return Locally stored view name when 8004 comes. It's read only once, after read local cache is cleared.
 */
- (NSString *)shGetViewName;

/**
 Trigger phonegap observer to load html page. This is used for 8004 notification which can map friendly name to html file name.
 @param htmlFile The html page register by `shCustomActivityList`.
 */
- (void)shPGLoadHtml:(NSString *)htmlFile;

/**
 Does user disable notification permission for this App in system preference settings App. It's used to check before promote settings dialog by calling `- (void)launchSystemPreferenceSettings` to let user reset location since iOS 8, or before iOS 8 needs to show self made instruction. Return YES if notification is disabled or no type is enabled.
 */
@property (nonatomic, readonly) BOOL systemPreferenceDisableNotification;

@end
