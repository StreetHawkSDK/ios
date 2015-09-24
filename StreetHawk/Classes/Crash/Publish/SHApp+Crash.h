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

@class SHCrashHandler;

/**
 Extension for Crash API.
 */
@interface SHApp (CrashExt)

/**
 StreetHawk uses PLCrashReport to collect App's crash report and upload to StreetHawk server when next launch the App. You can check crash report on web site. It's enabled by default.
 Note: if would like to disable crash report, suggest set this property before "registerInstallForApp" to avoid loading PLCrashReport. 
 */
@property (nonatomic) BOOL isEnableCrashReport;

/**
 Handler for crash report stuff.
 */
@property (nonatomic, strong) SHCrashHandler *crashHandler;

/**
 To avoid sending twice, for example SHDemo location update and login happen same time, cause two install/update happen. This should be private however category class cannot define property in private interface.
 */
@property (nonatomic) BOOL isSendingCrashReport;

@end
