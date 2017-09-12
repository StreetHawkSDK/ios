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

#import "AppDelegate.h"
#import "SampleCaseViewController.h"
#import "AppKeyChoiceViewController.h"

#import <StreetHawkCore/StreetHawkCore.h>

#define SH_APPKEY   @"SH_APPKEY"

@interface MyHandler : NSObject<ISHCustomiseHandler, UIActionSheetDelegate>

@property (nonatomic, copy) ClickButtonHandler callbackHandler;

@end

@interface AppDelegate ()

- (void)installRegisterSuccessHandler:(NSNotification *)notification;

@end


@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    SampleCaseViewController *sampleCaseVC = [[SampleCaseViewController alloc] initWithStyle:UITableViewStylePlain];
    UINavigationController *navigationVC = [[UINavigationController alloc] initWithRootViewController:sampleCaseVC];
    navigationVC.navigationBar.translucent = NO;
    
    self.window.rootViewController = navigationVC;
    [self.window makeKeyAndVisible];
    
    NSString *appKey = [[NSUserDefaults standardUserDefaults] objectForKey:SH_APPKEY];
    if (appKey.length == 0)
    {
        AppKeyChoiceViewController *appKeyListVC = [[AppKeyChoiceViewController alloc] initWithStyle:UITableViewStyleGrouped];
        UINavigationController *navigationAppKeyListVC = [[UINavigationController alloc] initWithRootViewController:appKeyListVC];
        appKeyListVC.selectedCallback = ^(NSString *selectedAppKey)
        {
            [[NSUserDefaults standardUserDefaults] setObject:selectedAppKey forKey:SH_APPKEY];
            [[NSUserDefaults standardUserDefaults] synchronize];
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"AppKey is setup. Restart App to take effect."
                                                                                     message:@"Click \"OK\" to close App."
                                                                              preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *action = [UIAlertAction actionWithTitle:@"OK"
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * _Nonnull action) {
                                                               exit(0); //kill App
                                                           }];
            [alertController addAction:action];
            [navigationAppKeyListVC presentViewController:alertController animated:YES completion:nil];
        };
        [self.window.rootViewController presentViewController:navigationAppKeyListVC animated:YES completion:nil];
        return YES; //need to kill and restart
    }
    //Manually test delay asking for system notification.
    //    StreetHawk.isDefaultNotificationEnabled = NO;
    //    StreetHawk.notificationTypes = UIRemoteNotificationTypeAlert;
    //    StreetHawk.isDefaultLocationServiceEnabled = NO;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(installRegisterSuccessHandler:) name:SHInstallRegistrationSuccessNotification object:nil];
    [StreetHawk registerInstallForApp:appKey withDebugMode:YES];
    
    //Sample code to register some friendly names which will be used in push notification 8004/8006/8007.
    SHFriendlyNameObject *name1 = [[SHFriendlyNameObject alloc] init]; //Match friendly name "login" to a vc, to test push notification 8007
    SHFriendlyNameObject *name2 = [[SHFriendlyNameObject alloc] init]; //Match friendly name "register" to a vc, to test push notification 8006
    SHFriendlyNameObject *name3 = [[SHFriendlyNameObject alloc] init]; //Sample for use friendly name.
    SHFriendlyNameObject *name4 = [[SHFriendlyNameObject alloc] init]; //Sample for use friendly name and deeplinking.
    name1.friendlyName = FRIENDLYNAME_LOGIN;
    name1.vc = @"LogTagCasesViewController";
    name2.friendlyName = FRIENDLYNAME_REGISTER;
    name2.vc = @"LogTagCasesViewController";
    name3.friendlyName = @"Input iBeacon region";
    name3.vc = @"BeaconRegionInputViewController";
    name3.xib_iphone = @"BeaconRegionInputViewController";
    name4.friendlyName = @"Deep Linking";
    name4.vc = @"DeepLinkingViewController";
    name4.xib_iphone = @"DeepLinkingViewController";
    name4.xib_ipad = @"DeepLinkingViewController";
    [StreetHawk shCustomActivityList:@[name1, name2, name3, name4]];
    
    //Sample code to handle customer notification.
    MyHandler *handler = [[MyHandler alloc] init];
    [StreetHawk shSetCustomiseHandler:handler];
    
    //Sample code to handle open url.
    StreetHawk.openUrlHandler = ^(NSURL *openUrl)
    {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Open url handler" message:openUrl.absoluteString delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alertView show];
    };
    
    //Sample code to handle fetch feeds.
    StreetHawk.newFeedHandler = ^
    {
        NSLog(@"Find new feeds.");
    };
    
    //Sample code to add spotlight search item
    if ([[UIDevice currentDevice].systemVersion doubleValue] >= 9.0)
    {
        [StreetHawk indexSpotlightSearchForIdentifier:@"1" forDeeplinking:@"hawk://testsearch?id=12" withSearchTitle:@"An interesting restaurant for kids." withSearchDescription:@"It has many toys for kids, \nand the table is colorful." withThumbnail:[UIImage imageNamed:@"icon.png"] withKeywords:@[@"child", @"play"]];
    }
    
    //Sample code to set interactive pair buttons
    InteractivePush *pair1 = [[InteractivePush alloc] initWithPairTitle:@"MyPair1" withButton1:@"Facebook" withButton2:@"Twitter"];
    InteractivePush *pair2 = [[InteractivePush alloc] initWithPairTitle:@"MyPair2" withButton1:@"Invite" withButton2:@"Send Photo"];
    InteractivePush *pair3 = [[InteractivePush alloc] initWithPairTitle:@"MyPair3" withButton1:@"Lost" withButton2:@"Found"];
    [StreetHawk setInteractivePushBtnPairs:@[pair1, pair2, pair3]];
    
    return YES;
}

