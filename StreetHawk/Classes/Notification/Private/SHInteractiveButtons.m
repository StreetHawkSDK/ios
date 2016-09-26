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

#import "SHInteractiveButtons.h"
//header from StreetHawk
#import "SHUtils.h" //for shLocalizedString
#import "SHApp+Notification.h" //for StreetHawk
#import "SHHTTPSessionManager.h" //for send request

@implementation SHInteractiveButtons

#pragma mark - life cycle

- (id)init
{
    if (self = [super init])
    {
        self.isSubmitToServer = YES;
    }
    return self;
}

#pragma mark - public functions

+ (NSArray *)predefinedCodes
{
    return @[@(8000), @(8003), @(8004), @(8005), @(8006), @(8007), @(8008), @(8009), @(8010), @(8011), @(8012), @(8013), @(8014), @(8042), @(8049), @(8100)];
}

+ (NSArray *)predefinedPairs
{
    //StreetHawk predefine pairs which for each predefine code.
    NSMutableArray *arrayPairs = [NSMutableArray array];
    SHInteractiveButtons *pair8000 = [[SHInteractiveButtons alloc] init]; //8000 notification for launch web in app or open safari. Buttons: 1. Show; 2. Cancel
    pair8000.categoryIdentifier = @"8000";
    pair8000.button1 = shLocalizedString(@"STREETHAWK_8000_POSITIVE", @"Show");
    pair8000.action1 = SHNotificationActionResult_Yes;
    pair8000.executeFg1 = YES;
    pair8000.button2 = shLocalizedString(@"STREETHAWK_8000_NEGATIVE", @"Cancel");
    pair8000.action2 = SHNotificationActionResult_NO;
    pair8000.executeFg2 = NO;
    pair8000.isSubmitToServer = NO;
    [arrayPairs addObject:pair8000];
    SHInteractiveButtons *pair8004 = [[SHInteractiveButtons alloc] init]; //8004 notifications for launch page. Buttons: 1. Open App; 2. Cancel
    pair8004.categoryIdentifier = @"8004";
    pair8004.button1 = shLocalizedString(@"STREETHAWK_8004_POSITIVE", @"Open App");
    pair8004.action1 = SHNotificationActionResult_Yes;
    pair8004.executeFg1 = YES;
    pair8004.button2 = shLocalizedString(@"STREETHAWK_8004_NEGATIVE", @"Cancel");
    pair8004.action2 = SHNotificationActionResult_NO;
    pair8004.executeFg2 = NO;
    pair8004.isSubmitToServer = NO;
    [arrayPairs addObject:pair8004];
    SHInteractiveButtons *pair8005 = [[SHInteractiveButtons alloc] init]; //8005 notification for rate. Buttons: 1. Rate; 2. Later.
    pair8005.categoryIdentifier = @"8005";
    pair8005.button1 = shLocalizedString(@"STREETHAWK_8005_POSITIVE", @"Rate");
    pair8005.action1 = SHNotificationActionResult_Yes;
    pair8005.executeFg1 = YES;
    pair8005.button2 = shLocalizedString(@"STREETHAWK_8005_LATER", @"Later");
    pair8005.action2 = SHNotificationActionResult_Later;
    pair8005.executeFg2 = NO;
    pair8005.isSubmitToServer = NO;
    [arrayPairs addObject:pair8005];
    SHInteractiveButtons *pair8006 = [[SHInteractiveButtons alloc] init]; //8006 notifications for launch page. Buttons: 1. Open App; 2. Cancel
    pair8006.categoryIdentifier = @"8006";
    pair8006.button1 = shLocalizedString(@"STREETHAWK_8006_POSITIVE", @"Open App");
    pair8006.action1 = SHNotificationActionResult_Yes;
    pair8006.executeFg1 = YES;
    pair8006.button2 = shLocalizedString(@"STREETHAWK_8006_NEGATIVE", @"Cancel");
    pair8006.action2 = SHNotificationActionResult_NO;
    pair8006.executeFg2 = NO;
    pair8006.isSubmitToServer = NO;
    [arrayPairs addObject:pair8006];
    SHInteractiveButtons *pair8007 = [[SHInteractiveButtons alloc] init]; //8007 notifications for launch page. Buttons: 1. Open App; 2. Cancel
    pair8007.categoryIdentifier = @"8007";
    pair8007.button1 = shLocalizedString(@"STREETHAWK_8007_POSITIVE", @"Open App");
    pair8007.action1 = SHNotificationActionResult_Yes;
    pair8007.executeFg1 = YES;
    pair8007.button2 = shLocalizedString(@"STREETHAWK_8007_NEGATIVE", @"Cancel");
    pair8007.action2 = SHNotificationActionResult_NO;
    pair8007.executeFg2 = NO;
    pair8007.isSubmitToServer = NO;
    [arrayPairs addObject:pair8007];
    SHInteractiveButtons *pair8008 = [[SHInteractiveButtons alloc] init]; //8008 notification for upgrade. Buttons: 1. Upgrade; 2. Cancel
    pair8008.categoryIdentifier = @"8008";
    pair8008.button1 = shLocalizedString(@"STREETHAWK_8008_POSITIVE", @"Upgrade");
    pair8008.action1 = SHNotificationActionResult_Yes;
    pair8008.executeFg1 = YES;
    pair8008.button2 = shLocalizedString(@"STREETHAWK_8008_NEGATIVE", @"Cancel");
    pair8008.action2 = SHNotificationActionResult_NO;
    pair8008.executeFg2 = NO;
    pair8008.isSubmitToServer = NO;
    [arrayPairs addObject:pair8008];
    SHInteractiveButtons *pair8009 = [[SHInteractiveButtons alloc] init]; //8009 notification for call telephone. Buttons: 1. Call; 2. Cancel
    pair8009.categoryIdentifier = @"8009";
    pair8009.button1 = shLocalizedString(@"STREETHAWK_8009_POSITIVE", @"Call");
    pair8009.action1 = SHNotificationActionResult_Yes;
    pair8009.executeFg1 = YES;
    pair8009.button2 = shLocalizedString(@"STREETHAWK_8009_NEGATIVE", @"Cancel");
    pair8009.action2 = SHNotificationActionResult_NO;
    pair8009.executeFg2 = NO;
    pair8009.isSubmitToServer = NO;
    [arrayPairs addObject:pair8009];
    SHInteractiveButtons *pair8010 = [[SHInteractiveButtons alloc] init]; //8010 notification for simply show dialog to launch App. Buttons: 1. Read; 2. Cancel
    pair8010.categoryIdentifier = @"8010";
    pair8010.button1 = shLocalizedString(@"STREETHAWK_8010_POSITIVE", @"Read");
    pair8010.action1 = SHNotificationActionResult_Yes;
    pair8010.executeFg1 = YES;
    pair8010.button2 = shLocalizedString(@"STREETHAWK_8010_NEGATIVE", @"Cancel");
    pair8010.action2 = SHNotificationActionResult_NO;
    pair8010.executeFg2 = NO;
    pair8010.isSubmitToServer = NO;
    [arrayPairs addObject:pair8010];
    SHInteractiveButtons *pair8011 = [[SHInteractiveButtons alloc] init]; //8011 notification for feedback. Buttons: 1. Open; 2. Cancel
    pair8011.categoryIdentifier = @"8011";
    pair8011.button1 = shLocalizedString(@"STREETHAWK_8011_POSITIVE", @"Open");
    pair8011.action1 = SHNotificationActionResult_Yes;
    pair8011.executeFg1 = YES;
    pair8011.button2 = shLocalizedString(@"STREETHAWK_8011_NEGATIVE", @"Cancel");
    pair8011.action2 = SHNotificationActionResult_NO;
    pair8011.executeFg2 = NO;
    pair8011.isSubmitToServer = NO;
    [arrayPairs addObject:pair8011];
    SHInteractiveButtons *pair8012 = [[SHInteractiveButtons alloc] init]; //8012 notification for remind to turn on bluetooth. Buttons: 1. Enable; 2. Cancel
    pair8012.categoryIdentifier = @"8012";
    pair8012.button1 = shLocalizedString(@"STREETHAWK_8012_POSITIVE", @"Enable");
    pair8012.action1 = SHNotificationActionResult_Yes;
    pair8012.executeFg1 = YES;
    pair8012.button2 = shLocalizedString(@"STREETHAWK_8012_NEGATIVE", @"Cancel");
    pair8012.action2 = SHNotificationActionResult_NO;
    pair8012.executeFg2 = NO;
    pair8012.isSubmitToServer = NO;
    [arrayPairs addObject:pair8012];
    SHInteractiveButtons *pair8013 = [[SHInteractiveButtons alloc] init]; //8013 notification for remind to turn on push permission. Buttons: 1. Enable; 2. Cancel
    pair8013.categoryIdentifier = @"8013";
    pair8013.button1 = shLocalizedString(@"STREETHAWK_8013_POSITIVE", @"Enable");
    pair8013.action1 = SHNotificationActionResult_Yes;
    pair8013.executeFg1 = YES;
    pair8013.button2 = shLocalizedString(@"STREETHAWK_8013_NEGATIVE", @"Cancel");
    pair8013.action2 = SHNotificationActionResult_NO;
    pair8013.executeFg2 = NO;
    pair8013.isSubmitToServer = NO;
    [arrayPairs addObject:pair8013];
    SHInteractiveButtons *pair8014 = [[SHInteractiveButtons alloc] init]; //8014 notification for remind to turn on location permission. Buttons: 1. Enable; 2. Cancel
    pair8014.categoryIdentifier = @"8014";
    pair8014.button1 = shLocalizedString(@"STREETHAWK_8014_POSITIVE", @"Enable");
    pair8014.action1 = SHNotificationActionResult_Yes;
    pair8014.executeFg1 = YES;
    pair8014.button2 = shLocalizedString(@"STREETHAWK_8014_NEGATIVE", @"Cancel");
    pair8014.action2 = SHNotificationActionResult_NO;
    pair8014.executeFg2 = NO;
    pair8014.isSubmitToServer = NO;
    [arrayPairs addObject:pair8014];
    SHInteractiveButtons *pair8049 = [[SHInteractiveButtons alloc] init]; //8049 notification for json. Buttons: 1. Yes please; 2. Cancel
    pair8049.categoryIdentifier = @"8049";
    pair8049.button1 = shLocalizedString(@"STREETHAWK_8049_POSITIVE", @"Yes please");
    pair8049.action1 = SHNotificationActionResult_Yes;
    pair8049.executeFg1 = YES;
    pair8049.button2 = shLocalizedString(@"STREETHAWK_8049_NEGATIVE", @"Cancel");
    pair8049.action2 = SHNotificationActionResult_NO;
    pair8049.executeFg2 = NO;
    pair8049.isSubmitToServer = NO;
    [arrayPairs addObject:pair8049];
        
    //StreetHawk predefine out-of-box pairs
    SHInteractiveButtons *pairYesNo = [[SHInteractiveButtons alloc] init]; //Category: YesNo. Buttons: 1. Yes; 2. No
    pairYesNo.categoryIdentifier = @"YesNo";
    pairYesNo.button1 = shLocalizedString(@"STREETHAWK_Yes_No_1", @"Yes");
    pairYesNo.action1 = SHNotificationActionResult_Yes;
    pairYesNo.executeFg1 = YES;
    pairYesNo.button2 = shLocalizedString(@"STREETHAWK_Yes_No_2", @"No");
    pairYesNo.action2 = SHNotificationActionResult_NO;
    pairYesNo.executeFg2 = YES;
    [arrayPairs addObject:pairYesNo];
    SHInteractiveButtons *pairAcceptDecline = [[SHInteractiveButtons alloc] init]; //Category: AcceptDecline. Buttons: 1. Accept; 2. Decline
    pairAcceptDecline.categoryIdentifier = @"AcceptDecline";
    pairAcceptDecline.button1 = shLocalizedString(@"STREETHAWK_Accept_Decline_1", @"Accept");
    pairAcceptDecline.action1 = SHNotificationActionResult_Yes;
    pairAcceptDecline.executeFg1 = YES;
    pairAcceptDecline.button2 = shLocalizedString(@"STREETHAWK_Accept_Decline_2", @"Decline");
    pairAcceptDecline.action2 = SHNotificationActionResult_NO;
    pairAcceptDecline.executeFg2 = YES;
    [arrayPairs addObject:pairAcceptDecline];
    SHInteractiveButtons *pairShareDownload = [[SHInteractiveButtons alloc] init]; //Category: ShareDownload. Buttons: 1. Share; 2. Download
    pairShareDownload.categoryIdentifier = @"ShareDownload";
    pairShareDownload.button1 = shLocalizedString(@"STREETHAWK_Share_Download_1", @"Share");
    pairShareDownload.action1 = SHNotificationActionResult_Yes;
    pairShareDownload.executeFg1 = YES;
    pairShareDownload.button2 = shLocalizedString(@"STREETHAWK_Share_Download_2", @"Download");
    pairShareDownload.action2 = SHNotificationActionResult_NO;
    pairShareDownload.executeFg2 = YES;
    [arrayPairs addObject:pairShareDownload];
    SHInteractiveButtons *pairShareRemind = [[SHInteractiveButtons alloc] init]; //Category: ShareRemindMeLater. Buttons: 1. Share; 2. Remind Me Later
    pairShareRemind.categoryIdentifier = @"ShareRemindMeLater";
    pairShareRemind.button1 = shLocalizedString(@"STREETHAWK_Share_Remind_1", @"Share");
    pairShareRemind.action1 = SHNotificationActionResult_Yes;
    pairShareRemind.executeFg1 = YES;
    pairShareRemind.button2 = shLocalizedString(@"STREETHAWK_Share_Remind_2", @"Remind Me Later");
    pairShareRemind.action2 = SHNotificationActionResult_NO;
    pairShareRemind.executeFg2 = YES;
    [arrayPairs addObject:pairShareRemind];
    SHInteractiveButtons *pairShareOptin = [[SHInteractiveButtons alloc] init]; //Category: ShareOpt-in. Buttons: 1. Share; 2. Opt-in
    pairShareOptin.categoryIdentifier = @"ShareOpt-in";
    pairShareOptin.button1 = shLocalizedString(@"STREETHAWK_Share_Optin_1", @"Share");
    pairShareOptin.action1 = SHNotificationActionResult_Yes;
    pairShareOptin.executeFg1 = YES;
    pairShareOptin.button2 = shLocalizedString(@"STREETHAWK_Share_Optin_2", @"Opt-in");
    pairShareOptin.action2 = SHNotificationActionResult_NO;
    pairShareOptin.executeFg2 = YES;
    [arrayPairs addObject:pairShareOptin];
    SHInteractiveButtons *pairShareOptout = [[SHInteractiveButtons alloc] init]; //Category: ShareOpt-out. Buttons: 1. Share; 2. Opt-out
    pairShareOptout.categoryIdentifier = @"ShareOpt-out";
    pairShareOptout.button1 = shLocalizedString(@"STREETHAWK_Share_Optout_1", @"Share");
    pairShareOptout.action1 = SHNotificationActionResult_Yes;
    pairShareOptout.executeFg1 = YES;
    pairShareOptout.button2 = shLocalizedString(@"STREETHAWK_Share_Optout_2", @"Opt-out");
    pairShareOptout.action2 = SHNotificationActionResult_NO;
    pairShareOptout.executeFg2 = YES;
    [arrayPairs addObject:pairShareOptout];
    SHInteractiveButtons *pairShareFollow = [[SHInteractiveButtons alloc] init]; //Category: ShareFollow. Buttons: 1. Share; 2. Follow
    pairShareFollow.categoryIdentifier = @"ShareFollow";
    pairShareFollow.button1 = shLocalizedString(@"STREETHAWK_Share_Follow_1", @"Share");
    pairShareFollow.action1 = SHNotificationActionResult_Yes;
    pairShareFollow.executeFg1 = YES;
    pairShareFollow.button2 = shLocalizedString(@"STREETHAWK_Share_Follow_2", @"Follow");
    pairShareFollow.action2 = SHNotificationActionResult_NO;
    pairShareFollow.executeFg2 = YES;
    [arrayPairs addObject:pairShareFollow];
    SHInteractiveButtons *pairShareUnfollow = [[SHInteractiveButtons alloc] init]; //Category: ShareUnfollow. Buttons: 1. Share; 2. Unfollow
    pairShareUnfollow.categoryIdentifier = @"ShareUnfollow";
    pairShareUnfollow.button1 = shLocalizedString(@"STREETHAWK_Share_Unfollow_1", @"Share");
    pairShareUnfollow.action1 = SHNotificationActionResult_Yes;
    pairShareUnfollow.executeFg1 = YES;
    pairShareUnfollow.button2 = shLocalizedString(@"STREETHAWK_Share_Unfollow_2", @"Unfollow");
    pairShareUnfollow.action2 = SHNotificationActionResult_NO;
    pairShareUnfollow.executeFg2 = YES;
    [arrayPairs addObject:pairShareUnfollow];
    SHInteractiveButtons *pairShareShopNow = [[SHInteractiveButtons alloc] init]; //Category: ShareShopNow. Buttons: 1. Share; 2. Shop Now
    pairShareShopNow.categoryIdentifier = @"ShareShopNow";
    pairShareShopNow.button1 = shLocalizedString(@"STREETHAWK_Share_ShopNow_1", @"Share");
    pairShareShopNow.action1 = SHNotificationActionResult_Yes;
    pairShareShopNow.executeFg1 = YES;
    pairShareShopNow.button2 = shLocalizedString(@"STREETHAWK_Share_ShopNow_2", @"Shop Now");
    pairShareShopNow.action2 = SHNotificationActionResult_NO;
    pairShareShopNow.executeFg2 = YES;
    [arrayPairs addObject:pairShareShopNow];
    SHInteractiveButtons *pairShareBuyNow = [[SHInteractiveButtons alloc] init]; //Category: ShareBuyNow. Buttons: 1. Share; 2. Buy Now
    pairShareBuyNow.categoryIdentifier = @"ShareBuyNow";
    pairShareBuyNow.button1 = shLocalizedString(@"STREETHAWK_Share_BuyNow_1", @"Share");
    pairShareBuyNow.action1 = SHNotificationActionResult_Yes;
    pairShareBuyNow.executeFg1 = YES;
    pairShareBuyNow.button2 = shLocalizedString(@"STREETHAWK_Share_BuyNow_2", @"Buy Now");
    pairShareBuyNow.action2 = SHNotificationActionResult_NO;
    pairShareBuyNow.executeFg2 = YES;
    [arrayPairs addObject:pairShareBuyNow];
    SHInteractiveButtons *pairShareLike = [[SHInteractiveButtons alloc] init]; //Category: ShareLike. Buttons: 1. Share; 2. Like
    pairShareLike.categoryIdentifier = @"ShareLike";
    pairShareLike.button1 = shLocalizedString(@"STREETHAWK_Share_Like_1", @"Share");
    pairShareLike.action1 = SHNotificationActionResult_Yes;
    pairShareLike.executeFg1 = YES;
    pairShareLike.button2 = shLocalizedString(@"STREETHAWK_Share_Like_2", @"Like");
    pairShareLike.action2 = SHNotificationActionResult_NO;
    pairShareLike.executeFg2 = YES;
    [arrayPairs addObject:pairShareLike];
    SHInteractiveButtons *pairLikeDislike = [[SHInteractiveButtons alloc] init]; //Category: LikeDislike. Buttons: 1. Like; 2. Dislike
    pairLikeDislike.categoryIdentifier = @"LikeDislike";
    pairLikeDislike.button1 = shLocalizedString(@"STREETHAWK_Like_Dislike_1", @"Like");
    pairLikeDislike.action1 = SHNotificationActionResult_Yes;
    pairLikeDislike.executeFg1 = YES;
    pairLikeDislike.button2 = shLocalizedString(@"STREETHAWK_Like_Dislike_2", @"Dislike");
    pairLikeDislike.action2 = SHNotificationActionResult_NO;
    pairLikeDislike.executeFg2 = YES;
    [arrayPairs addObject:pairLikeDislike];
    SHInteractiveButtons *pairMoreLess = [[SHInteractiveButtons alloc] init]; //Category: MoreLikeThisLessLikeThis. Buttons: 1. More Like This; 2. Less Like This
    pairMoreLess.categoryIdentifier = @"MoreLikeThisLessLikeThis";
    pairMoreLess.button1 = shLocalizedString(@"STREETHAWK_MoreLikeThis_LessLikeThis_1", @"More Like This");
    pairMoreLess.action1 = SHNotificationActionResult_Yes;
    pairMoreLess.executeFg1 = YES;
    pairMoreLess.button2 = shLocalizedString(@"STREETHAWK_MoreLikeThis_LessLikeThis_2", @"Less Like This");
    pairMoreLess.action2 = SHNotificationActionResult_NO;
    pairMoreLess.executeFg2 = YES;
    [arrayPairs addObject:pairMoreLess];
    SHInteractiveButtons *pairSmileSad = [[SHInteractiveButtons alloc] init]; //Category: shpre_happysad. Buttons: 1. :smile:; 2. :disappointed:
    pairSmileSad.categoryIdentifier = @"shpre_happysad";
    pairSmileSad.button1 = @"\U0001F604";
    pairSmileSad.action1 = SHNotificationActionResult_Yes;
    pairSmileSad.executeFg1 = YES;
    pairSmileSad.button2 = @"\U0001F61E";
    pairSmileSad.action2 = SHNotificationActionResult_NO;
    pairSmileSad.executeFg2 = YES;
    [arrayPairs addObject:pairSmileSad];
    SHInteractiveButtons *pairThumbnailUpDown = [[SHInteractiveButtons alloc] init]; //Category: shpre_tutd. Buttons: 1. :thumbsup:; 2. :thumbsdown:
    pairThumbnailUpDown.categoryIdentifier = @"shpre_tutd";
    pairThumbnailUpDown.button1 = @"\U0001F44D";
    pairThumbnailUpDown.action1 = SHNotificationActionResult_Yes;
    pairThumbnailUpDown.executeFg1 = YES;
    pairThumbnailUpDown.button2 = @"\U0001F44E";
    pairThumbnailUpDown.action2 = SHNotificationActionResult_NO;
    pairThumbnailUpDown.executeFg2 = YES;
    [arrayPairs addObject:pairThumbnailUpDown];
    
    return arrayPairs;
}

