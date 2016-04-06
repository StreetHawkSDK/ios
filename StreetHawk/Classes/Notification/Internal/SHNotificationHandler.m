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

#import "SHNotificationHandler.h"
//header from StreetHawk
#import "SHApp+Notification.h" //for `StreetHawk.developmentPlatform`
#import "SHLogger.h" //for send logline
#import "SHFriendlyNameObject.h" //for parse friendly name
#import "SHSlideViewController.h" //for 8000 slide push
#import "SHAppStatus.h" //for 8003 sendAppStatusCheckRequest
#import "SHDeepLinking.h" //for 8004 launch page
#import "SHFeedbackQueue.h" //for 8010 feedback push
#import "SHUtils.h" //for shLocalizedString
#import "SHTypes.h" //for SH_BEACON_BLUETOOTH
#import "SHInteractiveButtons.h" //for interactive pair buttons
//header from System
#import <CoreBluetooth/CoreBluetooth.h>
//header from Third-party
#import "Emojione.h" //for convert emoji to unicode

@interface SHNotificationHandler ()

//background execution
@property (nonatomic, strong) NSOperationQueue *backgroundQueue;  //Used for background execution. Enter background or foreground must be finished in 10 seconds, to finish send install/log request begin a background task which can run 10 minutes in another thread using operation queue.
//End background task, must do this for started background task.
- (void)endBackgroundTask:(UIBackgroundTaskIdentifier)backgroundTask;

@end

@implementation SHNotificationHandler

#pragma mark - life cycle

- (id)init
{
    if (self = [super init])
    {
        self.backgroundQueue = [[NSOperationQueue alloc] init];
        self.backgroundQueue.maxConcurrentOperationCount = 1;
    }
    return self;
}

#pragma mark - public functions

const NSString *Push_Payload_Code = @"c";  //code
const NSString *Push_Payload_MsgId = @"i";  //msgid
const NSString *Push_Payload_Data = @"d";  //data
const NSString *Push_Payload_Slide_Proportion = @"p";  //proportion (former: pixel)
const NSString *Push_Payload_Slide_Orientation = @"o"; //orientation (former: direction)
const NSString *Push_Payload_Slide_Speed = @"s";  //speed
const NSString *Push_Payload_DialogTitleLength = @"l"; //title "t" and message "m" is deprecated now, use "l" as title lenght of "alert", left is message.
const NSString *Push_Payload_SupressDialog = @"n"; //if payload has "n", regardless of its value, not show confirm dialog.

- (BOOL)isDefinedCode:(NSDictionary *)userInfo
{
    int code = -1;
    NSObject *codeStr = userInfo[Push_Payload_Code];
    if (codeStr != nil && ([codeStr isKindOfClass:[NSNumber class]] || [codeStr isKindOfClass:[NSString class]]))
    {
        code = [((NSNumber *)codeStr) intValue];
    }
    //But it's also possible that the push message is sent by other format without code. If it's not standard format, StreetHawk SDk ignores it and let other to handle.
    if (code == -1)
    {
        return NO;
    }
    return [[SHInteractiveButtons predefinedCodes] containsObject:@(code)];
}

