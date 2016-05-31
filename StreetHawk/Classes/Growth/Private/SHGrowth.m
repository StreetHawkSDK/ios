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

#import "SHGrowth.h"
//header from StreetHawk
#import "SHApp.h" //for `StreetHawk.currentInstall`
#import "SHInstall.h" //for `StreetHawk.currentInstall.suid`
#import "SHTypes.h" //for NONULL
#import "SHHTTPSessionManager.h" //for sending request
#import "SHAlertView.h" //for choose channel
#import "SHUtils.h" //for strIsEmpty
#import "SHDeepLinking.h" //for handling deeplinking url
//header from System
#import <MessageUI/MessageUI.h> //for sending SMS and email
#import <Social/Social.h> //for sharing to Facebook, twitter etc
//header from Third-party
#import "MBProgressHUD.h" //for progress view

static const NSString *GrowthServer = @"https://pointzi.streethawk.com";

#define GROWTH_REGISTERED   @"GROWTH_REGISTERED" //key for flag indicate growth is registered

@interface SHGrowth() <MFMessageComposeViewControllerDelegate, MFMailComposeViewControllerDelegate>

@property (nonatomic) BOOL isGrowthRegistered;

//notification
- (void)installRegistrationSucceededForGrowth:(NSNotification *)notification;
- (void)installUpdateSucceededForGrowth:(NSNotification *)notification;
- (void)handleGrowthRegister;

@end

@implementation SHGrowth

#pragma mark - life cycle

+ (void)initialize
{
    if ([self class] == [SHGrowth class])
    {
        NSMutableDictionary *initialDefaults = [NSMutableDictionary dictionary];
        initialDefaults[GROWTH_REGISTERED] = @(NO);
        [[NSUserDefaults standardUserDefaults] registerDefaults:initialDefaults];
    }
}

#pragma mark - properties

@dynamic isGrowthRegistered;

- (void)setIsGrowthRegistered:(BOOL)isGrowthRegistered
{
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:isGrowthRegistered] forKey:GROWTH_REGISTERED];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)isGrowthRegistered
{
    NSObject *obj = [[NSUserDefaults standardUserDefaults] objectForKey:GROWTH_REGISTERED];
    if (obj != nil && [obj isKindOfClass:[NSNumber class]])
    {
        return [(NSNumber *)obj boolValue];
    }
    return NO;
}

#pragma mark - public functions

+ (SHGrowth *)sharedInstance
{
    static SHGrowth *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
      {
          instance = [[SHGrowth alloc] init];
      });
    return instance;
}

