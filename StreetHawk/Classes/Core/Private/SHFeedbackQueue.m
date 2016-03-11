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

#import "SHFeedbackQueue.h"
//header from StreetHawk
#import "SHHTTPSessionManager.h" //for sending request
#import "PushDataForApplication.h" //for use pushData
#import "SHUtils.h" //for format date utility
#import "SHPresentDialog.h" //for present modal dialog
#import "SHInstall.h" //for `StreetHawk.currentInstall.suid`
#import "SHLogger.h" //for send logline
#import "SHFeedbackViewController.h" //for input feedback comment
#import "SHChoiceViewController.h" //for choose feedback options
#import "SHAlertView.h" //for confirm dialog
//header from Third-party
#import "MBProgressHUD.h" //for feedback result

@interface SHFeedbackQueue ()

@property (nonatomic, strong) NSMutableArray *arrayFeedbacks;
@property (nonatomic) BOOL isProcessing; //flag indicates a feedback is processing.

- (void)handleFeedback; //pick first one from queue and handle it.
- (void)checkNextFeedback; //after one feedback is done, remove it from queue and check next one.

@end

@implementation SHFeedbackQueue

#pragma mark - life cycle

- (id)init
{
    if (self = [super init])
    {
        self.arrayFeedbacks = [NSMutableArray array];
        self.isProcessing = NO;
    }
    return self;
}

+ (id)shared
{
    static SHFeedbackQueue *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^ {
        instance = [[SHFeedbackQueue alloc] init];
    });
    return instance;
}

#pragma mark - public functions

- (void)addFeedback:(NSArray *)arrayChoice needInputDialog:(BOOL)needInput needConfirmDialog:(BOOL)needConfirm withTitle:(NSString *)infoTitle withMessage:(NSString *)infoMessage withPushData:(PushDataForApplication *)pushData
{
    //format a dictionary and append to queue
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    if (arrayChoice != nil)
    {
        dict[@"choice"] = arrayChoice;
    }
    dict[@"needInput"] = [NSNumber numberWithBool:needInput];
    dict[@"needConfirm"] = [NSNumber numberWithBool:needConfirm];
    if (infoTitle != nil)
    {
        dict[@"title"] = infoTitle;
    }
    if (infoMessage != nil)
    {
        dict[@"message"] = infoMessage;
    }
    if (pushData != nil)
    {
        dict[@"data"] = [pushData toDictionary];
    }
    [self.arrayFeedbacks addObject:dict];
    //check and handle
    [self handleFeedback];
}