- (BOOL)handleDefinedUserInfo:(NSDictionary *)userInfo withAction:(SHNotificationActionResult)action treatAppAs:(SHAppFGBG)appFGBG forNotificationType:(SHNotificationType)notificationType
{
    [StreetHawk setApplicationBadge:0]; //clear badge here too, as for Titanium StreetHawk is init after didBecomeActive, so first launch cannot clear badge.
    PushDataForApplication *pushData = [[PushDataForApplication alloc] init];
    NSAssert([self isDefinedCode:userInfo], @"Only work for defined code but pass in %@.", userInfo);
    if (![self isDefinedCode:userInfo])
    {
        return NO;
    }
    pushData.code = [((NSNumber *)userInfo[Push_Payload_Code]) integerValue]; //checked above already
    if (pushData.action != SHAction_CheckAppStatus) //only check app status can reset enable/disable streethawk functions
    {
        if (!streetHawkIsEnabled())
        {
            return NO;
        }
    }
    if (notificationType == SHNotificationType_SmartPush)
    {
        NSAssert([UIApplication sharedApplication].applicationState == UIApplicationStateActive, @"Smart push only trigger when App is active.");
    }
    switch (appFGBG)
    {
        case SHAppFGBG_Unknown:
            pushData.isAppOnForeground = ([UIApplication sharedApplication].applicationState == UIApplicationStateActive); //Remember the state when App receive push notification. To switch quick for App is in background and wake up and then switch to other App, the action will be delay, cause state is always UIApplicationStateActive in action. Use this to know the original state.
            break;
        case SHAppFGBG_FG:
            pushData.isAppOnForeground = YES;
            break;
        case SHAppFGBG_BG:
            pushData.isAppOnForeground = NO;
            break;
        default:
            NSAssert(NO, @"AppFGBG should not meet here.");
            pushData.isAppOnForeground = YES;
            break;
    }
    NSAssert(action == SHNotificationActionResult_Unknown || !pushData.isAppOnForeground, @"Action has decided must trigger from BG.");
    if ([userInfo.allKeys containsObject:@"aps"])
    {
        NSDictionary *dictAps = userInfo[@"aps"];
        NSAssert([dictAps isKindOfClass:[NSDictionary class]], @"aps is not a dictionary.");
        if ([dictAps isKindOfClass:[NSDictionary class]])
        {
            if ([dictAps.allKeys containsObject:@"sound"])
            {
                pushData.sound = dictAps[@"sound"];
            }
            if ([dictAps.allKeys containsObject:@"badge"])
            {
                pushData.badge = [dictAps[@"badge"] integerValue];
            }
            if ([dictAps.allKeys containsObject:@"category"])
            {
                pushData.category = dictAps[@"category"];
            }
            if ([dictAps.allKeys containsObject:@"alert"])
            {
                NSString *alert = (NSString *)dictAps[@"alert"];
                NSAssert([alert isKindOfClass:[NSString class]], @"alert is not a string.");
                if (!shStrIsEmpty(alert))
                {
                    NSAssert([userInfo.allKeys containsObject:Push_Payload_DialogTitleLength], @"Alert must have title length.");
                    if ([userInfo.allKeys containsObject:Push_Payload_DialogTitleLength])
                    {
                        NSInteger titleLength = [NONULL(userInfo[Push_Payload_DialogTitleLength]) integerValue];
                        if (titleLength < 0)
                        {
                            titleLength = 0;
                        }
                        if (titleLength > alert.length)
                        {
                            titleLength = alert.length;
                        }
                        pushData.title = [Emojione shortnameToUnicode:[[alert substringToIndex:titleLength] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
                        pushData.message = [Emojione shortnameToUnicode:[[alert substringFromIndex:titleLength] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
                    }
                }
            }
        }
    }
    //Send pushack for remote notification when enable background mode. Pushack is sent no matter App in FG or BG as much as possible, although if a) user kill App b) device restart cannot wake App.
    pushData.msgID = [NONULL(userInfo[Push_Payload_MsgId]) integerValue];
    pushData.data = userInfo[Push_Payload_Data];
    if ([pushData.data isKindOfClass:[NSString class]])  //cannot assume data is string, as 8011, 8049 send dictionary
    {
        NSString *refinedStr = (NSString *)pushData.data;
        refinedStr = [refinedStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];  //trim string as it may cause some problem.
        if ([refinedStr compare:@"<null>" options:NSCaseInsensitiveSearch] == NSOrderedSame) //server return "<null>" as a bug, treat as empty string
        {
            refinedStr = @"";
        }
        pushData.data = refinedStr;
    }
    else if (pushData.data == [NSNull null])
    {
        pushData.data = nil;
    }
    if (notificationType == SHNotificationType_Remote || notificationType == SHNotificationType_SmartPush) //these two are sent from server so must send pushack back
    {
        NSAssert(pushData.msgID != 0, @"Fail to get msg id from %@.", userInfo);
        //Send pushack logline
        [StreetHawk sendLogForCode:LOG_CODE_PUSH_ACK withComment:[NSString stringWithFormat:@"%@", pushData.data]/*treat data as string*/ forAssocId:pushData.msgID withResult:100/*ignore*/ withHandler:nil]; //Cannot send pushack immediately at background. In order to send at background must use background mode with "content-available:1" and let it execute in background, however once App execute in background, the badge and notification list entry is lost, causing user cannot find this notification any more. It cannot trigger local notification again to add the badge and entry as it will promote twice. Use silent remote notification and local notification does not work either, as silent remote notification cannot wake App when user kill App or device restart, causing lose message.
    }
    if (action == SHNotificationActionResult_NO || action == SHNotificationActionResult_Later)
    {
        SHResult pushResult = (action == SHNotificationActionResult_NO) ? SHResult_Decline : SHResult_Postpone;
        //This must be invoked from interactive push and it's background, to send install/log successfully, begin a background task to gain 10 minutes to finish this. Otherwise the log cannot be sent till next launch to FG.
        __block UIBackgroundTaskIdentifier backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^
         {
             [self endBackgroundTask:backgroundTask];
         }];
        __block NSBlockOperation *op = [NSBlockOperation blockOperationWithBlock:^
        {
            if (!op.isCancelled)
            {
                [pushData sendPushResult:pushResult withHandler:^(NSObject *result, NSError *error)
                {
                    //Once start not cancel the install/log request, there are 10 minutes so make sure it can finish. Call endBackgroundTask after it's done.
                    [self endBackgroundTask:backgroundTask];
                }];
            }
            else
            {
                [self endBackgroundTask:backgroundTask];
            }
        }];
        [self.backgroundQueue addOperation:op];
        return YES;
    }
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground/*This is really in background execution, if wake from background it's inactive*/
        && (pushData.action != SHAction_CheckAppStatus))
    {
        return YES; //If App in background should not continue UI required actions.
    }
    //Now process payload with UI or action.
    pushData.isInAppSlide = NO;
    pushData.orientation = SHSlideDirection_Up;
    pushData.speed = 0;
    pushData.portion = 1;
    if ([userInfo.allKeys containsObject:Push_Payload_Slide_Proportion])
    {
        pushData.isInAppSlide = YES;
        pushData.portion = [NONULL(userInfo[Push_Payload_Slide_Proportion]) doubleValue];
    }
    if ([userInfo.allKeys containsObject:Push_Payload_Slide_Orientation])
    {
        pushData.isInAppSlide = YES;
        int direction = [NONULL(userInfo[Push_Payload_Slide_Orientation]) intValue];
        pushData.orientation = (direction >= 0 && direction < 4) ? direction : 0;
    }
    if ([userInfo.allKeys containsObject:Push_Payload_Slide_Speed])
    {
        pushData.isInAppSlide = YES;
        pushData.speed = [NONULL(userInfo[Push_Payload_Slide_Speed]) doubleValue];
    }
    pushData.isInAppSlide = pushData.isInAppSlide && (pushData.action == SHAction_OpenUrl)/*support slide type*/;
    if (pushData.isInAppSlide)
    {
        pushData.displayWithoutDialog = [userInfo.allKeys containsObject:Push_Payload_SupressDialog]; //if payload has "n" no need to show confirm dialog. This is only used for in app slide. In all other cases it's NO.
    }
    NSString *deeplinkingStr = nil;
    if ((pushData.action == SHAction_LaunchActivity || pushData.action == SHAction_UserRegistrationScreen || pushData.action == SHAction_UserLoginScreen) && (pushData.data == nil || [pushData.data isKindOfClass:[NSString class]]))
    {
        deeplinkingStr = (NSString *)pushData.data;
        if (pushData.action == SHAction_UserRegistrationScreen && (deeplinkingStr == nil || deeplinkingStr.length == 0))
        {
            deeplinkingStr = FRIENDLYNAME_REGISTER;
        }
        if (pushData.action == SHAction_UserLoginScreen && (deeplinkingStr == nil || deeplinkingStr.length == 0))
        {
            deeplinkingStr = FRIENDLYNAME_LOGIN;
        }
    }
    //implement the action for each system code
    dispatch_block_t confirmAction = nil;
    dispatch_block_t dismissAction = nil;
    //Phonegap 8004 push from BG (include not launched) to FG, need to set html page (vcClassName) at first time, because html "shGetViewName" do direct when html page show. If move this to later place, because the checking is asynchronous it's too late to setup NSUserDefaults.
    if (pushData.action == SHAction_LaunchActivity && !pushData.isAppOnForeground && (StreetHawk.developmentPlatform == SHDevelopmentPlatform_Phonegap || StreetHawk.developmentPlatform == SHDevelopmentPlatform_Titanium || StreetHawk.developmentPlatform == SHDevelopmentPlatform_Unity))
    {
        //Phonegap and Titanium not support deeplinking launch, it can only launch a simple html/xml page. Unity can only print console log.
        //The deeplinking string can only be page or friendly name. If it's friendly name, need to convert to raw page name.
        SHFriendlyNameObject *findObj = [SHFriendlyNameObject findObjByFriendlyName:deeplinkingStr];
        if (findObj != nil)
        {
            deeplinkingStr = findObj.vc; //get raw page name
        }
        [[NSUserDefaults standardUserDefaults] setObject:deeplinkingStr forKey:PHONEGAP_8004_PAGE];
        [[NSUserDefaults standardUserDefaults] setObject:[pushData toDictionary] forKey:PHONEGAP_8004_PUSHDATA];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    //8049 is customised handler, check and call customised function.
    if (pushData.action == SHAction_CustomJson)
    {
        BOOL isCustomisedHandled = NO;
        NSString *jsonString = nil;
        if ([pushData.data isKindOfClass:[NSString class]])
        {
            jsonString = (NSString *)pushData.data;
        }
        else if ([pushData.data isKindOfClass:[NSDictionary class]])
        {
            jsonString = shSerializeObjToJson(pushData.data);
            if (shStrIsEmpty(jsonString))
            {
                [StreetHawk sendLogForCode:LOG_CODE_ERROR withComment:[NSString stringWithFormat:@"Error: Meet error when serialize %@ to json. Push msgid: %ld.", pushData.data, (long)pushData.msgID] forAssocId:0 withResult:100 withHandler:nil];
                 jsonString = [NSString stringWithFormat:@"%@", pushData.data]; //still try to pass to customer handler.
            }            
        }
        else
        {
            NSAssert(NO, @"data is not string or dictionary: %@.", pushData.data);
            //Although this error logline sent, it will continue to handle jsonString and send push result.
            [StreetHawk sendLogForCode:LOG_CODE_ERROR withComment:[NSString stringWithFormat:@"data is not string or dictionary: %@. Push msgid: %ld.", pushData.data, (long)pushData.msgID] forAssocId:0 withResult:100 withHandler:nil];
            jsonString = [NSString stringWithFormat:@"%@", pushData.data];
        }
        for (id<ISHCustomiseHandler> handler in StreetHawk.arrayCustomisedHandler)
        {
            if ([handler respondsToSelector:@selector(shRawJsonCallbackWithTitle:withMessage:withJson:)]) //implementation is optional
            {
                [handler shRawJsonCallbackWithTitle:pushData.title withMessage:pushData.message withJson:jsonString];
                isCustomisedHandled = YES;
            }
        }
        [pushData sendPushResult:isCustomisedHandled ? SHResult_Accept : SHResult_Decline withHandler:nil];
        return isCustomisedHandled;
    }
    BOOL shouldShowConfirmDialog = [pushData shouldShowConfirmDialog];
    if (pushData.action == SHAction_OpenUrl)  //data is supposed to be url, for example https://www.streethawk.com
    {
        if (pushData.data == nil || ![pushData.data isKindOfClass:[NSString class]] || ((NSString *)pushData.data).length == 0)
        {
            [StreetHawk sendLogForCode:LOG_CODE_ERROR withComment:[NSString stringWithFormat:@"Open webpage with invalid url: %@. Push msgid: %ld.", pushData.data, (long)pushData.msgID] forAssocId:0 withResult:100/*ignore*/ withHandler:nil];
            pushData.isInAppSlide = NO; //wrong data cannot slide, just forcily make confirm dialog show, because if isInAppSlide=YES will show dialog when loading slide.
            //Notification data has error, App in BG sends pushresult=1; App in FG depends on confirm dialog.
            confirmAction = ^ {
                [pushData sendPushResult:SHResult_Accept withHandler:nil];
            };
        }
        else
        {
            confirmAction = ^ {
                if (!pushData.isInAppSlide)
                {
                    if (!pushData.isAppOnForeground || shouldShowConfirmDialog)  //if title/msg/slide are all empty and App is in foreground, not do anything. This is to avoid suddenly transfer to safari.
                    {
                        [pushData sendPushResult:SHResult_Accept withHandler:nil];
                        //Start to open url in safari
                        NSString *address = (NSString *)pushData.data;  //checked in above logic
                        if ([address rangeOfString:@"://"].location == NSNotFound)  //if not have protocal, prefix https://
                        {
                            address = [NSString stringWithFormat:@"https://%@", address];
                        }
                        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:address]];
                    }
                }
                else
                {
                    //Ticket https://bitbucket.org/shawk/streethawk/issue/368/remove-h-parameter-in-8000 We use h to hide / show loading of webpage. This can be removed and following can be implemented 1. App in FG,(no t/m) always load URL in BG and slide in after loading. 2. Rest all scenarios (t/m in FG) and (app in BG) always shows spinner progress bar indicating loading.
                    BOOL slideHideLoading = pushData.isAppOnForeground && !shouldShowConfirmDialog;
                    [StreetHawk slideForUrl:(NSString *)pushData.data withDirection:pushData.orientation withSpeed:pushData.speed withCoverPercentage:pushData.portion withHideLoading:slideHideLoading withAlertTitle:pushData.title withAlertMessage:pushData.message withNeedShowDialog:pushData.isAppOnForeground withPushData:pushData];
                }
            };
        }
    }
    else if (pushData.action == SHAction_CheckAppStatus)
    {
        confirmAction = ^ {
            [pushData sendPushResult:SHResult_Accept withHandler:nil];
            [[SHAppStatus sharedInstance] sendAppStatusCheckRequest:YES/*8003 force to do check*/];
        };
    }
    else if (pushData.action == SHAction_LaunchActivity || pushData.action == SHAction_UserRegistrationScreen || pushData.action == SHAction_UserLoginScreen)
    {
        if (!pushData.isAppOnForeground || shouldShowConfirmDialog)  //if title/msg/slide are all empty and App is in foreground, not do anything. This is to avoid suddenly launch a page without confirmed by user.
        {
            confirmAction = ^{
                //In notification there are many cases. Only deeplinking without "launchvc" should be handled by customer.
                BOOL handledByCustomer = NO;
                if (StreetHawk.openUrlHandler != nil)
                {
                    NSURL *deeplinkingUrl = [NSURL URLWithString:deeplinkingStr];
                    if (!shStrIsEmpty(deeplinkingUrl.scheme) /*it's a standard deeplinking url, not vc or friendly name only.*/
                        && [deeplinkingUrl.host compare:@"launchvc" options:NSCaseInsensitiveSearch] != NSOrderedSame /*not intend to use launchvc*/)
                    {
                        StreetHawk.openUrlHandler(deeplinkingUrl);
                        handledByCustomer = YES;
                        SHLog(@"Customer App code to handle this launch activitiy notification for: %@.", deeplinkingStr);
                        [pushData sendPushResult:SHResult_Accept withHandler:nil]; //customer code to handle, treat as accept as customer won't send result.
                    }
                }
                if (!handledByCustomer)
                {
                    if (StreetHawk.developmentPlatform == SHDevelopmentPlatform_Native || StreetHawk.developmentPlatform == SHDevelopmentPlatform_Xamarin)
                    {
                        SHDeepLinking *deepLinkingObj = [[SHDeepLinking alloc] init];
                        BOOL vcLaunched = [deepLinkingObj launchDeepLinkingVC:deeplinkingStr withPushData:pushData increaseGrowthClick:YES];
                        if (!vcLaunched)
                        {
                            [StreetHawk sendLogForCode:LOG_CODE_ERROR withComment:[NSString stringWithFormat:@"Fail to create VC from \"%@\". Push msgid: %ld.", pushData.data, (long)pushData.msgID] forAssocId:0 withResult:100/*ignore*/ withHandler:nil];
                            //Cannot launch vc, however still need to show confirm dialog in FG, and sends pushresult; in BG always sends pushresult=1.
                            if ([pushData shouldShowConfirmDialog])
                            {
                                NSMutableDictionary *dictUserInfo = [NSMutableDictionary dictionary];
                                dictUserInfo[@"pushdata"] = pushData;
                                dictUserInfo[@"clickbutton"] = ^(SHResult result)
                                {
                                    [pushData sendPushResult:result withHandler:nil];
                                };
                                [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PushBridge_HandlePushData" object:nil userInfo:dictUserInfo];
                            }
                            else
                            {
                                [pushData sendPushResult:SHResult_Accept withHandler:nil];
                            }
                        }
                    }
                    else
                    {
                        if (!pushData.isAppOnForeground)
                        {
                            //Titanium also uses callback launch. Actually this depends on customer App, however now this can make TiSample work.
                            //Phonegap:
                            //1. When App is launched from background to foreground, store view page locally and it will be called by [StreetHawk shGetViewName] to used when html start. Do it above at first time, it's too late here. This is handled automatically by common.js. "d" must use correct html path.
                                //function shResume(){
                                //var sh = cordova.require("com.streethawk.plugin.Streethawk");
                                //sh.shGetViewName(function(result){
                                //    if(null!=result){
                                //        launchAppPage(result);
                                //    }
                                //},function(){});
                                //}
                            //2. When App from not launch, call this due to delay launch notification. It's also called by from BG to FG but nothing happen.
                            [StreetHawk shPGLoadHtml:deeplinkingStr];
                            [pushData sendPushResult:SHResult_Accept withHandler:nil];
                        }
                        else  //App is in FG, call plugin's shPGDisplayHtmlFileName to trigger loading.
                        {
                            [StreetHawk handlePushDataForAppCallback:pushData clickButton:^(SHResult result)
                             {
                                 if (result == SHResult_Accept)
                                 {
                                     [StreetHawk shPGLoadHtml:deeplinkingStr];
                                 }
                                 [pushData sendPushResult:result withHandler:nil];
                             }];
                        }
                    }
                }
            };
        }
    }    
    else if (pushData.action == SHAction_RateApp || pushData.action == SHAction_UpdateApp)
    {
        if (!pushData.isAppOnForeground || shouldShowConfirmDialog)  //if title/msg are all empty and App is in foreground, not do anything. This is to avoid suddenly transfer to AppStore without confirmed by user.
        {
            confirmAction = ^ {
                NSString *iTunesId = nil;
                //needs to check it's valid iTunesId, because Android push "com.example.myshtestapp.abc" as d. Valid iTunes Id is like "507040546", all numbers.
                NSString *data = (NSString *)pushData.data;
                if (data != nil && [data isKindOfClass:[NSString class]] && data.length > 0)
                {
                    BOOL isValid = YES;
                    for (int i = 0; i < data.length; i ++)
                    {
                        unichar ch = [data characterAtIndex:i];
                        if (ch < '0' || ch > '9') //not number character
                        {
                            isValid = NO;
                            break;
                        }
                    }
                    if (isValid)
                    {
                        iTunesId = data;
                    }
                }
                if (iTunesId == nil || ![iTunesId isKindOfClass:[NSString class]] || iTunesId.length == 0)
                {
                    iTunesId = StreetHawk.itunesAppId;
                }
                if (iTunesId != nil && iTunesId.length > 0)
                {
                    [pushData sendPushResult:SHResult_Accept withHandler:nil];
#if TARGET_IPHONE_SIMULATOR
                    SHLog(@"APPIRATER NOTE: iTunes App Store is not supported on the iOS simulator. Unable to open App Store page.");
#else
                    NSString *appLink = nil;
                    double iOSVersion = [[UIDevice currentDevice].systemVersion doubleValue];
                    if (iOSVersion >= 7.0)
                    {
                        appLink = [NSString stringWithFormat:@"itms-apps://itunes.apple.com/app/id%@", iTunesId];
                    }
                    else
                    {
                        
                        appLink = (pushData.action == SHAction_RateApp) ? [NSString stringWithFormat:@"itms-apps://ax.itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?type=Purple+Software&id=%@", iTunesId] : [NSString stringWithFormat:@"itms-apps://itunes.apple.com/WebObjects/MZStore.woa/wa/viewSoftware?id=%@&mt=8", iTunesId];
                    }
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:appLink]];
#endif
                }
                else
                {
                    NSString *appDisplayName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
                    [StreetHawk sendLogForCode:LOG_CODE_ERROR withComment:[NSString stringWithFormat:@"App %@ try to open AppStore without setup itunes id. Push msgid: %ld.", appDisplayName, (long)pushData.msgID] forAssocId:0 withResult:100/*ignore*/ withHandler:nil];
                    //Notification data has error, App in BG sends pushresult=1; App in FG depends on confirm dialog.
                    [pushData sendPushResult:SHResult_Accept withHandler:nil];
                    SHLog(@"WARNING: Please setup iTunes Id in web console -> App Details -> App Summary.");
                }
            };
        }
    }
    else if (pushData.action == SHAction_CallTelephone) //call telephone, data should be a phone number
    {
        if (pushData.data == nil || ![pushData.data isKindOfClass:[NSString class]] || ((NSString *)pushData.data).length == 0)
        {
            [StreetHawk sendLogForCode:LOG_CODE_ERROR withComment:[NSString stringWithFormat:@"Call telephone with invalid number: %@. Push msgid: %ld.", pushData.data, (long)pushData.msgID] forAssocId:0 withResult:100/*ignore*/ withHandler:nil];
            //Notification data has error, App in BG sends pushresult=1; App in FG depends on confirm dialog.
            confirmAction = ^ {
                [pushData sendPushResult:SHResult_Accept withHandler:nil];
            };
        }
        else if (pushData.isAppOnForeground && !shouldShowConfirmDialog)
        {
            return YES; //if Application is in foreground and no confirmation dialog, ignore this because should not directly trigger call telephone without user approval.
        }
        else
        {
            confirmAction = ^ {
                [pushData sendPushResult:SHResult_Accept withHandler:nil];
                shCallPhoneNumber((NSString *)pushData.data);  //data validation is checked above
            };
        }
    }
    else if (pushData.action == SHAction_SimplePrompt)  //simply launch App
    {
        confirmAction = ^ {
            [pushData sendPushResult:SHResult_Accept withHandler:nil];
        };
    }
    else if (pushData.action == SHAction_Feedback)
    {
        //data should be dictionary
        //{
        //  "c": ["wrong address", "product not available"],  //list of options, can be empty
        //  "i": 0|1, //show message box after tapping on one of the options (if 1)
        //}
        NSDictionary *dictFeedback = shParseObjectToDict(pushData.data);
        if (dictFeedback != nil)
        {
            confirmAction = ^{
                NSArray *arrayChoice = nil;
                if ([dictFeedback.allKeys containsObject:@"c"] && [dictFeedback[@"c"] isKindOfClass:[NSArray class]])
                {
                    arrayChoice = dictFeedback[@"c"];
                }
                NSInteger needInput = 0;
                if ([dictFeedback.allKeys containsObject:@"i"] && [dictFeedback[@"i"] isKindOfClass:[NSNumber class]])
                {
                    needInput = [dictFeedback[@"i"] integerValue];
                }
                [StreetHawk shFeedback:arrayChoice needInputDialog:(needInput == 1) needConfirmDialog:pushData.isAppOnForeground/*show confirm dialog when App in FG only*/ withTitle:pushData.title withMessage:pushData.message withPushData:pushData];
            };
        }
        else
        {
            [StreetHawk sendLogForCode:LOG_CODE_ERROR withComment:[NSString stringWithFormat:@"Fail to parse feedback string: \"%@\". Push msgid: %ld.", pushData.data, (long)pushData.msgID] forAssocId:0 withResult:100/*ignored*/ withHandler:nil];
            //Cannot show feedback list, however still need to show confirm dialog in FG, and sends pushresult; in BG always sends pushresult=1.
            if ([pushData shouldShowConfirmDialog])
            {
                NSMutableDictionary *dictUserInfo = [NSMutableDictionary dictionary];
                dictUserInfo[@"pushdata"] = pushData;
                dictUserInfo[@"clickbutton"] = ^(SHResult result)
                {
                    [pushData sendPushResult:result withHandler:nil];
                };
                [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PushBridge_HandlePushData" object:nil userInfo:dictUserInfo];
            }
            else
            {
                [pushData sendPushResult:SHResult_Accept withHandler:nil];
            }
        }
    }
    else if (pushData.action == SHAction_EnableBluetooth)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_LMBridge_UpdateBluetoothStatus" object:nil];
        NSInteger bluetoothStatus = [[[NSUserDefaults standardUserDefaults] objectForKey:SH_BEACON_BLUETOOTH] integerValue];
        if ((pushData.isAppOnForeground/*is App from BG system setting maybe modified but bluetoothState is not updated on time yet. A good thing is it goes to direct action, and CBCentralManager can decide show dialog or not*/ && bluetoothStatus == CBCentralManagerStatePoweredOn/*if App in FG this is accurate*/))
        {
            [pushData sendPushResult:SHResult_Accept withHandler:nil];
            return YES;  //stop handle
        }
        confirmAction = ^{
            [pushData sendPushResult:SHResult_Accept withHandler:nil];
            //show dialog which can direct to system's Bluetooth setting page
            if ([CBCentralManager instancesRespondToSelector:@selector(initWithDelegate:queue:options:)])  //`options` since iOS 7.0, this push is to warning user to turn on Bluetooth for iBeacon, available since iOS 7.0.
            {
                CBCentralManager *tempManager = [[CBCentralManager alloc] initWithDelegate:nil queue:nil options:@{CBCentralManagerOptionShowPowerAlertKey: @(1/*show setting*/)}];
                tempManager = nil;
            }
        };
    }
    else if (pushData.action == SHAction_EnablePushMsg) //this also used for smart push, which can occur even when push is disabled.
    {
        if (!StreetHawk.systemPreferenceDisableNotification)
        {
            [pushData sendPushResult:SHResult_Accept withHandler:nil];
            return YES;  //stop handle
        }
        confirmAction = ^{
            [pushData sendPushResult:SHResult_Accept withHandler:nil];
            if (![StreetHawk launchSystemPreferenceSettings])
            {
                UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Info" message:@"Pre-iOS 8 please manually change in settings." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                [alertView show];
            }
        };
    }
    else if (pushData.action == SHAction_EnableLocation)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_LMBridge_UpdateLocationPermissionStatus" object:nil];
        BOOL locationPermission = [[[NSUserDefaults standardUserDefaults] objectForKey:SH_LOCATION_STATUS] boolValue];
        if (!locationPermission) //Get NO for: 1. Customer enables location permission; 2. Not have location module integrated. Both case should stop handler.
        {
            [pushData sendPushResult:SHResult_Accept withHandler:nil];
            return YES;  //stop handle
        }
        confirmAction = ^{
            [pushData sendPushResult:SHResult_Accept withHandler:nil];
            if (![StreetHawk launchSystemPreferenceSettings])
            {
                UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Info" message:@"Pre-iOS 8 please manually change in settings." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                [alertView show];
            }
        };
    }
    else if (pushData.action == SHAction_Ghost)
    {
        [pushData sendPushResult:SHResult_Accept withHandler:nil];
        SHLog(@"Ghost push is received"); //Ghost push does nothing, just silently send pushresult.
        return YES;
    }
    //action handler has done, start to invoke.
    if ((pushData.action == SHAction_SimplePrompt) //simple promote may show dialog even from BG.
        || ([pushData shouldShowConfirmDialog]
            && !pushData.isInAppSlide/*confirm dialog for slide implemented in slide, because if hide loading, the dialog show after load finish*/
            && (pushData.action != SHAction_LaunchActivity && pushData.action != SHAction_UserRegistrationScreen && pushData.action != SHAction_UserLoginScreen/*launch page handle alert view by itself*/)
            && (pushData.action != SHAction_Feedback/*feedback has alert title and message in feedback list, not use confirm dialog*/)))
    {
        [StreetHawk handlePushDataForAppCallback:pushData clickButton:^(SHResult result)
         {
             switch (result)
             {
                 case SHResult_Accept:
                     if (confirmAction != nil)
                     {
                         confirmAction(); //confirm may have its own handling, internal can dismiss, but dismissAction is truly cancel.
                     }
                     //confirm action responsible for sending Accept result in its own process.
                     break;
                 case SHResult_Postpone:
                     [pushData sendPushResult:result withHandler:nil];
                     break;
                 case SHResult_Decline:
                     if (dismissAction != nil)
                     {
                         dismissAction();
                     }
                     [pushData sendPushResult:result withHandler:nil];
                     break;
                 default:
                     break;
             }
         }];
    }
    else  //directly do action
    {
        if (confirmAction != nil)
        {
            if (pushData.isAppOnForeground)
            {
                confirmAction();
            }
            else
            {
                //ARC: no need this retain these otherwise they got released after [alertView show], and crash in block.
                //                        alertTitle  = alertTitle;
                //                        alertMsg = alertMsg;
                //if App is in background and wake up by this push notification, it's slow to directly call the action. by test delay a little makes it do it quicker.
                double delayInSeconds = 1; //by test 1 is minimum, 0.5 does not work; dispatch_to_main does not work either.
                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                dispatch_after(popTime, dispatch_get_main_queue(), ^(void)
                   {
                       confirmAction();
                   });
            }
        }
    }
    return YES;
}

#pragma mark - private functions

- (void)endBackgroundTask:(UIBackgroundTaskIdentifier)backgroundTask
{
    [[UIApplication sharedApplication] endBackgroundTask:backgroundTask];
    backgroundTask = UIBackgroundTaskInvalid;
}

@end
