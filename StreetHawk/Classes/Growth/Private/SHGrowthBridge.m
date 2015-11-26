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

#import "SHGrowthBridge.h"
//header from StreetHawk
#import "SHGrowth.h" //for SHGrowth instance
#import "SHInstall.h" //for install notification names

@interface SHGrowthBridge (private)

+ (void)increaseGrowthHandler:(NSNotification *)notification; //for handle increase growth. notification name: SH_GrowthBridge_Increase_Notification; user info: @{url: string_url}.

@end

@implementation SHGrowthBridge

#pragma mark - public

+ (void)bridgeHandler:(NSNotification *)notification
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(increaseGrowthHandler:) name:@"SH_GrowthBridge_Increase_Notification" object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:[SHGrowth sharedInstance] selector:@selector(installRegistrationSucceededForGrowth:) name:SHInstallRegistrationSuccessNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:[SHGrowth sharedInstance] selector:@selector(installUpdateSucceededForGrowth:) name:SHInstallUpdateSuccessNotification object:nil];
}

#pragma mark - private

+ (void)increaseGrowthHandler:(NSNotification *)notification
{
    NSString *url = notification.userInfo[@"url"];
    NSAssert(url != nil, @"\"url\" in increaseGrowthHandler should not be nil.");
    [[SHGrowth sharedInstance] increaseGrowth:url withHandler:nil];
}

@end
