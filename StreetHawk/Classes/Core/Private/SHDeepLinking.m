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

#import "SHDeepLinking.h"
//header from StreetHawk
#import "SHApp.h"  //for StreetHawk
#import "SHUtils.h" //for streetHawkIsEnabled()
#import "SHFriendlyNameObject.h"  //for friendly name parse
#import "PushDataForApplication.h" //for pushData
#import "SHBaseViewController.h" //for `ISHDeepLinking` protocol
#import "SHHTTPSessionManager.h" //for set header "X-Install-Token"
//header from System
#import <UIKit/UIKit.h>

#define COMMAND_LAUNCHVC        @"launchvc"
#define COMMAND_POINTZI_AUTHOR  @"pointzi_author"

@interface SHDeepLinking ()

/**
 Create a new view controller according to pass in `deepLinking` and show it if current visible page is not this one, or this one has parameters to set. If current has navigation controller, push in navigation stack; otherwise show in modal way. This function is used for:
 
 1. Notification 8004 to launch a VC and show certain parameters.
 2. Open URl to launch a VC and show certain parameters.
 
 Note: this function only works on native App, not work for Phonegap, Titanium. Xamarin maps to native UIViewController so works.
 
 @param deepLinking The string indicates many information for how to launch the VC. Possible formats:
 
 1. a friendly name that you will look up in your dictionary of registered vcs/xibs.
 2. a string like <vc>.
 3. a string like <vc>:<xib_iphone>:<xib_ipad>
 4. a string like <vc>::<xib_ipad> (xib_iphone is missing but xib_ipad is interpreted correctly)
 
 above are old formats without deeplinking parameters, keep them for compatibility.
 
 5. URL like <scheme>://<path>?vc=<friendly name or vc>&xib_iphone=<xib_iphone>&xib_ipad=<xib_ipad>&<additional params>
 6. parameter part of above, like vc=<friendly name or vc>&xib_iphone=<xib_iphone>&xib_ipad=<xib_ipad>&<additional params>
 
 All above formats finally will parse to following elements:
 
 * view class name: Mandatory. The name of the subclass of UIViewController, for example: @"MyViewController". If it's empty, or it's typo and cannot create the VC, return NO.
 * iPhoneXib: Optional. The xib name for the page in iPhone, for example "MyViewController_iPhone". If it uses same name as `vcClassName`, use nil.
 * iPadXib: Optional. The xib name for the page in iPad, for example "MyViewController_iPad". If it uses same name as `vcClassName`, use nil.
 * dictParam: The key-value pair of deeplinking parameters, besides above elements for creating VC, it may have more custom param to pass to the page.
 
 @param pushData The payload information from notification. If not used for notification pass nil.
 @param shouldIncreaseClick Whether should try to increase Growth click_count for this deeplinking open.
 @return If successfully create VC, return YES; otherwise, return NO.
 */
- (BOOL)launchDeepLinkingVC:(NSString *)deepLinking withPushData:(PushDataForApplication *)pushData increaseGrowthClick:(BOOL)shouldIncreaseClick;

- (NSString *)formatXib:(NSString *)xib;  //format input string to match xib name requirement.
- (UIViewController *)viewcontroller:(UIViewController *)vc containsSubviewcontroller:(NSString *)subVCName;  //recursive to find whether this vc contains a subview for the name.

@end

@implementation SHDeepLinking

- (BOOL)isSupportedDeeplinkingUrl:(NSURL *)deeplinking
{
    NSString *command = deeplinking.host;
    return (command != nil
            &&( [command compare:COMMAND_LAUNCHVC options:NSCaseInsensitiveSearch] == NSOrderedSame
                || [command compare:COMMAND_POINTZI_AUTHOR options:NSCaseInsensitiveSearch] == NSOrderedSame));
}

