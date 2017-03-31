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
 The object to handle geofence status inside SHAppStatus.
 */
@interface SHGeofenceStatus : NSObject

/**
 Singleton for get app status instance.
 */
+ (SHGeofenceStatus *)sharedInstance;

/**
 Match to `app_status` dictionary's `geofences`. It's a time stamp of server provided geofence list. If the time stamp is newer than client fetch time, client should fetch geofence list again and monitor new list; if the time stamp is NULL or empty, client should clear cached geofence and stop monitor.
 */
@property (nonatomic, strong) NSString *geofenceTimestamp;

@end