- (void)installRegisterSuccessHandler:(NSNotification *)notification
{
    dispatch_async(dispatch_get_main_queue(), ^ {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Choose one to tag sh_cuid."
                                                                                 message:nil
                                                                          preferredStyle:UIAlertControllerStyleAlert];
        //promote choice list to tag sh_cuid.
        NSArray *tagChoice = @[@"david",
                               @"nick",
                               @"christine",
                               @"yichang",
                               @"steven",
                               @"linda",
                               @"QA"];
        for (NSString *choice in tagChoice)
        {
            UIAlertAction *actionTag = [UIAlertAction actionWithTitle:choice
                                                               style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction * _Nonnull action) {
                                                                 NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                                                                 [dateFormatter setDateFormat:@"MM-dd HH:mm"];
                                                                 NSString *dateStr = [dateFormatter stringFromDate:[NSDate date]];
                                                                 NSString *person = [NSString stringWithFormat:@"%@ %@", choice, dateStr];
                                                                 [StreetHawk tagCuid:person];
                                                                 UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:@"Tag %@ to sh_cuid", person] message:nil delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                                                                 [alertView show];
                                                             }];
            [alertController addAction:actionTag];
        }
        UIAlertAction *actionCancel = [UIAlertAction actionWithTitle:@"Not tag any person"
                                                               style:UIAlertActionStyleCancel
                                                             handler:nil];
        [alertController addAction:actionCancel];
        [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alertController animated:YES completion:nil];
    });
}

@end

@implementation MyHandler

#pragma mark - override functions

- (void)shRawJsonCallbackWithTitle:(NSString *)title withMessage:(NSString *)message withJson:(NSString *)json
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:@"%@, %@", title, message] message:json delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alertView show];
}

- (BOOL)onReceive:(PushDataForApplication *)pushData clickButton:(ClickButtonHandler)handler
{
    self.callbackHandler = handler; //keep callback handler, will used in custom dialog event.
//    if (pushData.action == SHAction_OpenUrl)
//    {
//        UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:@"Show my own confirm dialog" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"Go on", nil];
//        [actionSheet showInView:[UIApplication sharedApplication].windows[0]];
//        return YES; //only SHAction_OpenUrl use custom dialog, others keep StreetHawk's.
//    }
    return NO; //others not affected
}

- (void)onReceiveResult:(PushDataForApplication *)pushData withResult:(SHResult)result
{
//    if (pushData.isAppOnForeground) //UI action only happen when App in FG
//    {
//        if (pushData.action == SHAction_OpenUrl && result == SHResult_Decline)
//        {
//            [StreetHawk shFeedback:@[@"Not like the URL", @"The message is annoying", @"I am busy"] needInputDialog:NO needConfirmDialog:YES withTitle:@"Why decine the message?" withMessage:nil withPushData:nil];
//        }
//    }
}

#pragma mark - delegate handler

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(buttonIndex != actionSheet.cancelButtonIndex)
    {
        if (self.callbackHandler)
        {
            self.callbackHandler(SHResult_Accept); //notify streethawk to continue in positive way
        }
    }
    else
    {
        if (self.callbackHandler)
        {
            self.callbackHandler(SHResult_Decline); //notify streethawk to continue in negative way
        }
    }
}

@end