- (void)originateShareWithCampaign:(NSString *)utm_campaign withSource:(NSString *)utm_source withMedium:(NSString *)utm_medium withContent:(NSString *)utm_content withTerm:(NSString *)utm_term shareUrl:(NSURL *)shareUrl withDefaultUrl:(NSURL *)default_url streetHawkGrowth_object:(SHCallbackHandler)handler
{
    if (StreetHawk.currentInstall == nil)
    {
        if (handler)
        {
            handler(nil, [NSError errorWithDomain:SHErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey: @"StreetHawk isn't installed successfully for Growth share."}]);
        }
        return;
    }
    NSAssert(StreetHawk.currentInstall.suid != nil && StreetHawk.currentInstall.suid.length > 0, @"Install id not ready for Growth share.");
    NSMutableDictionary *dictParam = [NSMutableDictionary dictionary];
    [dictParam setObject:NONULL(StreetHawk.currentInstall.suid) forKey:@"sh_cuid"];
    [dictParam setObject:NONULL(StreetHawk.appKey) forKey:@"app_key"];
    if ([utm_campaign isKindOfClass:[NSString class]] && !shStrIsEmpty(utm_campaign))
    {
        [dictParam setObject:NONULL(utm_campaign) forKey:@"utm_campaign"];
    }
    if ([utm_source isKindOfClass:[NSString class]] && !shStrIsEmpty(utm_source))
    {
        [dictParam setObject:NONULL([utm_source lowercaseString]) forKey:@"utm_source"];
    }
    if ([utm_medium isKindOfClass:[NSString class]] && !shStrIsEmpty(utm_medium))
    {
        [dictParam setObject:NONULL(utm_medium) forKey:@"utm_medium"];
    }
    if ([utm_content isKindOfClass:[NSString class]] && !shStrIsEmpty(utm_content))
    {
        [dictParam setObject:NONULL(utm_content) forKey:@"utm_content"];
    }
    if ([utm_term isKindOfClass:[NSString class]] && !shStrIsEmpty(utm_term))
    {
        [dictParam setObject:NONULL(utm_term) forKey:@"utm_term"];
    }
    if (shareUrl != nil)
    {
        [dictParam setObject:NONULL(shareUrl.scheme) forKey:@"scheme"];
        NSString *uri =  shareUrl.resourceSpecifier;
        if ([uri hasPrefix:@"//"])
        {
            uri = [uri substringFromIndex:2];
        }
        [dictParam setObject:NONULL(uri) forKey:@"uri"];
    }
    if (default_url != nil)
    {
        [dictParam setObject:NONULL(default_url.absoluteString) forKey:@"destination_url_default"];
    }
    handler = [handler copy];
    [[SHHTTPSessionManager sharedInstance] POST:[NSString stringWithFormat:@"%@/originate_viral_share/", GrowthServer] hostVersion:SHHostVersion_Unknown body:dictParam success:^(NSURLSessionDataTask * _Nullable task, id  _Nullable responseObject)
    {
        if (handler)
        {
            NSString *share_guid_url = nil;
            NSError *error = nil;
            NSAssert([responseObject isKindOfClass:[NSDictionary class]], @"Expect NSDictionary for growth share guid, but get :%@.", responseObject);
            if ([responseObject isKindOfClass:[NSDictionary class]])
            {
                NSDictionary *dict = (NSDictionary *)responseObject;
                NSAssert([dict.allKeys containsObject:@"share_guid_url"], @"share_guid_url is not in %@.", dict);
                if ([dict.allKeys containsObject:@"share_guid_url"])
                {
                    share_guid_url = dict[@"share_guid_url"];
                }
                else
                {
                    error = [NSError errorWithDomain:SHErrorDomain code:INT_MIN userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"share_guid_url is not in %@.", dict]}];
                }
            }
            else
            {
                error = [NSError errorWithDomain:SHErrorDomain code:INT_MIN userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Expect NSDictionary for growth share guid, but get :%@.", responseObject]}];
            }
            handler(share_guid_url, error);
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nullable error)
    {
        if (handler)
        {
            handler(nil, error);
        }
    }];
}

