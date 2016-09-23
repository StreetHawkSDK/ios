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
#import "SHNotificationHandler.h" //for SHNotificationActionResult
//header from System
#import <UserNotifications/UserNotifications.h>  //for notification since iOS 10

#define SH_INTERACTIVEPUSH_KEY      @"SH_INTERACTIVEPUSH_KEY" //key in user defaults for whole customized interactive push array, it get an array, with each one is a dictionary. This is purely for customer's, not include predefined.
#define SH_INTERACTIVEPUSH_PAIR     @"SH_INTERACTIVEPUSH_PAIR" //key for one pair's title
#define SH_INTERACTIVEPUSH_BUTTON1  @"SH_INTERACTIVEPUSH_BUTTON1" //key for one pair's button1
#define SH_INTERACTIVEPUSH_BUTTON2  @"SH_INTERACTIVEPUSH_BUTTON2" //key for one pair's button2

/**
 The whole information for creating a interactive category. In public API there is a class `InteractivePush`, which is only for customized pairs, and it does not contain full information as not want it to be too complicated.
 */
@interface SHInteractiveButtons : NSObject

/**
 Identifier for category.
 */
@property (nonatomic, strong) NSString *categoryIdentifier;

/**
 Title for button 1.
 */
@property (nonatomic, strong) NSString *button1;

/**
 Action result for button1.
 */
@property (nonatomic) SHNotificationActionResult action1;

/**
 Whether button 1 requires foreground execution.
 */
@property (nonatomic) BOOL executeFg1;

/**
 Title for button 2.
 */
@property (nonatomic, strong) NSString *button2;

/**
 Action result for button2.
 */
@property (nonatomic) SHNotificationActionResult action2;

/**
 Whether button 2 requires foreground execution.
 */
@property (nonatomic) BOOL executeFg2;

/**
 Whether this pair should submit to server. Currently existing code pair such as "8000" should not submit. By default it's YES.
 */
@property (nonatomic) BOOL isSubmitToServer;

/**
 An array of int numbers for predefined code, such as: 8000, 8003....
 */
+ (NSArray *)predefinedCodes;

/**
 An array of pre-defined pairs and buttons. It does not precisely match `predefinedCodes`, because not need pair for 8003, and add out-of-box for 8100.
 */
+ (NSArray *)predefinedPairs;

/**
 Create a notification category according to self's information.
 */
- (UIUserNotificationCategory *)createNotificationCategory;

/**
 Create a UN notification category according to self's information.
 */
- (UNNotificationCategory *)createUNNotificationCategory;

/**
 Add one category to a set. Note: if set has same category id already, remove existing category from set and add this new one. This is because only the first category id take effect, if want newly added category work, the set cannot have same category id ahead.
 @param category Newly added category, cannot be nil.
 @param set The modified set, cannot be nil.
 */
+ (void)addCategory:(UIUserNotificationCategory *)category toSet:(NSMutableSet<UIUserNotificationCategory *> *)set;

/**
 Add one category to a set. Note: if set has same category id already, remove existing category from set and add this new one. This is because only the first category id take effect, if want newly added category work, the set cannot have same category id ahead.
 @param category Newly added category, cannot be nil.
 @param set The modified set, cannot be nil.
 */
+ (void)addUNCategory:(UNNotificationCategory *)category toSet:(NSMutableSet<UNNotificationCategory *> *)set;

/**
 Read from local and add customized button pairs.
 */
+ (void)addCustomisedButtonPairsToSet:(NSMutableSet<UIUserNotificationCategory *> *)set;

/**
 Read from local and add customized button pairs.
 */
+ (void)addUNCustomisedButtonPairsToSet:(NSMutableSet<UNNotificationCategory *> *)set;

/**
 Fetch predefined pairs and format the array for saved locally.
 */
+ (NSMutableArray *)predefinedLocalPairs;

/**
 Check whether a pair title optional button 1 and button 2 are already used in array.
 @param pairTitle The pair title to compare. It's mandatory.
 @param button1 Optional compare, if input nil ignore this.
 @param button2 Optional compare, if input nil ignore this.
 @param arrayPairs The local save array, each item is dictionary of `SH_INTERACTIVEPUSH_PAIR`, `SH_INTERACTIVEPUSH_BUTTON1`, `SH_INTERACTIVEPUSH_BUTTON2`.
 @return If find match return YES; otherwise return NO. Compare is case sensitive.
 */
+ (BOOL)pairTitle:(NSString *)pairTitle andButton1:(NSString *)button1 andButton2:(NSString *)button2 isUsed:(NSArray *)arrayPairs;

/**
 Read local saved pairs and submit to StreetHawk server.
 */
+ (void)submitInteractivePairButtons;

@end