- (UIUserNotificationCategory *)createNotificationCategory
{
    UIMutableUserNotificationCategory *category = [[UIMutableUserNotificationCategory alloc] init];
    category.identifier = self.categoryIdentifier;
    UIMutableUserNotificationAction *action1 = [[UIMutableUserNotificationAction alloc] init];
    action1.identifier = [NSString stringWithFormat:@"%d", self.action1];
    action1.title = [self.button1 stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    action1.activationMode = self.executeFg1 ? UIUserNotificationActivationModeForeground : UIUserNotificationActivationModeBackground;
    action1.authenticationRequired = NO;
    action1.destructive = NO;
    UIMutableUserNotificationAction *action2 = [[UIMutableUserNotificationAction alloc] init];
    action2.identifier = [NSString stringWithFormat:@"%d", self.action2];
    action2.title = [self.button2 stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    action2.activationMode = self.executeFg2 ? UIUserNotificationActivationModeForeground : UIUserNotificationActivationModeBackground;
    action2.authenticationRequired = NO;
    action2.destructive = NO;
    [category setActions:@[action1, action2] forContext:UIUserNotificationActionContextDefault];
    [category setActions:@[action1, action2] forContext:UIUserNotificationActionContextMinimal];
    return category;
}

- (UNNotificationCategory *)createUNNotificationCategory
{
    NSString *identifier1 = [NSString stringWithFormat:@"%d", self.action1];
    NSString *title1 = [self.button1 stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    UNNotificationActionOptions option1 = self.executeFg1 ? UNNotificationActionOptionForeground : UNNotificationActionOptionNone;
    UNNotificationAction *action1 = [UNNotificationAction actionWithIdentifier:identifier1 title:title1 options:option1];
    NSString *identifier2 = [NSString stringWithFormat:@"%d", self.action2];
    NSString *title2 = [self.button2 stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    UNNotificationActionOptions option2 = self.executeFg2 ? UNNotificationActionOptionForeground : UNNotificationActionOptionNone;
    UNNotificationAction *action2 = [UNNotificationAction actionWithIdentifier:identifier2 title:title2 options:option2];
    UNNotificationCategory *category = [UNNotificationCategory categoryWithIdentifier:self.categoryIdentifier actions:@[action1, action2] intentIdentifiers:@[] options:UNNotificationCategoryOptionCustomDismissAction]; //dismiss action also call delegate to send push result
    return category;
}

+ (void)addCategory:(UIUserNotificationCategory *)category toSet:(NSMutableSet<UIUserNotificationCategory *> *)set
{
    NSAssert(category != nil, @"Cannot add nil category.");
    NSAssert(set != nil, @"Cannot add category to nil set.");
    NSAssert(category.identifier != nil && category.identifier.length > 0, @"Category's identifier cannot be empty.");
    if (category != nil && set != nil && category.identifier.length > 0)
    {
        UIUserNotificationCategory *findCategory = nil;
        for (UIUserNotificationCategory *item in set)
        {
            if ([item.identifier compare:category.identifier] == NSOrderedSame) //category is case sensitive
            {
                findCategory = item;
                break;
            }
        }
        if (findCategory != nil)  //remove existing and add new.
        {
            [set removeObject:findCategory];
        }
        [set addObject:category];
    }
}

+ (void)addUNCategory:(UNNotificationCategory *)category toSet:(NSMutableSet<UNNotificationCategory *> *)set
{
    NSAssert(category != nil, @"Cannot add nil category.");
    NSAssert(set != nil, @"Cannot add category to nil set.");
    NSAssert(category.identifier != nil && category.identifier.length > 0, @"Category's identifier cannot be empty.");
    if (category != nil && set != nil && category.identifier.length > 0)
    {
        UNNotificationCategory *findCategory = nil;
        for (UNNotificationCategory *item in set)
        {
            if ([item.identifier compare:category.identifier] == NSOrderedSame) //category is case sensitive
            {
                findCategory = item;
                break;
            }
        }
        if (findCategory != nil)  //remove existing and add new.
        {
            [set removeObject:findCategory];
        }
        [set addObject:category];
    }
}

+ (void)addCustomisedButtonPairsToSet:(NSMutableSet *)set
{
    NSArray *arrayPairs = [[NSUserDefaults standardUserDefaults] objectForKey:SH_INTERACTIVEPUSH_KEY]; //purely customer's, not include predefined.
    for (NSDictionary *dict in arrayPairs)
    {
        NSString *pairTitle = dict[SH_INTERACTIVEPUSH_PAIR];
        NSString *b1Title = dict[SH_INTERACTIVEPUSH_BUTTON1];
        NSString *b2Title = dict[SH_INTERACTIVEPUSH_BUTTON2];
        SHInteractiveButtons *pairCustomize = [[SHInteractiveButtons alloc] init];
        pairCustomize.categoryIdentifier = pairTitle;
        pairCustomize.button1 = b1Title;
        pairCustomize.action1 = SHNotificationActionResult_Yes; //Hard code for button 1
        pairCustomize.executeFg1 = YES; //customized button always execute in foreground
        pairCustomize.button2 = b2Title;
        pairCustomize.action2 = SHNotificationActionResult_NO;
        pairCustomize.executeFg2 = YES;
        [self addCategory:[pairCustomize createNotificationCategory] toSet:set];
    }
}

+ (void)addUNCustomisedButtonPairsToSet:(NSMutableSet<UNNotificationCategory *> *)set
{
    NSArray *arrayPairs = [[NSUserDefaults standardUserDefaults] objectForKey:SH_INTERACTIVEPUSH_KEY]; //purely customer's, not include predefined.
    for (NSDictionary *dict in arrayPairs)
    {
        NSString *pairTitle = dict[SH_INTERACTIVEPUSH_PAIR];
        NSString *b1Title = dict[SH_INTERACTIVEPUSH_BUTTON1];
        NSString *b2Title = dict[SH_INTERACTIVEPUSH_BUTTON2];
        SHInteractiveButtons *pairCustomize = [[SHInteractiveButtons alloc] init];
        pairCustomize.categoryIdentifier = pairTitle;
        pairCustomize.button1 = b1Title;
        pairCustomize.action1 = SHNotificationActionResult_Yes; //Hard code for button 1
        pairCustomize.executeFg1 = YES; //customized button always execute in foreground
        pairCustomize.button2 = b2Title;
        pairCustomize.action2 = SHNotificationActionResult_NO;
        pairCustomize.executeFg2 = YES;
        [self addUNCategory:[pairCustomize createUNNotificationCategory] toSet:set];
    }
}

+ (NSMutableArray *)predefinedLocalPairs
{
    NSMutableArray *array = [NSMutableArray array];
    for (SHInteractiveButtons *obj in [self predefinedPairs])
    {
        if (obj.isSubmitToServer)
        {
            NSMutableDictionary *dictPair = [NSMutableDictionary dictionary];
            dictPair[SH_INTERACTIVEPUSH_PAIR] = NONULL(obj.categoryIdentifier);
            dictPair[SH_INTERACTIVEPUSH_BUTTON1] = NONULL(obj.button1);
            dictPair[SH_INTERACTIVEPUSH_BUTTON2] = NONULL(obj.button2);
            [array addObject:dictPair];
        }
    }
    return array;
}

+ (BOOL)pairTitle:(NSString *)pairTitle andButton1:(NSString *)button1 andButton2:(NSString *)button2 isUsed:(NSArray *)arrayPairs
{
    BOOL isUsed = NO;
    NSAssert(!shStrIsEmpty(pairTitle), @"Compare interactive pair buttons cannot use empty pair title.");
    for (NSDictionary *dict in arrayPairs)
    {
        if ([dict[SH_INTERACTIVEPUSH_PAIR] compare:pairTitle] == NSOrderedSame)
        {
            if (button1 == nil && button2 == nil) //here cannot use `shStrIsEmpty`, because if pass in "" it will compare.
            {
                return YES; //button 1 and button 2 are not used for compare, find the match pair title.
            }
            if ((button1 == nil || [dict[SH_INTERACTIVEPUSH_BUTTON1] compare:button1] == NSOrderedSame)
                && (button2 == nil || [dict[SH_INTERACTIVEPUSH_BUTTON2] compare:button2] == NSOrderedSame))
            {
                return YES;
            }
        }
    }
    return isUsed;
}

+ (void)submitInteractivePairButtons
{
    if (!shStrIsEmpty(StreetHawk.currentInstall.suid))
    {
        NSMutableDictionary *dictButtons = [NSMutableDictionary dictionary];
        //Read interactie pairs from predefined out-of-box.
        for (NSDictionary *dict in [self predefinedLocalPairs])
        {
            NSString *pairTitle = dict[SH_INTERACTIVEPUSH_PAIR];
            NSString *b1Title = dict[SH_INTERACTIVEPUSH_BUTTON1];
            NSString *b2Title = dict[SH_INTERACTIVEPUSH_BUTTON2];
            dictButtons[pairTitle] = @[b1Title, b2Title];
        }
        //Read interactive pairs from customer's.
        NSArray *arrayPairs = [[NSUserDefaults standardUserDefaults] objectForKey:SH_INTERACTIVEPUSH_KEY];
        for (NSDictionary *dict in arrayPairs)
        {
            NSString *pairTitle = dict[SH_INTERACTIVEPUSH_PAIR];
            NSString *b1Title = dict[SH_INTERACTIVEPUSH_BUTTON1];
            NSString *b2Title = dict[SH_INTERACTIVEPUSH_BUTTON2];
            dictButtons[pairTitle] = @[b1Title, b2Title];
        }
        //If has pairs to submit, do it.
        if (dictButtons.allKeys.count > 0)
        {
            SHHTTPSessionManager *sessionManager = [SHHTTPSessionManager sharedInstance];
            sessionManager.requestSerializer = [SHAFJSONRequestSerializer serializer]; //Temp solution: this API must use JSON.
            [sessionManager POST:@"apps/submit_interactive_button/" hostVersion:SHHostVersion_V2 body:@{@"installid": NONULL(StreetHawk.currentInstall.suid), @"button": dictButtons} success:nil failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nullable error)
             {
                 SHLog(@"Fail to submit interactive button pairs: %@", error); //submit button pairs not show error dialog to bother customer.
             }];
        }
    }
}

@end
