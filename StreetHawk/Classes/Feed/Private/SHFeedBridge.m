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

#import "SHFeedBridge.h"
//header from StreetHawk
#import "SHApp+Feed.h"
#import "SHUtils.h" //for SHLog
#import "SHApp.h" //for `StreetHawk.currentInstall`
#import "SHLogger.h" //for sending logline
#import "SHRequest.h" //for sending request

@interface SHFeedBridge ()

+ (void)setFeedTimestampHandler:(NSNotification *)notification; //for set app_status's feed time stamp. notification name: SH_LMBridge_SetFeedTimestamp; user info: @{@"timestamp": NONULL(feedTimestamp)}].

@end

@implementation SHFeedBridge

+ (void)bridgeHandler:(NSNotification *)notification
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setFeedTimestampHandler:) name:@"SH_LMBridge_SetFeedTimestamp" object:nil];
}

#pragma mark - private functions

+ (void)setFeedTimestampHandler:(NSNotification *)notification
{
    NSString *feedTimestamp = notification.userInfo[@"timestamp"];
    if (StreetHawk.currentInstall == nil)
    {
        return; //not register yet, wait for next time.
    }
    if (StreetHawk.newFeedHandler == nil)
    {
        return; //no need to continue if user not setup fetch handler
    }
    if (!streetHawkIsEnabled())
    {
        return;
    }
    if (feedTimestamp != nil && [feedTimestamp isKindOfClass:[NSString class]])
    {
        NSDate *serverTime = shParseDate(feedTimestamp, 0);
        if (serverTime != nil)
        {
            BOOL needFetch = NO;
            NSObject *localTimeVal = [[NSUserDefaults standardUserDefaults] objectForKey:APPSTATUS_FEED_FETCH_TIME];
            if (localTimeVal == nil || ![localTimeVal isKindOfClass:[NSNumber class]])
            {
                needFetch = YES;  //local never fetched, do fetch.
            }
            else
            {
                NSDate *localTime = [NSDate dateWithTimeIntervalSinceReferenceDate:[(NSNumber *)localTimeVal doubleValue]];
                if ([localTime compare:serverTime] == NSOrderedAscending)
                {
                    needFetch = YES;  //local fetched, but too old, do fetch.
                }
            }
            if (needFetch)
            {
                //update local cache time before notice user and send request, because this request has same format as others {app_status:..., code:0, value:...}, it will trigger `setFeedTimestamp` again. Customer's code controls feed function, they can do fetch anytime want.
                [[NSUserDefaults standardUserDefaults] setObject:@([[NSDate date] timeIntervalSinceReferenceDate]) forKey:APPSTATUS_FEED_FETCH_TIME];
                [[NSUserDefaults standardUserDefaults] synchronize];
                StreetHawk.newFeedHandler(); //just notice user, not do fetch actually.
            }
        }
    }
}

@end
