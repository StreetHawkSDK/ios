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

#import "SHCrashHandler.h"
//header from StreetHawk
#import "SHLogger.h" //for sending logline
//header from Third-party
//The downloaded binary is Framework style, however if use Framework it's not built inside StreetHawk.Framework, cause the calling App such as Peeptoe.project needs to include CrashReport.Framework explictly. This is not expected. A tricky is to use this as lib and header files, thus the lib is built inside.
#import "CrashReporter.h"

@implementation SHCrashHandler

- (BOOL)enableCrashReporter
{
    NSError *error;
    BOOL isEnabled = [[PLCrashReporter sharedReporter] enableCrashReporterAndReturnError: &error];
    if (!isEnabled)
    {
        [StreetHawk sendLogForCode:LOG_CODE_ERROR withComment:[NSString stringWithFormat:@"Could not enable crash reporter: %@", error]];
    }
    return isEnabled;
}

- (BOOL)hasPendingCrashReport
{
    return [[PLCrashReporter sharedReporter] hasPendingCrashReport];
}

- (NSString *)loadPendingCrashReport
{
    NSError *error;
    NSData *crashData = [[PLCrashReporter sharedReporter] loadPendingCrashReportDataAndReturnError:&error];
    if (crashData == nil)
    {
        [StreetHawk sendLogForCode:LOG_CODE_ERROR withComment:[NSString stringWithFormat:@"Could not load crash report: %@", error]];
        return nil;
    }
    PLCrashReport *report = [[PLCrashReport alloc] initWithData:crashData error:&error];
    if (report == nil)
    {
        [StreetHawk sendLogForCode:LOG_CODE_ERROR withComment:[NSString stringWithFormat:@"Could not parse crash report: %@", error]];
        return nil;
    }
    return [PLCrashReportTextFormatter stringValueForCrashReport:report withTextFormat:PLCrashReportTextFormatiOS];
}

- (NSDate *)crashReportDate
{
    NSError *error;
    NSData *crashData = [[PLCrashReporter sharedReporter] loadPendingCrashReportDataAndReturnError:&error];
    if (crashData == nil)
    {
        [StreetHawk sendLogForCode:LOG_CODE_ERROR withComment:[NSString stringWithFormat:@"Could not load crash report: %@", error]];
        return nil;
    }
    PLCrashReport *report = [[PLCrashReport alloc] initWithData:crashData error:&error];
    if (report == nil)
    {
        [StreetHawk sendLogForCode:LOG_CODE_ERROR withComment:[NSString stringWithFormat:@"Could not parse crash report: %@", error]];
        return nil;
    }
    return report.systemInfo.timestamp;
}

- (BOOL)purgePendingCrashReport
{
    NSError *error;
    BOOL isPurged = [[PLCrashReporter sharedReporter] purgePendingCrashReportAndReturnError:&error];
    if (!isPurged)
    {
        [StreetHawk sendLogForCode:LOG_CODE_ERROR withComment:[NSString stringWithFormat:@"Could not purge crash reporter: %@", error]];
    }
    return isPurged;
}

@end
