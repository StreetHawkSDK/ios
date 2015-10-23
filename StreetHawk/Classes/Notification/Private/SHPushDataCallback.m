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

#import "SHPushDataCallback.h"
//header from StreetHawk
#import "SHUtils.h" //for appendString
#import "SHAlertView.h" //for confirm dialog
//header from System
#import <UIKit/UIKit.h>

@implementation SHPushDataCallback

#pragma mark - override functions

- (BOOL)onReceive:(PushDataForApplication *)pushData clickButton:(ClickButtonHandler)handler
{
    if (pushData.action == SHAction_CheckAppStatus)
    {
        if (handler) //Check app status directly process, not show confirm dialog
        {
            handler(SHResult_Accept);
        }
    }
    else if (pushData.action == SHAction_SimplePrompt)
    {
        //check alert is long to show dialog even from BG
        BOOL isAlertLong = NO;
        if (!pushData.isAppOnForeground) //calculate it only for from BG.
        {
            NSString *alertBanner = shAppendString(pushData.title, pushData.message);
            if (alertBanner != nil && alertBanner.length > 0)
            {
                float screenWidth = [UIScreen mainScreen].bounds.size.width; //here just roughly guess, iPad/iPhone6+ may rotate so actually banner in height, but iOS8 also consider rotate, thus simply use "width" here.
                UIFont *notificationFont = [UIFont systemFontOfSize:14]; //also guess
                CGSize lineSize = [[alertBanner substringToIndex:1] sizeWithAttributes:@{NSFontAttributeName:notificationFont}];
                CGRect alertSize = [alertBanner boundingRectWithSize:CGSizeMake(screenWidth, 1000/*enough to wrapper*/) options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading) attributes:@{NSFontAttributeName:notificationFont} context:nil];
                if (alertSize.size.height > lineSize.height * 2 + 10/*margin but not enough for one line*/)
                {
                    isAlertLong = YES; //alert more than 2 lines
                }
            }
        }
        if ([pushData shouldShowConfirmDialog] || isAlertLong) //App in FG normally should show, or App from BG but with long alert, need to show dialog
        {
            SHAlertView *alertView = [[SHAlertView alloc] initWithTitle:pushData.title message:pushData.message withHandler:nil cancelButtonTitle:nil otherButtonTitles:shLocalizedString(@"STREETHAWK_OKAY", @"OK"), nil];
            [alertView show];
        }
        if (!pushData.isAppOnForeground || [pushData shouldShowConfirmDialog]) //in this two cases user see the simple promote dialog.
        {
            if (handler)
            {
                handler(SHResult_Accept); //simple promote is accept once trigger.
            }
        }
    }
    else
    {
        if (handler)
        {
            NSString *positiveButton = shLocalizedString(@"STREETHAWK_YES", @"Yes Please!");
            NSString *negativeButton = shLocalizedString(@"STREETHAWK_CANCEL", @"Cancel");
            if (pushData.action == SHAction_RateApp)
            {
                positiveButton = shLocalizedString(@"STREETHAWK_RATE", @"Rate");
                negativeButton = shLocalizedString(@"STREETHAWK_LATER", @"Later");
            }
            else if (pushData.action == SHAction_LaunchActivity || pushData.action == SHAction_UserLoginScreen || pushData.action == SHAction_UserRegistrationScreen)
            {
                positiveButton = shLocalizedString(@"STREETHAWK_OPEN", @"Open");
            }
            SHAlertView *alertView = [[SHAlertView alloc] initWithTitle:pushData.title message:pushData.message withHandler:^(UIAlertView *view, NSInteger buttonIndex)
              {
                  if (buttonIndex != view.cancelButtonIndex)
                  {
                      if (handler)
                      {
                          handler(SHResult_Accept);
                      }
                  }
                  else
                  {
                      if (handler)
                      {
                          if (pushData.action == SHAction_RateApp)
                          {
                              handler(SHResult_Postpone);
                          }
                          else
                          {
                              handler(SHResult_Decline);
                          }
                      }
                  }
              } cancelButtonTitle:negativeButton otherButtonTitles:positiveButton, nil];
            [alertView show];
        }
        else
        {
            //used for deeplinking view already show, not pass in handler.
            SHAlertView *alertView = [[SHAlertView alloc] initWithTitle:pushData.title message:pushData.message withHandler:nil cancelButtonTitle:nil otherButtonTitles:shLocalizedString(@"STREETHAWK_OKAY", @"OK"), nil];
            [alertView show];
        }
    }
    return YES;
}

@end
