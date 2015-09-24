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

@class PushDataForApplication;

/**
 Function to launch page with deeplinking.
 */
@interface SHDeepLinking : NSObject

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

@end
