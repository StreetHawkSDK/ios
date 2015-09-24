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

#define FRIENDLYNAME_KEY                    @"FRIENDLYNAME_KEY" //key in user defaults for whole friendly name, it get an array, with each one is a dictionary.
#define FRIENDLYNAME_NAME                   @"FRIENDLYNAME_NAME"  //the register to server name.
#define FRIENDLYNAME_VC                     @"FRIENDLYNAME_VC"  //the view controller class name
#define FRIENDLYNAME_XIB_IPHONE             @"FRIENDLYNAME_XIB_IPHONE"  //the xib for iphone
#define FRIENDLYNAME_XIB_IPAD               @"FRIENDLYNAME_XIB_IPAD"  //the xib for ipad

#define FRIENDLYNAME_REGISTER               @"register"  //reserved friendly name for login UI, push notification code 8006
#define FRIENDLYNAME_LOGIN                  @"login"  //reserved friendly name for login UI, push notification code 8007

/**
 Object for hosting friendly name, vc, xib for iphone and ipad. Refer to `-(BOOL)shCustomActivityList:(NSArray *)arrayFriendlyNameObj;`.
 */
@interface SHFriendlyNameObject : NSObject

/**
 The friendly name register and show on StreetHawk server when sending push notification. All platform should use same friendly name. Example: @"My favourite page". This is mandatory, case sensitive, cannot be nil or empty, and length should be less than 150. It cannot contain ":" because ":" is used as separator for <vc>:<xib_iphone>:<xib_ipad>.
 */
@property (nonatomic, strong) NSString *friendlyName;

/**
 The view controller class name, it must inherit from UIViewController. Example: @"MyViewController". This is mandatory, case sensitive, cannot be nil or empty, otherwise fail to register.
 */
@property (nonatomic, strong) NSString *vc;

/**
 The xib name for iPhone. Example: @"MyViewController_iPhone". This is optional, case sensitive, used for create view controller for iPhone. If not run on iPhone, or xib name is same as class name, set nil.
 */
@property (nonatomic, strong) NSString *xib_iphone;

/**
 The xib name for iPad. Example: @"MyViewController_iPad". This is optional, case sensitive, used for create view controller for iPad. If not run on iPad, or xib name is same as class name, set nil.
 */
@property (nonatomic, strong) NSString *xib_ipad;

/**
 Friendly objects are stored locally in NSUserDefaults. Server may send friendly name, need to get raw information to launch page. This method is to find matching `SHFriendlyNameObject` from local list.
 @param friendlyName Comparing friendly name. 
 @return If find match friendly name locally, return the object; else return nil.
 */
+ (SHFriendlyNameObject *)findObjByFriendlyName:(NSString *)friendlyName;

/**
 Try to find friendly name according to vc, if not find matching friendly name return vc.
 @param vc Pass in view controller name.
 @return If find matching friendly name, return friendly name; otherwise return same `vc`.
 */
+ (NSString *)tryFriendlyName:(NSString *)vc;

@end
