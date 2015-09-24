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

#import "PushDataForApplication.h"
//header from StreetHawk
#import "SHLogger.h" //for LOG_RESULT
#import "SHUtils.h" //for shStrIsEmpty
#ifdef SH_FEATURE_NOTIFICATION
#import "SHApp+Notification.h" //for ISHCustomiseHandler
#endif

@implementation PushDataForApplication

- (id)init
{
    if (self = [super init])
    {
        self.title = nil;
        self.message = nil;
        self.displayWithoutDialog = NO;
        self.data = nil;
        _action = SHAction_Undefined;
        _code = 0; //cannot use property, otherwise it triggers set action and cause assert.
        self.isAppOnForeground = YES;
        self.msgID = 0;
        self.isInAppSlide = NO;
        self.portion = 0;
        self.orientation = SHSlideDirection_Up;
        self.speed = 0;
        self.sound = nil;
        self.badge = 0;
    }
    return self;
}

#pragma mark - properties

- (void)setCode:(NSInteger)code
{
    _code = code;
    if (code == 8000)
    {
        _action = SHAction_OpenUrl;
    }
    else if (code == 8003)
    {
        _action = SHAction_CheckAppStatus;
    }
    else if (code == 8004)
    {
        _action = SHAction_LaunchActivity;
    }
    else if (code == 8005)
    {
        _action = SHAction_RateApp;
    }
    else if (code == 8006)
    {
        _action = SHAction_UserRegistrationScreen;
    }
    else if (code == 8007)
    {
        _action = SHAction_UserLoginScreen;
    }
    else if (code == 8008)
    {
        _action = SHAction_UpdateApp;
    }
    else if (code == 8009)
    {
        _action = SHAction_CallTelephone;
    }
    else if (code == 8010)
    {
        _action = SHAction_SimplePrompt;
    }
    else if (code == 8011)
    {
        _action = SHAction_Feedback;
    }
    else if (code == 8012)
    {
        _action = SHAction_EnableBluetooth;
    }
    else if (code == 8049)
    {
        _action = SHAction_CustomJson;
    }
    else
    {
        NSAssert(NO, @"Unknown code, cannot match to action.");
    }
}

#pragma mark - public functions

- (NSString *)description
{
    NSMutableString *displayStr = [NSMutableString string];
    [displayStr appendFormat:@"Title: %@\n", self.title];
    [displayStr appendFormat:@"Message: %@\n", self.message];
    [displayStr appendFormat:@"Display without dialog: %@\n", self.displayWithoutDialog ? @"Yes" : @"No"];
    [displayStr appendFormat:@"Data: %@\n", self.data];
    [displayStr appendFormat:@"Code: %ld\n", (long)self.code];
    [displayStr appendFormat:@"MsgId: %ld\n", (long)self.msgID];
    [displayStr appendFormat:@"Portion: %f\n", self.portion];
    [displayStr appendFormat:@"Orientation: %u\n", self.orientation];
    [displayStr appendFormat:@"Speed: %f\n", self.speed];
    [displayStr appendFormat:@"Sound: %@\n", self.sound];
    [displayStr appendFormat:@"Badge: %ld\n", (long)self.badge];
    return displayStr;
}

- (void)sendPushResult:(SHResult)result withHandler:(SHCallbackHandler)handler
{
    NSAssert(self.msgID != 0, @"Notification %@ without msg id.", self);
    NSAssert(self.code != 0, @"Notification %@ without code.", self);
    if (self.msgID != 0 && self.code != 0)
    {
        int logResult;
        switch (result)
        {
            case SHResult_Accept:
                logResult = LOG_RESULT_ACCEPT;
                break;
            case SHResult_Postpone:
                logResult = LOG_RESULT_LATER;
                break;
            case SHResult_Decline:
                logResult = LOG_RESULT_CANCEL;
                break;
            default:
                NSAssert(NO, @"Unexpected push result.");
                break;
        }
        [StreetHawk sendLogForCode:LOG_CODE_PUSH_RESULT withComment:[NSString stringWithFormat:@"%ld", (long)self.code] forAssocId:self.msgID withResult:logResult withHandler:handler];
        //invoke custom handler
#ifdef SH_FEATURE_NOTIFICATION
        for (id<ISHCustomiseHandler> callback in StreetHawk.arrayCustomisedHandler)
        {
            if ([callback respondsToSelector:@selector(onReceiveResult:withResult:)]) //implementation is optional
            {
                [callback onReceiveResult:self withResult:result];
            }
        }
#endif
    }
}

