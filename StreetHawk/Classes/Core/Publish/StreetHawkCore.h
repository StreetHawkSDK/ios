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

#ifndef SH__STREETHAWK__H
#define SH__STREETHAWK__H

//Core
#import "PushDataForApplication.h"
#import "SHApp.h"
#import "SHBaseViewController.h"
#import "SHFriendlyNameObject.h"
#import "SHInstall.h"
#import "SHObject.h"
#import "SHTypes.h"

//Crash
#ifdef SH_FEATURE_CRASH
#import "SHApp+Crash.h"
#endif

//Feed
#ifdef SH_FEATURE_FEED
#import "SHFeedObject.h"
#import "SHApp+Feed.h"
#endif

//Growth
#ifdef SH_FEATURE_GROWTH
#import "SHApp+Growth.h"
#endif

//Location
#if defined(SH_FEATURE_LATLNG) || defined(SH_FEATURE_GEOFENCE) || defined(SH_FEATURE_IBEACON)
#import "SHApp+Location.h"
#endif

//Notification
#ifdef SH_FEATURE_NOTIFICATION
#import "ISHCustomiseHandler.h"
#import "ISHPhonegapObserver.h"
#import "SHApp+Notification.h"
#endif

#endif //SH__STREETHAWK__H
