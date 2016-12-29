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

/**
 Protocol for deal with deeplinking. `StreetHawkBaseViewController` and `StreetHawkBaseTableViewController` conform this protocol, customer App's view controller is recommended to inherit from `StreetHawkBaseViewController` or `StreetHawkBaseTableViewController`, so can implement this protocol. Or customer's App's view controller can directly conform this protocol for deeplinking.
 */
@protocol ISHDeepLinking <NSObject>

@optional

/**
 Implement this function for receive deeplinking parameters. Customer App needs to hold the pass in `dictParam` in some internal data structure, cannot rely on this function to show to UI. Because this function is called before UI loaded, the controls are not created yet. `StreetHawkBaseViewController` or `StreetHawkBaseTableViewController` automatically calls `displayDeepLinkingToUI` on `viewDidLoad` to display data to UI.
 @param dictParam Pass in parameters.
 */
- (void)receiveDeepLinkingData:(NSDictionary *)dictParam;

/**
 Implement this function if need to show deeplinking data to UI. The data was received in `receiveDeepLinkingData:` before UI loaded, and it should be stored in customer's view controller internal data. Call this function whenever it's ready to show data to UI controller. `viewDidLoad` is already automatically called by `StreetHawkBaseViewController` or `StreetHawkBaseTableViewController`.
 */
- (void)displayDeepLinkingToUI;

@end

/**
 Base class for all view controller inherit from UIViewController. It sends logs when enter/exit this VC.
 */
@interface StreetHawkBaseViewController : UIViewController <ISHDeepLinking>

@end

/**
 Base class for all view controller inherit from UITableViewController. It sends logs when enter/exit this VC.
 */
@interface StreetHawkBaseTableViewController : UITableViewController <ISHDeepLinking>

@end

/**
 Category extension of UIViewController.
 */
@interface UIViewController (SHViewExt)

/**
 Show self VC's view on top.
 @param needCover When showing self's view, whether need a cover view behide it. Sometimes it needs a light transparanet color cover. 
 @param coverColor Optional, only take effect when needCover = YES; It has default value `lightGrayColor` when it's nil.
 @param coverAlpha Optional, only take effect when needCover = YES; It has default value 0.5 when it's 0. If it's really want to be 0, set needCover = NO.
 @param coverTouchHandler Callback when touch cover. Must have needCover=YES to work. The touchPoint is in cover full screen range.
 @param animationHandler Callback when need caller to show by changing self view's frame. The pass in rect is orientated root rect.
 @param orientationChangedHandler Callback when orientation changed. Must have needCover=YES to work.
 */
- (void)presentOnTopWithCover:(BOOL)needCover withCoverColor:(UIColor *)coverColor withCoverAlpha:(CGFloat)coverAlpha withCoverTouchHandler:(void (^)(CGPoint touchPoint))coverTouchHandler withAnimationHandler:(void (^)(CGRect fullScreenRect))animationHandler withOrientationChangedHandler:(void (^)(CGRect fullScreenRect))orientationChangedHandler;

/**
 Dismiss self VC's view from top.
 */
- (void)dismissOnTop;

@end