- (void)originateShareWithCampaign:(NSString *)utm_campaign withMedium:(NSString *)utm_medium withContent:(NSString *)utm_content withTerm:(NSString *)utm_term shareUrl:(NSURL *)shareUrl withDefaultUrl:(NSURL *)default_url withMessage:(NSString *)message
{
    SHAlertView *channelsView = [[SHAlertView alloc] initWithTitle:shLocalizedString(@"STREETHAWK_Growth_Channel_Title", @"Share content to which channel?") message:shLocalizedString(@"STREETHAWK_Growth_Channel_Message", @"Please choose one channel from below to share the url.") withHandler:^(UIAlertView *view, NSInteger buttonIndex)
    {
        if (buttonIndex != view.cancelButtonIndex)
        {
            NSString *selectedChannel = [view buttonTitleAtIndex:buttonIndex];
            NSString *utm_source = nil;
            if ([selectedChannel compare:shLocalizedString(@"STREETHAWK_Growth_Channel_SMS", @"SMS")] == NSOrderedSame)
            {
                utm_source = @"sms";
            }
            else if ([selectedChannel compare:shLocalizedString(@"STREETHAWK_Growth_Channel_Email", @"Email")] == NSOrderedSame)
            {
                utm_source = @"email";
            }
            else if ([selectedChannel compare:shLocalizedString(@"STREETHAWK_Growth_Channel_Facebook", @"Facebook")] == NSOrderedSame)
            {
                utm_source = @"facebook";
            }
            else if ([selectedChannel compare:shLocalizedString(@"STREETHAWK_Growth_Channel_Twitter", @"Twitter")] == NSOrderedSame)
            {
                utm_source = @"twitter";
            }
            else if ([selectedChannel compare:shLocalizedString(@"STREETHAWK_Growth_Channel_SinaWeibo", @"Sina Weibo")] == NSOrderedSame)
            {
                utm_source = @"sina weibo";
            }
            else if ([selectedChannel compare:shLocalizedString(@"STREETHAWK_Growth_Channel_TencentWeibo", @"Tencent Weibo")] == NSOrderedSame)
            {
                utm_source = @"tencent weibo";
            }
            else
            {
                NSAssert(NO, @"Unknown selected channel.");
            }
            NSAssert(!shStrIsEmpty(utm_source), @"Fail to find match utm_source in pre-defined channels.");
            UIWindow *presentWindow = shGetPresentWindow();
            MBProgressHUD *progressView = [MBProgressHUD showHUDAddedTo:presentWindow animated:YES];
            progressView.detailsLabelText = shLocalizedString(@"STREETHAWK_Growth_Channel_GeneratingUrl", @"Generating share_guid_url...");
            [self originateShareWithCampaign:utm_campaign withSource:utm_source withMedium:utm_medium withContent:utm_content withTerm:utm_term shareUrl:shareUrl withDefaultUrl:default_url streetHawkGrowth_object:^(NSObject *result, NSError *error)
             {
                 dispatch_async(dispatch_get_main_queue(), ^
                    {
                        [MBProgressHUD hideAllHUDsForView:presentWindow animated:YES];
                        shPresentErrorAlert(error, YES);
                        if (error == nil)
                        {
                            NSString *share_guid_url = (NSString *)result;
                            if ([selectedChannel compare:shLocalizedString(@"STREETHAWK_Growth_Channel_SMS", @"SMS")] == NSOrderedSame)
                            {
                                MFMessageComposeViewController *messageVC = [[MFMessageComposeViewController alloc] init];
                                messageVC.messageComposeDelegate = self;
                                messageVC.body = shAppendString(message, share_guid_url);  //body is aviable since iOS 4.0, subject available since iOS 7.0.
                                [presentWindow.rootViewController presentViewController:messageVC animated:YES completion:nil];
                            }
                            else if ([selectedChannel compare:shLocalizedString(@"STREETHAWK_Growth_Channel_Email", @"Email")] == NSOrderedSame)
                            {
                                MFMailComposeViewController *emailVC = [[MFMailComposeViewController alloc] init];
                                emailVC.mailComposeDelegate = self;
                                [emailVC setMessageBody:shAppendString(message, share_guid_url) isHTML:NO];
                                [presentWindow.rootViewController presentViewController:emailVC animated:YES completion:nil];
                            }
                            else
                            {
                                SLComposeViewController *shareVC = nil;
                                if ([selectedChannel compare:shLocalizedString(@"STREETHAWK_Growth_Channel_Facebook", @"Facebook")] == NSOrderedSame)
                                {
                                    shareVC = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeFacebook];
                                }
                                else if ([selectedChannel compare:shLocalizedString(@"STREETHAWK_Growth_Channel_Twitter", @"Twitter")] == NSOrderedSame)
                                {
                                    shareVC = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeTwitter];
                                }
                                else if ([selectedChannel compare:shLocalizedString(@"STREETHAWK_Growth_Channel_SinaWeibo", @"Sina Weibo")] == NSOrderedSame)
                                {
                                    shareVC = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeSinaWeibo];
                                }
                                else if ([selectedChannel compare:shLocalizedString(@"STREETHAWK_Growth_Channel_TencentWeibo", @"Tencent Weibo")] == NSOrderedSame)
                                {
                                    shareVC = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeTencentWeibo];
                                }
                                NSAssert(shareVC != nil, @"Cannot create social share VC.");
                                if (shareVC != nil)
                                {
                                    [shareVC setInitialText:shAppendString(message, share_guid_url)]; //addURL cannot show in text message part, so add share_guid_url as text.
                                    [shareVC addImage:[UIImage imageNamed:@"icon.png"]]; //share view has an obvious image part, use App's image.
                                    shareVC.completionHandler = ^(SLComposeViewControllerResult result)
                                    {
                                        MBProgressHUD *resultView = [MBProgressHUD showHUDAddedTo:presentWindow animated:YES];
                                        resultView.mode = MBProgressHUDModeText; //only show result text, not show progress bar.
                                        switch (result)
                                        {
                                            case SLComposeViewControllerResultCancelled:
                                                resultView.labelText = shLocalizedString(@"STREETHAWK_Growth_Channel_PostCancel", @"Post is cancelled.");
                                                break;
                                            case SLComposeViewControllerResultDone:
                                                resultView.labelText = shLocalizedString(@"STREETHAWK_Growth_Channel_PostDone", @"Post successfully!");
                                                break;
                                            default:
                                                NSAssert(NO, @"Unexpected share result.");
                                                break;
                                        }
                                        [resultView hide:YES afterDelay:1.5];
                                    };
                                    [presentWindow.rootViewController presentViewController:shareVC animated:YES completion:nil];
                                }
                                else
                                {
                                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"share_guid_url" message:share_guid_url delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
                                    [alert show];
                                }
                            }
                        }
                    });
             }];
        }
    } cancelButtonTitle:shLocalizedString(@"STREETHAWK_CANCEL", @"Cancel") otherButtonTitles:nil];
    if ([MFMessageComposeViewController canSendText])
    {
        [channelsView addButtonWithTitle:shLocalizedString(@"STREETHAWK_Growth_Channel_SMS", @"SMS")];
    }
    if ([MFMailComposeViewController canSendMail])
    {
        [channelsView addButtonWithTitle:shLocalizedString(@"STREETHAWK_Growth_Channel_Email", @"Email")];
    }
    if ([SLComposeViewController isAvailableForServiceType:SLServiceTypeFacebook])
    {
        [channelsView addButtonWithTitle:shLocalizedString(@"STREETHAWK_Growth_Channel_Facebook", @"Facebook")];
    }
    if ([SLComposeViewController isAvailableForServiceType:SLServiceTypeTwitter])
    {
        [channelsView addButtonWithTitle:shLocalizedString(@"STREETHAWK_Growth_Channel_Twitter", @"Twitter")];
    }
    if ([SLComposeViewController isAvailableForServiceType:SLServiceTypeSinaWeibo])
    {
        [channelsView addButtonWithTitle:shLocalizedString(@"STREETHAWK_Growth_Channel_SinaWeibo", @"Sina Weibo")];
    }
    if ([[UIDevice currentDevice].systemVersion doubleValue] >= 7.0 && [SLComposeViewController isAvailableForServiceType:SLServiceTypeTencentWeibo]) //TencentWeibo is supported since iOS 7.0. API return YES for none-existing service type, for example `[SLComposeViewController isAvailableForServiceType:@"not exist"]` get YES, so in iOS 6 device "Tencent Weibo" button still show. It does not make sense. To avoid this issue, add systemVersion >= 7.
    {
        [channelsView addButtonWithTitle:shLocalizedString(@"STREETHAWK_Growth_Channel_TencentWeibo", @"Tencent Weibo")];
    }
    [channelsView show];
}