- (void)submitFeedbackForTitle:(NSString *)feedbackTitle withType:(NSInteger)feedbackType withContent:(NSString *)feedbackContent withPushData:(PushDataForApplication *)pushData withShowError:(BOOL)showError withHandler:(SHCallbackHandler)handler
{
    //pushresult traces user action, no matter request succeed or fail, here means agree to post feedback.
    [pushData sendPushResult:SHResult_Accept withHandler:nil];
    NSDictionary *params = @{@"title": NONULL(feedbackTitle), @"feedback_type": @(feedbackType), @"contents": NONULL(feedbackContent), @"built_at": shFormatStreetHawkDate([NSDate date]), @"anonymous": @"no", @"installid": NONULL(StreetHawk.currentInstall.suid)};
    handler = [handler copy];
    [[SHHTTPSessionManager sharedInstance] POST:@"feedback/submit/" hostVersion:SHHostVersion_V1 body:params success:^(NSURLSessionDataTask * _Nullable task, id  _Nullable responseObject)
    {
        dispatch_async(dispatch_get_main_queue(), ^
           {
               UIWindow *presentWindow = shGetPresentWindow();
               MBProgressHUD *resultView = [MBProgressHUD showHUDAddedTo:presentWindow animated:YES];
               resultView.mode = MBProgressHUDModeText; //only show result text, not show progress bar.
               resultView.labelText = shLocalizedString(@"STREETHAWK_WINDOW_FEEDBACK_THANKS", @"Thanks for your feedback!");
               [resultView hide:YES afterDelay:1.5];
           });
        if (handler)
        {
            handler(task.currentRequest, nil);
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nullable error)
    {
        if (showError)
        {
            shPresentErrorAlert(error, YES);
        }
        if (pushData != nil && pushData.msgID != 0)
        {
            [StreetHawk sendLogForCode:LOG_CODE_ERROR withComment:[NSString stringWithFormat:@"Send feedback meet error: %@. Push msgid: %ld.", error.localizedDescription, (long)pushData.msgID] forAssocId:0 withResult:100/*ignore*/ withHandler:nil];
        }
        if (handler)
        {
            handler(task.currentRequest, error);
        }
    }];
}

#pragma mark - private functions

- (void)handleFeedback
{
    if (self.arrayFeedbacks.count > 0 && !self.isProcessing/*if one feedback is doing, wait till done*/)
    {
        self.isProcessing = YES;
        //parse information from queue
        NSDictionary *dict = self.arrayFeedbacks[0];
        NSArray *arrayChoice = nil;
        if ([dict.allKeys containsObject:@"choice"])
        {
            arrayChoice = dict[@"choice"];
        }
        BOOL needInput = [dict[@"needInput"] boolValue];
        BOOL needConfirm = [dict[@"needConfirm"] boolValue];
        NSString *infoTitle = nil;
        if ([dict.allKeys containsObject:@"title"])
        {
            infoTitle = dict[@"title"];
        }
        NSString *infoMessage = nil;
        if ([dict.allKeys containsObject:@"message"])
        {
            infoMessage = dict[@"message"];
        }
        PushDataForApplication *pushData = nil;
        if ([dict.allKeys containsObject:@"data"])
        {
            pushData = [PushDataForApplication fromDictionary:dict[@"data"]];
        }
        //handle it
        __block/*need to use block as it may change outside of block*/ NSString *feedbackChoice = nil;
        dispatch_block_t actionInput = ^
        {
            SHFeedbackInputHandler inputHandler = ^(BOOL isSubmit, NSString *title, NSString *content)
            {
                if (isSubmit)
                {
                    [self submitFeedbackForTitle:title withType:0/*discussed: this is not used now*/ withContent:content withPushData:pushData withShowError:YES withHandler:nil];
                }
                else
                {
                    [pushData sendPushResult:SHResult_Decline withHandler:nil];
                }
                [self checkNextFeedback]; //when input dialog dismiss, no matter submit or cancel, continue next one. Previous result may appear in a few seconds, but it's toast view and disappear automatically.
            };
            SHFeedbackViewController *feedbackVC = [[SHFeedbackViewController alloc] initWithNibName:nil bundle:nil];
            feedbackVC.inputHandler = inputHandler;
            feedbackVC.feedbackTitle = feedbackChoice;
            [self presentModalDialogViewController:feedbackVC];
        };
        //arrayChoice may contain none string, or empty string, need to filter out otherwise cause crash.
        NSMutableArray *arrayChoiceRefine = [NSMutableArray array];
        for (int i = 0; i < arrayChoice.count; i ++)
        {
            if (arrayChoice[i] != nil && [arrayChoice[i] isKindOfClass:[NSString class]] && ((NSString *)arrayChoice[i]).length > 0)
            {
                [arrayChoiceRefine addObject:arrayChoice[i]];
            }
        }
        NSString *appDisplayName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
        NSString *alertTitle = shStrIsEmpty(infoTitle) ? [NSString stringWithFormat:shLocalizedString(@"STREETHAWK_WINDOW_FEEDBACK_TITLE", @"%@ loves Feedback!"), appDisplayName] : infoTitle;
        if (arrayChoiceRefine == nil || arrayChoiceRefine.count == 0)  //regardless needInput, show input dialog
        {
            if (needConfirm)
            {
                if (pushData == nil) //not from notification
                {
                    SHAlertView *alertViewConfirm = [[SHAlertView alloc] initWithTitle:alertTitle message:infoMessage withHandler:^(UIAlertView *viewConfirm, NSInteger buttonIndexConfirm)
                     {
                         if (buttonIndexConfirm == viewConfirm.cancelButtonIndex)
                         {
                             [self checkNextFeedback];
                         }
                         else
                         {
                             actionInput();
                         }
                     } cancelButtonTitle:shLocalizedString(@"STREETHAWK_CANCEL", @"Cancel") otherButtonTitles:shLocalizedString(@"STREETHAWK_YES", @"Yes Please!"), nil];
                    [alertViewConfirm show];
                }
                else
                {
                    if (pushData.title == nil || pushData.title.length == 0)
                    {
                        pushData.title = alertTitle;
                    }
                    NSMutableDictionary *dictUserInfo = [NSMutableDictionary dictionary];
                    dictUserInfo[@"pushdata"] = pushData;
                    dictUserInfo[@"clickbutton"] = ^(SHResult result)
                    {
                        switch (result)
                        {
                            case SHResult_Accept:
                                actionInput();
                                break;
                            case SHResult_Decline:
                                [pushData sendPushResult:SHResult_Decline withHandler:nil];
                                [self checkNextFeedback];
                                break;
                            default:
                                break;
                        }
                    };
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PushBridge_HandlePushData" object:nil userInfo:dictUserInfo];
                }
            }
            else
            {
                actionInput();
            }
        }
        else
        {
            SHChoiceHandler choiceHandler = ^(BOOL isCancel, NSInteger choiceIndex)
            {
                if (isCancel)
                {
                    [pushData sendPushResult:SHResult_Decline withHandler:nil];
                    [self checkNextFeedback];
                    return;
                }
                //not retain feedbackChoice, different from alertTitle in notification handler, as it reset here.
                feedbackChoice = arrayChoiceRefine[choiceIndex];
                if (needInput)
                {
                    actionInput();
                }
                else
                {
                    //if from notification and one click choice, use notification title/message as feedback title and one click choice as content, so that web can show what's the question and what's the answer.
                    NSString *feedbackTitle = nil;
                    NSString *feedbackContent = nil;
                    if (pushData != nil)
                    {
                        if (!shStrIsEmpty(pushData.title))
                        {
                            feedbackTitle = pushData.title;
                        }
                        else if (!shStrIsEmpty(pushData.message))
                        {
                            feedbackTitle = pushData.message;
                        }
                        else
                        {
                            feedbackTitle = alertTitle;
                        }
                        feedbackContent = feedbackChoice;
                    }
                    else
                    {
                        feedbackTitle = feedbackChoice;
                    }
                    NSAssert(feedbackTitle != nil, @"Feedback title is mandatory.");
                    [self submitFeedbackForTitle:feedbackTitle withType:0/*discussed: this is not used now*/ withContent:feedbackContent withPushData:pushData withShowError:YES withHandler:nil];
                    [self checkNextFeedback];
                }
            };
            SHChoiceViewController *choiceVC = [[SHChoiceViewController alloc] initWithNibName:nil bundle:nil];
            choiceVC.choiceHandler = choiceHandler;
            choiceVC.arrayChoices = arrayChoiceRefine;
            choiceVC.displayTitle = alertTitle;
            choiceVC.displayMessage = infoMessage;
            [choiceVC showChoiceList];
        }
    }
}

- (void)checkNextFeedback
{
    //delay for 1 second to let previous dialog dismiss, and feedback toast window appear/disappear.
    double delayInSeconds = 1;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void)
       {
           self.isProcessing = NO;
           NSAssert(self.arrayFeedbacks.count > 0, @"There should be processed feedback dict.");
           if (self.arrayFeedbacks.count > 0)
           {
               [self.arrayFeedbacks removeObjectAtIndex:0];
           }
           [self handleFeedback];
       });
}

@end
