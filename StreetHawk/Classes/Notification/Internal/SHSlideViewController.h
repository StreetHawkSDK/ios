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

#import <UIKit/UIKit.h>
#import "SHApp.h" //for extension SHApp

@class PushDataForApplication;

/**
 Callback for `SHSlideContentViewController` load finish.
 */
typedef void(^SHSlideContentLoadFinish)(BOOL isSuccesss);

/**
 Protocal for slide content to implement.
 */
@protocol SHSlideContentViewController <NSObject>

@required

/**
 Property for notice content is loaded finished.
 */
@property (copy, nonatomic) SHSlideContentLoadFinish contentLoadFinishHandler;

/**
 After slide display for first time, or after rotation, content VC may need to adjust subview position according to new frame. Adjust subview position in this method.
 */
- (void)contentViewAdjustUI;

@optional

/**
 Property for passing notification payload with slide.
 */
@property (nonatomic, strong) PushDataForApplication *pushData;

@end

/**
 **Extension for slide:**
 
 Slide utility to show some content. For example:
 
 * `slideForUrl:withDirection:withSpeed:withCoverPercentage:withHideLoading:withAlertTitle:withAlertMessage:` is to slide a web view showing the url.
 * `slideForVC:withDirection:withSpeed:withCoverPercentage:withHideLoading:withAlertTitle:withAlertMessage:` is to slide a customized view controller, the view controller can be created by customer and do whatever they want.
 */
@interface SHApp (SlideExt)

/**
 Utility function to show slide with url content.
 @param url The content's url link, NSString type, for example @"www.google.com" or @"https://www.some.com". If it does not contain the protocal prefix @"://", default @"https://" will be added. But if it's not http protocal, must have the complete address.
 @param direction The slide show direction, refer to enum `SHSlideDirection`.
 @param speed The seconds duration from start slide till it complete, measured in seconds. It should be a positive number. Note: it's the time for animate slide show, not include time for loading web page. It should be a positive number, if not use 0.1 by default.
 @param percentage The width or height (depending on direction) of the slide cover on screen. It should be from 0 to 1. If set too much to outside of screen, the slide cover whole screen.
 @param isHideLoading Whether the slide should wait till web page load finished. If YES the slide will not show till web page finish loading, and then call confirm alert (if `alertTitle` or `alertMessage` not empty) or slide without activity spinner; If NO the slide show immediately with an acivity spinner, not wait till web page load finish.
 @param alertTitle Before slide it may be show a confirm dialog if `alertTitle` or `alertMessage` not empty and `needShowDialog`=YES. This title will also display on slide top.
 @param alertMessage Same as `alertTitle`.
 @param needShowDialog Before slide it may be show a confirm dialog if `alertTitle` or `alertMessage` not empty and `needShowDialog`=YES.
 @param pushData When used in notification, pass in payload information. If not used in notification, pass nil.
 */
- (void)slideForUrl:(NSString *)url withDirection:(SHSlideDirection)direction withSpeed:(double)speed withCoverPercentage:(double)percentage withHideLoading:(BOOL)isHideLoading withAlertTitle:(NSString *)alertTitle withAlertMessage:(NSString *)alertMessage withNeedShowDialog:(BOOL)needShowDialog withPushData:(PushDataForApplication *)pushData;

/**
 Utility function to show slide with url content.
 @param contentVC A view controller to display as content of the slide.
 @param direction The slide show direction, refer to enum `SHSlideDirection`.
 @param speed The seconds duration from start slide till it complete, measured in seconds. It should be a positive number. Note: it's the time for animate slide show, not include time for loading content VC. It should be a positive number, if not use 0.1 by default.
 @param percentage The width or height (depending on direction) of the slide cover on screen. It should be from 0 to 1. If set too much to outside of screen, the slide cover whole screen.
 @param isHideLoading Whether the slide should wait till content VC load finished. If YES the slide will not show till content VC finish loading, and then call confirm alert (if `alertTitle` or `alertMessage` not empty) or slide without activity spinner; If NO the slide show immediately with an acivity spinner, not wait till content VC load finish.
 @param alertTitle Before slide it may be show a confirm dialog if `alertTitle` or `alertMessage` not empty.
 @param alertMessage Same as `alertTitle`.
 */
- (void)slideForVC:(UIViewController<SHSlideContentViewController> *)contentVC withDirection:(SHSlideDirection)direction withSpeed:(double)speed withCoverPercentage:(double)percentage withHideLoading:(BOOL)isHideLoading withAlertTitle:(NSString *)alertTitle withAlertMessage:(NSString *)alertMessage withNeedShowDialog:(BOOL)needShowDialog;

@end
