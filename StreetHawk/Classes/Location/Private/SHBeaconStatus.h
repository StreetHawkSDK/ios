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

/**
 The object to handle beacon status inside SHAppStatus.
 */
@interface SHBeaconStatus : NSObject

/**
 Singleton for get app status instance.
 */
+ (SHBeaconStatus *)sharedInstance;

/**
 Match to `app_status` dictionary's `ibeacon`. It's a time stamp of server provided iBeacon list. If the time stamp is newer than client fetch time, client should fetch iBeacon list again and monitor new list; if the time stamp is NULL, client should clear cached iBeacon and stop monitor.
 */
@property (nonatomic, strong) NSString *iBeaconTimestamp;

@end
