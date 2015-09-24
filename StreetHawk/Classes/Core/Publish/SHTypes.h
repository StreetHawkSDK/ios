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

#ifndef SH_Types_h
#define StreetHawkCore_StreetHawkTypes_h

/**
 Callback handler with a result or an error.
 
 * If successfully result is the requested object, error is nil.
 * if fail result is nil, error is NSError for failure details.
 */
typedef void (^SHCallbackHandler)(NSObject *result, NSError *error);

/**
 Enum for development platforms.
 */
enum SHDevelopmentPlatform
{
    /**
     Native iOS build by Xcode. Most Apps use this, and it's default.
     */
    SHDevelopmentPlatform_Native,
    /**
     Phonegap Apps.
     */
    SHDevelopmentPlatform_Phonegap,
    /**
     Titanium Apps.
     */
    SHDevelopmentPlatform_Titanium,
    /**
     Xamarin Apps.
     */
    SHDevelopmentPlatform_Xamarin,
    /**
     Unity Apps.
     */
    SHDevelopmentPlatform_Unity,
};
typedef enum SHDevelopmentPlatform SHDevelopmentPlatform;

/**
 Defined as common error domain reported from StreetHawk.
 */
#define SHErrorDomain  @"SHErrorDomain"

/**
 Make sure not pass nil or NSNull, this is useful to avoid insert nil to NSArray and cause crash.
 */
#define NONULL(str)     ((str && str != (id)[NSNull null]) ? (str) : @"")

#endif
