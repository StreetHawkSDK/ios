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
 Handler to deal with crash. It uses open-source CrashReporter.framework. The usage is:
 
 * When App initialized, call `enableCrashReporter` to have crash handler get ready. 
 * If crash happen, the crash report is logged locally. Use `hasPendingCrashReport` to check whether local has pending crash report. 
 * If local has crash report, use `loadPendingCrashReport` to get the report data string. 
 * After send crash report to server, use `purgePendingCrashReport` to clear the local one.
 
 For StreetHawkCoreCompact, remove PLCrashReport to reduce library size, thus only can catch some basic information by `ExceptionHandler`.
 */
@interface SHCrashHandler : NSObject

/**
 Make crash reporter to get ready. If error happen it will log as error event and sent to server.
 */
- (BOOL)enableCrashReporter;

/**
 Whether local has un-sent crash report. 
 */
- (BOOL)hasPendingCrashReport;

/**
 If local has crash report, use this to load the crash report string. It may return nil if fail to load the data. If error happen it will log as error event and sent to server.
 @return The text format is compatible with iTunesConnect download crash report.
 */
- (NSString *)loadPendingCrashReport;

/**
 Return the date parsed from current crash report. If no crash report or fail to load, it's nil.
 */
- (NSDate *)crashReportDate;

/**
 Clear local un-sent crash report. If error happen it will log as error event and sent to server.
 */
- (BOOL)purgePendingCrashReport;

@end
