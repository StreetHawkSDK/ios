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

#import "SHCrashBridge.h"
//header from StreetHawk
#import "SHApp+Crash.h"
#import "SHCrashHandler.h"
#import "SHUtils.h" //for SHLog
//header from System
#import <mach/mach.h>
#import <mach/mach_host.h>

@interface SHCrashBridge ()

+ (void)createCrashHandler:(NSNotification *)notification; //for creating crash handler when register. notification name: SH_CrashBridge_CreateObject; user info: empty.
+ (void)installUpdateSucceededForCrash:(NSNotification *)notification; //Handle install update notification for sending crash report.

@end

@implementation SHCrashBridge

+ (void)bridgeHandler:(NSNotification *)notification
{
    //initialise variables, move from SHApp's init.
    StreetHawk.isEnableCrashReport = YES;
    StreetHawk.isSendingCrashReport = NO;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(createCrashHandler:) name:@"SH_CrashBridge_CreateObject" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(installUpdateSucceededForCrash:) name:SHInstallUpdateSuccessNotification object:nil];
}

+ (void)createCrashHandler:(NSNotification *)notification
{
    if (StreetHawk.isEnableCrashReport)
    {
        StreetHawk.crashHandler = [[SHCrashHandler alloc] init];
        [StreetHawk.crashHandler enableCrashReporter];
    }
}

+ (void)installUpdateSucceededForCrash:(NSNotification *)aNotification
{
    //note: after install/update, not call "registerForRemoteNotification", because "registerForRemoteNotification" calls install/update after: a)successfully register and get new token; b)unregister and send install/update with revoked.
    //update crash logs if any
    if ([StreetHawk.crashHandler hasPendingCrashReport])
    {
        NSString *crashReport = [StreetHawk.crashHandler loadPendingCrashReport];
        if (crashReport == nil)
        {
            [StreetHawk.crashHandler purgePendingCrashReport]; //fail to load, purge to avoid next loading
            return;
        }
        //PLCrashReporter generates text with "TODO", replace that to be "".
        crashReport = [crashReport stringByReplacingOccurrencesOfString:@"TODO" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, crashReport.length)];
        //Add more information. CrashReporter Key:   [Development platform], [AppStore/Simulator/Other], [SDK Version, e.g. 1/1.3.2], [Install Id, e.g. ABDEF2CBF6CYX927], [battery], [memory]
        //battery
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
        NSString *battery = [UIDevice currentDevice].batteryLevel < 0.0 ? @"unknown" : [NSString stringWithFormat:@"%.0f%%", [UIDevice currentDevice].batteryLevel * 100];
        //memory
        NSString *memoryUsage = nil;
        mach_port_t host_port;
        mach_msg_type_number_t host_size;
        vm_size_t pagesize;
        host_port = mach_host_self();
        host_size = sizeof(vm_statistics_data_t) / sizeof(integer_t);
        host_page_size(host_port, &pagesize);
        vm_statistics_data_t vm_stat;
        if (host_statistics(host_port, HOST_VM_INFO, (host_info_t)&vm_stat, &host_size) != KERN_SUCCESS)
        {
            memoryUsage = @"Failed to fetch memory statistics";
        }
        else
        {
            natural_t mem_used = (natural_t)((vm_stat.active_count + vm_stat.inactive_count + vm_stat.wire_count) * pagesize);
            natural_t mem_free = (natural_t)(vm_stat.free_count * pagesize);
            natural_t mem_total = mem_used + mem_free;
            memoryUsage = [NSString stringWithFormat:@"used %llu MB free %llu MB total %llu MB", ((mem_used/1024ll)/1024ll), ((mem_free/1024ll)/1024ll), ((mem_total/1024ll)/1024ll)];
        }
        NSString *infoStr = [NSString stringWithFormat:@"CrashReporter Key:   %@, %@, %@, %@, Battery %@, Memory: %@", shDevelopmentPlatformString(), shAppModeString(shAppMode()), StreetHawk.version, StreetHawk.currentInstall.suid, battery, memoryUsage];
        crashReport = [crashReport stringByReplacingOccurrencesOfString:@"CrashReporter Key:   " withString:infoStr];
        //store MD5 in NSUserDefaults and compare with next send to avoid double reporting of crashlogs
        NSString *md5 = [crashReport md5];
        NSString *previousSend = [[NSUserDefaults standardUserDefaults] objectForKey:@"CrashLog_MD5"];
        if (previousSend != md5)
        {
            NSDate *crashDate = [StreetHawk.crashHandler crashReportDate] == nil ? [NSDate date] : [StreetHawk.crashHandler crashReportDate];
            [StreetHawk sendCrashReportForInstall:StreetHawk.currentInstall.suid withContent:crashReport onCrashDate:crashDate withHandler:^(id result, NSError *error)
             {
                 if (!error)
                 {
                     SHLog(@"Crash Log Uploaded: %@", crashReport);
                     [StreetHawk.crashHandler purgePendingCrashReport]; //OK, load successfully, purge local.
                     [[NSUserDefaults standardUserDefaults] setObject:md5 forKey:@"CrashLog_MD5"];
                 }
             }];
        }
        else
        {
            [StreetHawk.crashHandler purgePendingCrashReport]; //Same as before, purge local.
        }
    }
}

@end
