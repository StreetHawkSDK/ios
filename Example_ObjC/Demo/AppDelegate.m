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
#import "DemoViewController.h"

#import <StreetHawkCore/StreetHawkCore.h>

@interface MyHandler : NSObject<ISHCustomiseHandler, UIActionSheetDelegate>

@property (nonatomic, copy) ClickButtonHandler callbackHandler;

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    DemoViewController *sampleCaseVC = [[DemoViewController alloc] initWithStyle:UITableViewStylePlain];
    UINavigationController *navigationVC = [[UINavigationController alloc] initWithRootViewController:sampleCaseVC];
    self.window.rootViewController = navigationVC;
    [self.window makeKeyAndVisible];
    
    //Delay asking for System permission.
    //Doc: https://streethawk.freshdesk.com/solution/categories/5000158959/folders/5000254779/articles/5000609896-code-snippets#delayAskingPermission_ios_native
    //StreetHawk.isDefaultNotificationEnabled = NO; //Not enable notification by default. Later use `StreetHawk.isNotificationEnabled = YES;` to enable.
    //StreetHawk.isDefaultLocationServiceEnabled = NO; //Not enable location by default. Later use `StreetHawk.isLocationServiceEnabled = YES;` to enable.
    
    //Register install to StreetHawk server.
    [StreetHawk registerInstallForApp:@"MyFirstApp" withDebugMode:YES];
    
    //Define friendly names
    SHFriendlyNameObject *name1 = [[SHFriendlyNameObject alloc] init];
    SHFriendlyNameObject *name2 = [[SHFriendlyNameObject alloc] init];
    name1.friendlyName = @"Tag";
    name1.vc = @"TagViewController";
    name2.friendlyName = @"Deep Linking";
    name2.vc = @"DeepLinkingViewController";
    name2.xib_iphone = @"DeepLinkingViewController"; //optional, used if xib different in iPhone and iPad.
    name2.xib_ipad = @"DeepLinkingViewController";
    [StreetHawk shCustomActivityList:@[name1, name2]];
    
    //Implement handle deeplinking url by customer's own code.
    //Doc: https://streethawk.freshdesk.com/solution/categories/5000158959/folders/5000254779/articles/5000609896-code-snippets#deeplinking_ios_native
    //If not implement this, deeplinking url is handled by StreetHawk SDK in following scenarios to launch view controller automatically. If implement this customer's own code must handle the url.
    //Launch view controller in such scenarios:
    //1. Click a link "<app_scheme://host/path?param=value>" in Email or social App, launch this App by `openURL`.
    //2. Notification "Launch page activity" sends from StreetHawk campaign with deeplinking url "<app_scheme://host/path?param=value>", and host not equal "launchvc".
    //3. Growth recommend friend to install a new App, after first launch Growth automatically match a deeplinking url "<app_scheme://host/path?param=value>" and launch view controller.
    StreetHawk.openUrlHandler = ^(NSURL *openUrl)
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Please handle open url by your own code." message:openUrl.absoluteString delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
    };
    
    //Customer notification handle.
    //Doc: https://streethawk.freshdesk.com/solution/categories/5000158959/folders/5000254779/articles/5000609896-code-snippets#rawjson_ios_native
    MyHandler *handler = [[MyHandler alloc] init];
    [StreetHawk shSetCustomiseHandler:handler];
    
    //Sample code to set interactive pair buttons
    InteractivePush *pair1 = [[InteractivePush alloc] initWithPairTitle:@"MyPair1" withButton1:@"Facebook" withButton2:@"Twitter"];
    InteractivePush *pair2 = [[InteractivePush alloc] initWithPairTitle:@"MyPair2" withButton1:@"Invite" withButton2:@"Send Photo"];
    InteractivePush *pair3 = [[InteractivePush alloc] initWithPairTitle:@"MyPair3" withButton1:@"Lost" withButton2:@"Found"];
    [StreetHawk setInteractivePushBtnPairs:@[pair1, pair2, pair3]];

    return YES;
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
