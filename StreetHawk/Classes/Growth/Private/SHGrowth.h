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
#import "SHTypes.h"

/**
 The StreetHawkGrowth Class is core of Growth.
 
 **Normal usage:**
 
 - StreetHawkGrowth is singleton, access it by `[StreetHawkGrowth sharedInstance]`.
 
 - Before using Growth, must finish StreetHawk onboarding actions.
 
 - When use StreetHawk SDK, Growth automatically register when App launch, customer get this for free. Customer no need to call `registerGrowth:`.
 
 - Growth click increase automatically by StreetHawk SDK too, customer no need to call `increaseGrowth:`.
 
 - Customer call `originateShareWithCampaign:` as demand.
 */
@interface SHGrowth : NSObject

/** @name Create and initialize */

/**
 Singleton creator of StreetHawkGrowth.
 @return Singleton StreetHawkGrowth instance.
 */
+ (SHGrowth *)sharedInstance;

/** @name Public functions */

/**
 Call this function to share and invite friend. It will return a callback with share url, and customer developer is responsible to perform the action to share.
 
 @param utm_campaign Optional, for identify how this share is used for. For example in a book App, it would be "Child", "Computer", "Poetry". It's an Id to be used in StreetHawk Analytics.
 @param utm_source Optional, indicate where share url will be posted (Example facebook, twitter, whatsapp etc). It's free text string.
 @param utm_medium Optional, medium as url will be posted. For example cpc.
 @param utm_content Optional, content of campaign.
 @param utm_term Optional, keywords for campaing.
 @param shareUrl Optional, share url which will open App by browser link. For example, to open App page with parameter, url like "hawk://launchVC?vC=Deep%20Linking&param1=this%20is%20a%20test&param2=123".
 @param default_url Optional, fallback url if user opens url not on iOS or Android mobile devices. It's a normal url to display on browser, for example the developer's website which describes the App, like http://www.myapp.com.
 @param handler Share result callback handler, when successfully share `result` is share_guid_url, otherwise it contains error.
 */
- (void)originateShareWithCampaign:(NSString *)utm_campaign withSource:(NSString *)utm_source withMedium:(NSString *)utm_medium withContent:(NSString *)utm_content withTerm:(NSString *)utm_term shareUrl:(NSURL *)shareUrl withDefaultUrl:(NSURL *)default_url streetHawkGrowth_object:(SHCallbackHandler)handler;

/**
 Call this function to share and invite friend. It will promote a list of StreetHawk supporting share channel, and after user choose the channel, the share content will be shared automatically.
 
 @param utm_campaign Optional, for identify how this share is used for. For example in a book App, it would be "Child", "Computer", "Poetry". It's an Id to be used in StreetHawk Analytics.
 @param utm_medium Optional, medium as url will be posted. For example cpc.
 @param utm_content Optional, content of campaign.
 @param utm_term Optional, keywords for campaing.
 @param shareUrl Optional, share url which will open App by browser link. For example, to open App page with parameter, url like "hawk://launchVC?vC=Deep%20Linking&param1=this%20is%20a%20test&param2=123".
 @param default_url Optional, fallback url if user opens url not on iOS or Android mobile devices. It's a normal url to display on browser, for example the developer's website which describes the App, like http://www.myapp.com.
 @param message The message text which will display in share channel, such as "I would like to recommend an excellent book to you.".
 */
- (void)originateShareWithCampaign:(NSString *)utm_campaign withMedium:(NSString *)utm_medium withContent:(NSString *)utm_content withTerm:(NSString *)utm_term shareUrl:(NSURL *)shareUrl withDefaultUrl:(NSURL *)default_url withMessage:(NSString *)message;

/** @name Internal functions */

/**
 Register Growth. Normally this is called by StreetHawk SDK automatically, customer does not need to call it.
 @param handler Register result callback handler.
 */
- (void)registerGrowth:(SHCallbackHandler)handler;

/**
 Increase click count for Growth. Normally this is called by StreetHawk SDK automatically, customer does not need to call it.
 @param shareUrlStr The share url sent to Growth server, by this Growth can increase click count. Note: Growth server will check parameter "share_guid_url" as identifier, if pass in `shareUrlStr` does not have the parameter, no request send to Growth server. An expected sample: hawk://launchVC?vC=Deep%20Linking&param1=this%20is%20a%20test&param2=123&share_guid_url=http://hwk.io/s/YdpxJh.
 @param handler Result callback handler.
 */
- (void)increaseGrowth:(NSString *)shareUrlStr withHandler:(SHCallbackHandler)handler;

@end