- (BOOL)shouldShowConfirmDialog
{
    if (self.displayWithoutDialog)
    {
        return NO;
    }
    if (shStrIsEmpty(self.title) && shStrIsEmpty(self.message)) //nothing to show
    {
        return NO;
    }
    if (!self.isAppOnForeground) //If wake App from background by notification, not show confirm dialog to avoid user click twice.
    {
        return NO;
    }
    if (self.action == SHAction_RateApp && (![self.data isKindOfClass:[NSString class]] || shStrIsEmpty((NSString *)self.data)) && shStrIsEmpty(StreetHawk.itunesAppId)) //push is rate but not send iTunes Id, and StreetHawk.itunesAppId is also empty. In notification handler also check iTunesId is number but here do simpler.
    {
        return NO;
    }
    return YES;
}

- (NSDictionary *)toDictionary
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    if (self.title != nil)
    {
        [dict setValue:self.title forKey:@"title"];
    }
    if (self.message != nil)
    {
        [dict setValue:self.message forKey:@"message"];
    }
    [dict setValue:[NSNumber numberWithBool:self.displayWithoutDialog] forKey:@"displayWithoutDialog"];
    if (self.data != nil)
    {
        [dict setValue:self.data forKey:@"data"];
    }
    [dict setValue:[NSNumber numberWithInteger:self.code] forKey:@"code"];
    [dict setValue:[NSNumber numberWithBool:self.isAppOnForeground] forKey:@"isAppOnForeground"];
    [dict setValue:[NSNumber numberWithInteger:self.msgID] forKey:@"msgID"];
    [dict setValue:[NSNumber numberWithBool:self.isInAppSlide] forKey:@"isInAppSlide"];
    [dict setValue:[NSNumber numberWithFloat:self.portion] forKey:@"portion"];
    [dict setValue:[NSNumber numberWithInteger:self.orientation] forKey:@"orientation"];
    [dict setValue:[NSNumber numberWithFloat:self.speed] forKey:@"speed"];
    if (self.sound != nil)
    {
        [dict setValue:self.sound forKey:@"sound"];
    }
    [dict setValue:[NSNumber numberWithInteger:self.badge] forKey:@"badge"];
    return dict;
}

+ (PushDataForApplication *)fromDictionary:(NSDictionary *)dict
{
    PushDataForApplication *pushData = [[PushDataForApplication alloc] init];
    if ([dict.allKeys containsObject:@"title"])
    {
        pushData.title = dict[@"title"];
    }
    if ([dict.allKeys containsObject:@"message"])
    {
        pushData.message = dict[@"message"];
    }
    pushData.displayWithoutDialog = [dict[@"displayWithoutDialog"] boolValue];
    if ([dict.allKeys containsObject:@"data"])
    {
        pushData.data = dict[@"data"];
    }
    pushData.code = [dict[@"code"] integerValue];
    pushData.isAppOnForeground = [dict[@"isAppOnForeground"] boolValue];
    pushData.msgID = [dict[@"msgID"] integerValue];
    pushData.isInAppSlide = [dict[@"isInAppSlide"] boolValue];
    pushData.portion = [dict[@"portion"] floatValue];
    pushData.orientation = (SHSlideDirection)[dict[@"orientation"] integerValue];
    pushData.speed = [dict[@"speed"] floatValue];
    if ([dict.allKeys containsObject:@"sound"])
    {
        pushData.sound = dict[@"sound"];
    }
    pushData.badge = [dict[@"badge"] integerValue];
    return pushData;
}

@end