- (BOOL)processDeeplinkingUrl:(NSURL *)deeplinking withPushData:(PushDataForApplication *)pushData withIncreaseGrowth:(BOOL)increaseGrowth
{
    NSString *command = deeplinking.host;
    if (command != nil && [command compare:COMMAND_LAUNCHVC options:NSCaseInsensitiveSearch] == NSOrderedSame) //launch vc
    {
        SHLog(@"Deeplinking process do launch vc: %@.", deeplinking.absoluteString);
        if (StreetHawk.developmentPlatform == SHDevelopmentPlatform_Native
            || StreetHawk.developmentPlatform == SHDevelopmentPlatform_Xamarin) //automatically launch vc only available for native and xamarin
        {
            BOOL isHandled = [self launchDeepLinkingVC:deeplinking.absoluteString withPushData:pushData increaseGrowthClick:increaseGrowth];
            if (isHandled)
            {
                return YES; //launchvc deeplinking is handled by StreetHawk
            }
        }
    }
    else if (command != nil && [command compare:COMMAND_POINTZI_AUTHOR options:NSCaseInsensitiveSearch] == NSOrderedSame) //pointzi author
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PointziBridge_Deeplinking_Notification"
                                                            object:nil
                                                          userInfo:@{@"url": NONULL(deeplinking.absoluteString)}];
        return YES;
    }
    return NO;
}

