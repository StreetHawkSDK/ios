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
#import "PushDataForApplication.h" //for SHResult

/**
 Callback when click button.
 */
typedef void(^ClickButtonHandler)(SHResult result);

/**
 Customer override these functions to provide their own customised functions.
 */
@protocol ISHCustomiseHandler <NSObject>

@optional

/**
 Streethawk calls [ISHCustomiseHandler shRawJsonCallbackWithTitle:withMessage:withJson:] function when a customized notification code 8049 arrives at device. Customer is responsible to handle this message by their own code:
 
 1. Customer App create class (assume named `MyHandler`) inherit from `ISHCustomiseHandler` and implement this function.
 2. Customer App call `[StreetHawk shSetCustomiseHandler:<instance_MyHandler>` to register the observer.
 3. When StreetHawk sends 8049, customer's implementation is triggered.
 
 @param title Title of the payload.
 @param message Message of the payload.
 @param json Json string, usually parse to NSDicationary. Use system API `NSJSONSerialization`, or use StreetHawk utility function `NSDictionary *dict = shParseObjectToDict(json)`.
 */
- (void)shRawJsonCallbackWithTitle:(NSString *)title withMessage:(NSString *)message withJson:(NSString *)json;

/**
 Streethawk calls [ISHCustomiseHandler onReceive:clickButton:] function when needs to display confirm dialog UI. Default it will display a UIAlertView, and customer is capable to override this confirm dialog UI with their own code:
 
 1. Customer App create class (assume named `MyHandler`) inherit from `ISHCustomiseHandler` and implement this function.
 2. `pushData` contains notification information, such as title, message, data etc. Customer can show their own dialog using these information.
 3. After showing customer confirm dialog UI, if still wish to use StreetHawk functions, call `handler` and let StreetHawk to handle the rest automatically.
 4. If not use StreetHawk function, not call `handler` and implement by your own. Remember to call `[PushDataForApplication sendPushResult]` to send result to server.
 5. Customer App call `[StreetHawk shSetCustomiseHandler:<instance_MyHandler>` to register the callback.
 
 @param pushData Information from notification. Customer developer can use the information to create their own confirm dialog.
 @param handler After click button call this to let StreetHawk continue process.
 @return If this push can be handled by one callback, return YES; if not handle this push, return NO. For example, customer handler may handle one action, so return YES for this action and return NO for others to let StreetHawk handle the rest.
 */
- (BOOL)onReceive:(PushDataForApplication *)pushData clickButton:(ClickButtonHandler)handler;

/**
 Streethawk calls [ISHCustomiseHandler onReceiveResult:withResult:] function when sending push result to server, customer App can implement this to do some action. For example, if user choose `SHResult_Decline` it can pop up feedback dialog asking why. Note: this can happen both FG and BG, check `pushData.isAppOnForeground` to know the status, if in BG it cannot do UI stuff.
 
 @param pushData Information from notification. Customer developer can use the information to know what notification is handled.
 @param result The result user decides for this notification.
 */
- (void)onReceiveResult:(PushDataForApplication *)pushData withResult:(SHResult)result;

@end
