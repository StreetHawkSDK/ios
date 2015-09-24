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

#import "SHApp.h" //for extension SHApp
#import "SHFeedObject.h" //for SHNewFeedsHandler and SHFeedsFetchHandler

/**
 Extension for Feed API.
 */
@interface SHApp (FeedExt)

/**
 Callback happen when new feed detects by app_status/feed.
 */
@property (nonatomic, copy) SHNewFeedsHandler newFeedHandler;

/**
 Fetch feeds starting from `offset`.
 @param offset Offset from which to fetch.
 @param handler Callback for fetch handler, which return NSArray of SHFeedObject and error if meet.
 */
- (void)feed:(NSInteger)offset withHandler:(SHFeedsFetchHandler)handler;

/**
 Send no priority logline for feedack. Customer developer should call this when a feed is read. Server may receive multiple loglines if user read one feed many times.
 @param feed_id The feed id of reading feed.
 */
- (void)sendFeedAck:(NSInteger)feed_id;

/**
 Send no priority logline for feed result.
 @param feed_id The feed id of result feed.
 @param result The result for accept, or postpone or decline.
 */
- (void)sendLogForFeed:(NSInteger)feed_id withResult:(SHResult)result;

@end
