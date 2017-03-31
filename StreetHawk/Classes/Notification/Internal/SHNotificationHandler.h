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

#import <UIKit/UIKit.h>
#import "PushDataForApplication.h" //for enum SHAppFGBG

#define PHONEGAP_8004_PAGE                  @"PHONEGAP_8004_PAGE"  //when Phonegap receive 8004 at background and launch, store this and it will read by [StreetHawk shGetViewName] when launch
#define PHONEGAP_8004_PUSHDATA              @"PHONEGAP_8004_PUSHDATA" //together with PHONEGAP_8004_PAGE.

/**
 An enum for notification action. Since iOS 8 user can directly reply on notification, and here is the pre-defined action.
 */
enum SHNotificationActionResult
{
    SHNotificationActionResult_Unknown = 0,
    SHNotificationActionResult_Yes = 1,
    SHNotificationActionResult_NO = 2,
    SHNotificationActionResult_Later = 3,
};
typedef enum SHNotificationActionResult SHNotificationActionResult;

/**
 An enum for what kind of notification is triggered.
 */
enum SHNotificationType
{
    SHNotificationType_Remote,
    SHNotificationType_Local,
    SHNotificationType_SmartPush,
};
typedef enum SHNotificationType SHNotificationType;

/**
 StreetHawk notification handler for dealing with remote or local notifications.
 */
@interface SHNotificationHandler : NSObject

/**
 Check whether this push is from StreetHawk's defined code. If yes process StreetHawk's handling, if no should just return.
 */
- (BOOL)isDefinedCode:(NSDictionary *)userInfo;

/**
 This method is called to filter `code`. A StreetHawk style remote notification must have positive int value `code`, if not this method will return without any effect. After filter `code`, it calls `- (BOOL)handleDefinedCode:(int)code userInfo:(NSDictionary *)userInfo withAction:(SHNotificationAction)action treatAppAs:(SHAppFGBG)appFGBG` to perform action.
 
 @param userInfo Server remote notification payload, or local notification payload by response.
 @param action If response on notification directly here is the answer, at this time App state is inactive.
 @param appFGBG Treat this remote notification handled as FG or BG.
 @param notificationType An enum type indicate it's from remote notification or local notification.
 @return YES if this notification is handleable by StreetHawk SDK; NO if it's not recognizable or not as expected as StreetHawk SDK.
 */
- (BOOL)handleDefinedUserInfo:(NSDictionary *)userInfo withAction:(SHNotificationActionResult)action treatAppAs:(SHAppFGBG)appFGBG forNotificationType:(SHNotificationType)notificationType;

@end
