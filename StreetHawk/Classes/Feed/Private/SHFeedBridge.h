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

#define APPSTATUS_FEED_FETCH_TIME           @"APPSTATUS_FEED_FETCH_TIME"  //last successfully fetch feed time

/**
 Bridge for handle beacon module notifications.
 */
@interface SHFeedBridge : NSObject

/**
 Static entry point for bridge init.
 */
+ (void)bridgeHandler:(NSNotification *)notification;

@end