- (BOOL)launchDeepLinkingVC:(NSString *)deepLinking withPushData:(PushDataForApplication *)pushData increaseGrowthClick:(BOOL)shouldIncreaseClick
{
    if (!streetHawkIsEnabled())
    {
        return NO;
    }
    if (deepLinking == nil || deepLinking.length == 0)
    {
        return NO; //no need to continue
    }
    
    if (shouldIncreaseClick)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_GrowthBridge_Increase_Notification" object:nil userInfo:@{@"url": NONULL(deepLinking)}]; //send Growth increase request
    }
    
    NSString *vcClassName = nil;
    NSString *iPhoneXib = nil;
    NSString *iPadXib = nil;
    NSDictionary *dictParam = nil;
    //1. a friendly name that you will look up in your dictionary of registered vcs/xibs.
    //2. a string like <vc>.
    //3. a string like <vc>:<xib_iphone>:<xib_ipad>
    //4. a string like <vc>::<xib_ipad> (xib_iphone is missing but xib_ipad is interpreted correctly)
    //5. URL like <scheme>://<path>?vc=<friendly name or vc>&xib_iphone=<xib_iphone>&xib_ipad=<xib_ipad>&<additional params>
    //6. parameter part of above, like vc=<friendly name or vc>&xib_iphone=<xib_iphone>&xib_ipad=<xib_ipad>&<additional params>
    if ([deepLinking rangeOfString:@"://"].location != NSNotFound) //case 5
    {
        NSURL *url = [NSURL URLWithString:deepLinking]; //try to get URL, if format fail it may return nil.
        if (url != nil)
        {
            deepLinking = url.query; //only need key1=value1&key2=value2 part, convert to case 6.
        }
        else
        {
            //for some reason fail to create url and use NSURL function to get parameter string, anyway try to separate by "?", try the best to launch.
            NSInteger separatorIndex = [deepLinking rangeOfString:@"?"].location;
            if (separatorIndex != NSNotFound && separatorIndex < deepLinking.length)
            {
                deepLinking = [deepLinking substringFromIndex:separatorIndex + 1];
            }
        }
    }
    if (deepLinking.length == 0) //not check :// and ?, because share_guid_url may contain them in query string.
    {
        return NO; //format is error
    }
    BOOL hasAdditionalParam = NO;
    BOOL reuseDeeplinking = NO;
    if ([deepLinking rangeOfString:@"="].location != NSNotFound)
    {
        dictParam = shParseGetParamStringToDict(deepLinking);  //case 6
        for (NSString *key in dictParam.allKeys)
        {
            if ([key compare:@"vc" options:NSCaseInsensitiveSearch] == NSOrderedSame)
            {
                vcClassName = dictParam[key];
            }
            else if ([key compare:@"xib_iphone" options:NSCaseInsensitiveSearch] == NSOrderedSame)
            {
                iPhoneXib = dictParam[key];
            }
            else if ([key compare:@"xib_ipad" options:NSCaseInsensitiveSearch] == NSOrderedSame)
            {
                iPadXib = dictParam[key];
            }
            else
            {
                if ([key compare:@"reuse" options:NSCaseInsensitiveSearch] == NSOrderedSame)
                {
                    reuseDeeplinking = ([dictParam[key] intValue] != 0);
                }
                hasAdditionalParam = YES;
            }
        }
    }
    else
    {
        if ([deepLinking rangeOfString:@":"].location != NSNotFound)  //case 3 and 4
        {
            NSInteger loc1 = [deepLinking rangeOfString:@":"].location;
            if (loc1 >= 0 && loc1 < deepLinking.length)
            {
                vcClassName = [deepLinking substringToIndex:loc1];
                NSInteger loc2 = [deepLinking rangeOfString:@":" options:0 range:NSMakeRange(loc1 + 1, deepLinking.length - loc1 - 1)].location;
                if (loc2 > loc1 && loc2 < deepLinking.length)
                {
                    iPhoneXib = [deepLinking substringWithRange:NSMakeRange(loc1 + 1, loc2 - loc1 - 1)];
                    iPadXib = [deepLinking substringFromIndex:loc2 + 1];
                }
            }
        }
        else //case 1 and 2
        {
            vcClassName = deepLinking;
        }
    }
    //vcClassName may be friendly name, try to find in friendly names.
    SHFriendlyNameObject *findObj = [SHFriendlyNameObject findObjByFriendlyName:vcClassName];
    if (findObj != nil)
    {
        vcClassName = findObj.vc;
        iPhoneXib = findObj.xib_iphone;
        iPadXib = findObj.xib_ipad;
    }
    //finish parse deeplinking string, it's time to create VC.
    if (vcClassName == nil || vcClassName.length == 0 || ![vcClassName isKindOfClass:[NSString class]])
    {
        return NO;
    }
    Class vcClass = NSClassFromString(vcClassName);
    if (![vcClass isSubclassOfClass:[UIViewController class]]) //first make sure the vc can be created successfully
    {
        //Directly use class name fail, try Swift project way: AppName.VCClassName
        NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
        NSString *fullName = [NSString stringWithFormat:@"%@.%@", appName, vcClassName];
        vcClass = NSClassFromString(fullName);
        if (![vcClass isSubclassOfClass:[UIViewController class]])
        {
            //Last try mixed Swift project way: _TtC[app name length][app name][class name length][class name]
            fullName = [NSString stringWithFormat:@"_TtC%lu%@%lu%@", (unsigned long)appName.length, appName, (unsigned long)vcClassName.length, vcClassName];
            vcClass = NSClassFromString(fullName);
            if (![vcClass isSubclassOfClass:[UIViewController class]])
            {
                return NO;
            }
        }
    }
    //check this VC is already show. If not have parameter and already show, stop; if have parameter, check reuse to decide create new vc or not.
    UIViewController *visibleVC = nil;
    for (UIWindow *window in [UIApplication sharedApplication].windows)
    {
        if (!window.isHidden/*hidden window covers in demo App*/ && [NSStringFromClass(window.class) isEqual:@"UIWindow"]/*when confirm dialog promote there is a `UITextEffectsWindow` window*/)
        {
            UIViewController *rootVC = window.rootViewController;
            if ([NSStringFromClass(rootVC.class) isEqualToString:vcClassName])
            {
                visibleVC = rootVC;
                break;
            }
            UIViewController *subVC = [self viewcontroller:rootVC containsSubviewcontroller:vcClassName];
            if (subVC != nil)
            {
                visibleVC = subVC;
                break;
            }
            UINavigationController *navigationVC = nil;
            if ([rootVC isKindOfClass:[UINavigationController class]])
            {
                navigationVC = (UINavigationController *)rootVC;
            }
            else if (rootVC.navigationController != nil)
            {
                navigationVC = rootVC.navigationController;
            }
            if (navigationVC != nil)
            {
                if ([NSStringFromClass(navigationVC.visibleViewController.class) isEqualToString:vcClassName])
                {
                    visibleVC = navigationVC.visibleViewController;
                    break;
                }
                UIViewController *subVC = [self viewcontroller:navigationVC.visibleViewController containsSubviewcontroller:vcClassName];
                if (subVC != nil)
                {
                    visibleVC = subVC;
                    break;
                }
            }
        }
    }
    if (visibleVC != nil && !hasAdditionalParam)
    {
        //user actually viewed the page, should send pushresult=1.
        [pushData sendPushResult:SHResult_Accept withHandler:nil];
        //Requested by Tobias and Anurag, even user is already viewing the page, should still show message box, maybe the message box contains some information that user should read.
        if ([pushData shouldShowConfirmDialog])
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PushBridge_HandlePushData" object:nil userInfo:@{@"pushdata": pushData}];
        }
        return YES;  //already visible, not continue to create and show
    }
    UIViewController *launchVC = nil;
    BOOL shouldOpenNewPage = YES;
    if (visibleVC != nil && reuseDeeplinking)
    {
        launchVC = visibleVC;
        shouldOpenNewPage = NO;
    }
    else
    {
        iPhoneXib = [self formatXib:iPhoneXib];
        iPadXib = [self formatXib:iPadXib];
        if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone)
        {
            if (iPhoneXib == nil && [vcClass isSubclassOfClass:[UITableViewController class]])
            {
                launchVC = [(UITableViewController *)[vcClass alloc] initWithStyle:UITableViewStylePlain];
            }
            else
            {
                launchVC = [(UIViewController *)[vcClass alloc] initWithNibName:iPhoneXib bundle:nil];
            }
        }
        else
        {
            if (iPadXib == nil && [vcClass isSubclassOfClass:[UITableViewController class]])
            {
                launchVC = [(UITableViewController *)[vcClass alloc] initWithStyle:UITableViewStylePlain];
            }
            else
            {
                launchVC = [(UIViewController *)[vcClass alloc] initWithNibName:iPadXib bundle:nil];
            }
        }
        if (launchVC == nil)  //fail to create vc.
        {
            return NO;
        }
    }
    dispatch_block_t action = ^
    {
        //close all overlap view
        shDismissAllMessageView();
        //setup deeplinking parameters. It's done before show launch VC UI, customer App must hold this data inside, and when App launch show it to UI.
        //not check [launchVC conformsToProtocol:@protocol(ISHDeepLinking)], as Xamarin not use protocol due to C# not support multiple inheritance, and use weak delegate. Check respond to selector is enough.
        if ([launchVC respondsToSelector:@selector(receiveDeepLinkingData:)]/*optional protocol, must check real imp*/)
        {
            id<ISHDeepLinking> deepLinkingVC = (id<ISHDeepLinking>)launchVC;
            [deepLinkingVC receiveDeepLinkingData:dictParam];
        }
        if (shouldOpenNewPage)
        {
            //if current has navigation, push in navigation stack; otherwise show as modal.
            UIViewController *rootVC = shGetPresentWindow().rootViewController;
            NSAssert(rootVC != nil, @"Not find suitable root view controller.");
            UINavigationController *navigationVC = nil;
            if ([rootVC isKindOfClass:[UINavigationController class]])
            {
                navigationVC = (UINavigationController *)rootVC;
            }
            else if (rootVC.navigationController != nil)
            {
                navigationVC = rootVC.navigationController;
            }
            if (navigationVC != nil)
            {
                [navigationVC pushViewController:launchVC animated:YES];
            }
            else
            {
                [rootVC presentViewController:launchVC animated:YES completion:nil];
            }
        }
    };
    if ([pushData shouldShowConfirmDialog])
    {
        NSMutableDictionary *dictUserInfo = [NSMutableDictionary dictionary];
        dictUserInfo[@"pushdata"] = pushData;
        dictUserInfo[@"clickbutton"] = ^(SHResult result)
        {
            if (result == SHResult_Accept)
            {
                action();
            }
            [pushData sendPushResult:result withHandler:nil];
        };
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PushBridge_HandlePushData" object:nil userInfo:dictUserInfo];
    }
    else
    {
        action();
        [pushData sendPushResult:SHResult_Accept withHandler:nil];
    }
    return YES;
}

#pragma mark - private functions

- (NSString *)formatXib:(NSString *)xib
{
    if (xib != nil)
    {
        if ([xib isKindOfClass:[NSString class]])
        {
            xib = [xib stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (xib.length == 0)
            {
                return nil;
            }
        }
        else
        {
            return nil; //not string, just return nil
        }
    }
    return xib;
}

- (UIViewController *)viewcontroller:(UIViewController *)vc containsSubviewcontroller:(NSString *)subVCName
{
    for (UIView *subView in vc.view.subviews)
    {
        UIViewController *subVC = shGetViewController(subView);
        if (subVC == vc)  //shGetViewController uses responder, and it can find parent vc cause dead loop.
        {
            return nil;
        }
        if ([NSStringFromClass(subVC.class) isEqualToString:subVCName])
        {
            return subVC;
        }
        return [self viewcontroller:subVC containsSubviewcontroller:subVCName];
    }
    return nil;
}

@end
