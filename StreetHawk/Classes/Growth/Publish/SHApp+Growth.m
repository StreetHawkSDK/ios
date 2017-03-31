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

#import "SHApp+Growth.h"
#import "SHGrowth.h"

@implementation SHApp (GrowthExt)

- (void)originateShareWithCampaign:(NSString *)utm_campaign withSource:(NSString *)utm_source withMedium:(NSString *)utm_medium withContent:(NSString *)utm_content withTerm:(NSString *)utm_term shareUrl:(NSURL *)shareUrl withDefaultUrl:(NSURL *)default_url streetHawkGrowth_object:(SHCallbackHandler)handler
{
    [[SHGrowth sharedInstance] originateShareWithCampaign:utm_campaign withSource:utm_source withMedium:utm_medium withContent:utm_content withTerm:utm_term shareUrl:shareUrl withDefaultUrl:default_url streetHawkGrowth_object:handler];
}

- (void)originateShareWithCampaign:(NSString *)utm_campaign withMedium:(NSString *)utm_medium withContent:(NSString *)utm_content withTerm:(NSString *)utm_term shareUrl:(NSURL *)shareUrl withDefaultUrl:(NSURL *)default_url withMessage:(NSString *)message
{
    [[SHGrowth sharedInstance] originateShareWithCampaign:utm_campaign withMedium:utm_medium withContent:utm_content withTerm:utm_term shareUrl:shareUrl withDefaultUrl:default_url withMessage:message];
}

@end