- (void)registerGrowth:(SHCallbackHandler)handler;
{
    if (StreetHawk.currentInstall == nil)
    {
        if (handler)
        {
            handler(nil, [NSError errorWithDomain:SHErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey: @"StreetHawk isn't installed successfully for Growth register."}]);
        }
        return;
    }
    //Growth register happen only once in each fresh install. It checks after install/register and install/update.
    if (self.isGrowthRegistered)
    {
        if (handler)
        {
            handler(nil, nil);
        }
        return;
    }
    self.isGrowthRegistered = YES;
    NSAssert(StreetHawk.currentInstall.suid != nil && StreetHawk.currentInstall.suid.length > 0, @"Install id not ready for Growth register.");
    NSMutableDictionary *dictParam = [NSMutableDictionary dictionary];
    [dictParam setObject:@"iOS" forKey:@"os"];
    [dictParam setObject:NONULL(StreetHawk.appKey) forKey:@"app_key"];
    [dictParam setObject:NONULL([UIDevice currentDevice].systemVersion)  forKey:@"version"];
    [dictParam setObject:NONULL([UIDevice currentDevice].model) forKey:@"device"];
    [dictParam setObject:@([[UIScreen mainScreen] bounds].size.width * [[UIScreen mainScreen] scale]) forKey:@"width"];
    [dictParam setObject:@([[UIScreen mainScreen] bounds].size.height * [[UIScreen mainScreen] scale]) forKey:@"height"];
    [dictParam setObject:NONULL([UIDevice currentDevice].identifierForVendor.UUIDString) forKey:@"installid"];
    [dictParam setObject:NONULL(StreetHawk.currentInstall.suid) forKey:@"sh_cuid"];
    [dictParam setObject:@([[NSTimeZone localTimeZone] secondsFromGMT]/60) forKey:@"timezone"];
    handler = [handler copy];
    [[SHHTTPSessionManager sharedInstance] GET:[NSMutableString stringWithFormat:@"%@/i/", GrowthServer] hostVersion:SHHostVersion_Unknown parameters:dictParam success:^(NSURLSessionDataTask * _Nullable task, id  _Nullable responseObject)
    {
        if (handler)
        {
            NSAssert([responseObject isKindOfClass:[NSDictionary class]], @"Growth register expect NSDictionary, but get %@.", responseObject);
            if ([responseObject isKindOfClass:[NSDictionary class]])
            {
                NSDictionary *dict = (NSDictionary *)responseObject;
                handler(dict, nil);
            }
            else
            {
                NSError *error = [NSError errorWithDomain:SHErrorDomain code:INT_MIN userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Growth register expect NSDictionary, but get %@.", responseObject]}];
                handler(nil, error);
            }
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nullable error)
    {
        //self.isGrowthRegistered = NO; //this time register fail, do it next time. //Server side throw error when meet duplication, and client side cannot retry.
        if (handler)
        {
            handler(nil, error);
        }
    }];
}

- (void)increaseGrowth:(NSString *)shareUrlStr withHandler:(SHCallbackHandler)handler
{
    if (StreetHawk.currentInstall == nil)
    {
        if (handler)
        {
            handler(nil, [NSError errorWithDomain:SHErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey: @"StreetHawk isn't installed successfully for Growth increase."}]);
        }
        return;
    }
    NSURL *shareUrl = [NSURL URLWithString:shareUrlStr];
    if (shareUrl == nil)
    {
        if (handler)
        {
            handler(nil, [NSError errorWithDomain:SHErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Growth increase meet invalid share url %@.", shareUrlStr]}]);
        }
        return;
    }
    //parse for "share_guid_url" in url
    NSString *share_guid_url = nil;
    NSDictionary *dictQuery = shParseGetParamStringToDict(shareUrl.query);  //it convert key and value to raw string from encoding too.
    if (dictQuery != nil && [dictQuery isKindOfClass:[NSDictionary class]] && [dictQuery.allKeys containsObject:@"share_guid_url"])
    {
        share_guid_url = dictQuery[@"share_guid_url"];
    }
    if (![share_guid_url isKindOfClass:[NSString class]] || shStrIsEmpty(share_guid_url))
    {
        if (handler)
        {
            handler(nil, nil);
        }
        return; //not from Growth deeplinking, cannot find Growth identifier, just ignore.
    }
    NSAssert(StreetHawk.currentInstall.suid != nil && StreetHawk.currentInstall.suid.length > 0, @"Install id not ready for Growth increase.");
    NSMutableDictionary *dictParam = [NSMutableDictionary dictionary];
    [dictParam setObject:NONULL(StreetHawk.currentInstall.suid) forKey:@"sh_cuid"];
    [dictParam setObject:NONULL(share_guid_url) forKey:@"share_guid_url"];
    [dictParam setObject:NONULL(shareUrl.scheme) forKey:@"scheme"];
    NSString *uri =  shareUrl.resourceSpecifier;
    if ([uri hasPrefix:@"//"])
    {
        uri = [uri substringFromIndex:2];
    }
    [dictParam setObject:NONULL(uri) forKey:@"uri"];    
    handler = [handler copy];
    //Not need to consider offline mode. If device is offline short link cannot redirect to full link and will not pass above check.
    [[SHHTTPSessionManager sharedInstance] POST:[NSString stringWithFormat:@"%@/increase_clicks/", GrowthServer] hostVersion:SHHostVersion_Unknown body:dictParam success:^(NSURLSessionDataTask * _Nullable task, id  _Nullable responseObject)
    {
        if (handler)
        {
            handler(responseObject, nil);
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nullable error)
    {
        if (handler)
        {
            handler(nil, error);
        }
    }];
}

#pragma mark - private functions

- (void)installRegistrationSucceededForGrowth:(NSNotification *)notification
{
    [self handleGrowthRegister];
}

- (void)installUpdateSucceededForGrowth:(NSNotification *)notification
{
    [self handleGrowthRegister];
}

- (void)handleGrowthRegister
{
    [[SHGrowth sharedInstance] registerGrowth:^(NSObject *result, NSError *error) //Growth register automatically after install/register or install/upate.
     {
         if (result == nil)
         {
             return; //nothing to open, usually because have registered already.
         }
         SHLog(@"Growth register try to open: %@.", result);
         if (error == nil && result != nil && [result isKindOfClass:[NSDictionary class]])
         {
             NSDictionary *dictResult = (NSDictionary *)result;
             if ([dictResult.allKeys containsObject:@"message"] && [dictResult[@"message"] isKindOfClass:[NSDictionary class]])
             {
                 NSDictionary *dictMessage = dictResult[@"message"];
                 if ([dictMessage.allKeys containsObject:@"scheme"] && [dictMessage[@"scheme"] isKindOfClass:[NSString class]] && [dictMessage.allKeys containsObject:@"uri"] && [dictMessage[@"uri"] isKindOfClass:[NSString class]])
                 {
                     NSString *deeplinkingUrl = [NSString stringWithFormat:@"%@://%@", dictMessage[@"scheme"], dictMessage[@"uri"]];
                     dispatch_async(dispatch_get_main_queue(), ^
                        {
                            BOOL handledBySDK = NO;
                            if (StreetHawk.developmentPlatform == SHDevelopmentPlatform_Native || StreetHawk.developmentPlatform == SHDevelopmentPlatform_Xamarin)
                            {
                                NSString *command = [NSURL URLWithString:deeplinkingUrl].host;
                                if (command != nil && [command compare:@"launchvc" options:NSCaseInsensitiveSearch] == NSOrderedSame)
                                {
                                    SHDeepLinking *deepLinkingObj = [[SHDeepLinking alloc] init];
                                    handledBySDK = [deepLinkingObj launchDeepLinkingVC:deeplinkingUrl withPushData:nil increaseGrowthClick:NO];
                                    if (handledBySDK)
                                    {
                                        SHLog(@"Growth launch %@ successfully by StreetHawk SDK.", deeplinkingUrl);
                                        return;
                                    }
                                }
                            }
                            if (!handledBySDK && StreetHawk.openUrlHandler != nil)
                            {
                                //not increase Growth click in this case when Growth just registered.
                                StreetHawk.openUrlHandler([NSURL URLWithString:deeplinkingUrl]);
                                SHLog(@"Growth handle %@ by openUrlHandler.", deeplinkingUrl);
                            }
                            else
                            {
                                SHLog(@"Growth url %@ not find suitable way to launch.", deeplinkingUrl);
                            }
                        });
                 }
             }
         }
     }];
}

#pragma mark - MFMessageComposeViewControllerDelegate

- (void)messageComposeViewController:(MFMessageComposeViewController *)controller didFinishWithResult:(MessageComposeResult)result
{
    if (result != MessageComposeResultFailed)
    {
        [controller dismissViewControllerAnimated:YES completion:nil];
    }
}

#pragma mark - MFMailComposeViewControllerDelegate

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    if (!error)
    {
        [controller dismissViewControllerAnimated:YES completion:nil];
    }
}

@end
