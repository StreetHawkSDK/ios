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
#import "SHTypes.h"

/**
 Enum for actions.
 */
enum SHAction
{
    SHAction_OpenUrl = 1,
    SHAction_LaunchActivity = 2,
    SHAction_RateApp = 3,
    SHAction_UserRegistrationScreen = 4,
    SHAction_UserLoginScreen = 5,
    SHAction_UpdateApp = 6,
    SHAction_CallTelephone = 7,
    SHAction_SimplePrompt = 8,
    SHAction_Feedback = 9,
    SHAction_EnableBluetooth = 10,
    SHAction_EnablePushMsg = 11,
    SHAction_EnableLocation = 12,
    SHAction_CheckAppStatus,
    SHAction_CustomJson,
    SHAction_Undefined,
};
typedef enum SHAction SHAction;

/**
 Enum for result.
 */
enum SHResult
{
    /**
     Result when click positive button such as "Agree", "Yes Please".
     */
    SHResult_Accept = 1,
    /**
     Result when click neutral button such as "Later", "Not now".
     */
    SHResult_Postpone = 0,
    /**
     Result when click negative button such as "Never", "Cancel".
     */
    SHResult_Decline = -1,
};
typedef enum SHResult SHResult;

/**
 The directions of how slide show.
 */
enum SHSlideDirection
{
    /**
     Move from device's bottom to up.
     */
    SHSlideDirection_Up = 0,
    /**
     Move from device's top to down.
     */
    SHSlideDirection_Down = 1,
    /**
     Move from device's right to left.
     */
    SHSlideDirection_Left = 2,
    /**
     Move from device's left to right.
     */
    SHSlideDirection_Right = 3,
};
typedef enum SHSlideDirection SHSlideDirection;

/**
 An enum to treat App in FG or BG. Normally uses `SHAppFGBG_Unknown` to let App decide by `[UIApplication sharedApplication].applicationState`, however Titanium always return `UIApplicationStateActive`, and instead imlement FG or BG by its own payload, so extent API to be able to decide FG or BG.
 */
enum SHAppFGBG
{
    SHAppFGBG_Unknown,
    SHAppFGBG_FG,
    SHAppFGBG_BG,
};
typedef enum SHAppFGBG SHAppFGBG;

/**
 Object which contains information from notification.
 */
@interface PushDataForApplication : NSObject

/**
 The title of this notification, usually used for title in UIAlertView.
 */
@property (nonatomic, strong) NSString *title;

/**
 The message of this notification, usually used for detail message in UIAlertView.
 */
@property (nonatomic, strong) NSString *message;

/**
 A flag to indicate not show confirm dialog.
 */
@property (nonatomic) BOOL displayWithoutDialog;

/**
 The data of this notification, it's different according to different push, for example it's url for SHAction_OpenUrl, it's telephone number for SHAction_CallTelephone.
 */
@property (nonatomic, strong) NSObject *data;

/**
 The action of this notification.
 */
@property (nonatomic, readonly) SHAction action;

/**
 StreetHawk system defined code, used internally.
 */
@property (nonatomic) NSInteger code;

/**
 When the notification arrives, whether App on foreground or background. 
 */
@property (nonatomic) BOOL isAppOnForeground;

/**
 The msg id from server inside this notification, used internally.
 */
@property (nonatomic) NSInteger msgID;

/**
 A flag indicate whether this notification is for slide.
 */
@property (nonatomic) BOOL isInAppSlide;

/**
 Used for SHAction_OpenUrl to slide web page inside App. This indicates how many percentage screen should be covered by web page.
 */
@property (nonatomic) float portion;

/**
 Used for SHAction_OpenUrl to slide web page inside App. This indicates the direction where web page slide in.
 */
@property (nonatomic) SHSlideDirection orientation;

/**
 Used for SHAction_OpenUrl to slide web page inside App. This indicates how many seconds the animation takes.
 */
@property (nonatomic) float speed;

/**
 The sound file name in notification payload. Normally no need to handle this in iOS, system play the sound automatically when notification arrives.
 */
@property (nonatomic, strong) NSString *sound;

/**
 The badge number in notification payload. Normally no need to handle this in iOS, system set badge in App icon automatically when notification arrives.
 */
@property (nonatomic) NSInteger badge;

/**
 Send result logline to StreetHawk server. It's used in case customer develop their own action handler instead of using `handler` to continue StreetHawk action. If use `handler`, no need to call this again as it's handled by StreetHawk SDK automatically.
 @param result User decided result.
 @param handler Request done handler.
 */
- (void)sendPushResult:(SHResult)result withHandler:(SHCallbackHandler)handler;

/**
 Customise whether need to show confirm dialog for this notification. For example, if title and message are empty, there is nothing to show; if displayWithoutDialog = YES, dialog may not show; if App wake from BG, dialog may not show.
 @return Whether need to show confirm dialog.
 */
- (BOOL)shouldShowConfirmDialog;

/**
 Serialize to a dictionary object.
 @return The serialized dictionary.
 */
- (NSDictionary *)toDictionary;

/**
 Create instance from dictionary.
 @param dict The dictionary which contains instance value.
 @return The object.
 */
+ (PushDataForApplication *)fromDictionary:(NSDictionary *)dict;

@end
