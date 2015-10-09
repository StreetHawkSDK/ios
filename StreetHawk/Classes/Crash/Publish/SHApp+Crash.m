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

#import "SHApp+Crash.h"
//header from StreetHawk
#import "SHCrashHandler.h" //for create instance
#import "SHUtils.h" //for SHLog
#import "SHRequest.h" //for sending request
//header from System
#import <objc/runtime.h> //for associate object
#import <CommonCrypto/CommonDigest.h>
#import <mach/mach.h>
#import <mach/mach_host.h>

@interface SHApp (Private)

//Handle install update notification for sending crash report.
- (void)installUpdateSucceededForCrash:(NSNotification *)aNotification;
//Get MD5 of a string
- (NSString*)getMD5Checksum:(NSString*)content;
//Sends crash report content info to the server.
- (void)sendCrashReportForInstall:(NSString *)installId withContent:(NSString *)crashReportContent onCrashDate:(NSDate *)crashDate withHandler:(SHCallbackHandler)handler;

@end

@implementation SHApp (CrashExt)

#pragma mark - properties

@dynamic isEnableCrashReport;
@dynamic crashHandler;
@dynamic isSendingCrashReport;

- (void)setIsEnableCrashReport:(BOOL)isEnableCrashReport
{
    if (self.isEnableCrashReport != isEnableCrashReport && self.logger != nil) //registerForInstall already called, and set property to change after register.
    {
        if (self.isEnableCrashReport)  //from enable to disable
        {
            self.crashHandler = nil;
        }
        else //from disable to enable
        {
            self.crashHandler = [[SHCrashHandler alloc] init];
            [self.crashHandler enableCrashReporter];
        }
    }
    objc_setAssociatedObject(self, @selector(isEnableCrashReport), [NSNumber numberWithBool:isEnableCrashReport], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)isEnableCrashReport
{
    NSNumber *value = objc_getAssociatedObject(self, @selector(isEnableCrashReport));
    return [value boolValue];
}

- (SHCrashHandler *)crashHandler
{
    return objc_getAssociatedObject(self, @selector(crashHandler));
}

- (void)setCrashHandler:(SHCrashHandler *)crashHandler
{
    objc_setAssociatedObject(self, @selector(crashHandler), crashHandler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)isSendingCrashReport
{
    NSNumber *value = objc_getAssociatedObject(self, @selector(isSendingCrashReport));
    return [value boolValue];
}

- (void)setIsSendingCrashReport:(BOOL)isSendingCrashReport
{
    objc_setAssociatedObject(self, @selector(isSendingCrashReport), [NSNumber numberWithBool:isSendingCrashReport], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - private functions

- (void)installUpdateSucceededForCrash:(NSNotification *)aNotification
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
        NSString *md5 = [self getMD5Checksum:crashReport];
        NSString *previousSend = [[NSUserDefaults standardUserDefaults] objectForKey:@"CrashLog_MD5"];
        if (previousSend != md5)
        {
            NSDate *crashDate = [StreetHawk.crashHandler crashReportDate] == nil ? [NSDate date] : [StreetHawk.crashHandler crashReportDate];
            [self sendCrashReportForInstall:StreetHawk.currentInstall.suid withContent:crashReport onCrashDate:crashDate withHandler:^(id result, NSError *error)
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

- (NSString*)getMD5Checksum:(NSString*)content
{
    const char *cStr = [[NSData dataWithContentsOfFile:content] bytes];
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    NSInteger length = [[NSData dataWithContentsOfFile:content] length]; // strlen(cStr);
    CC_MD5(cStr, (int)length, result);
    return [NSString stringWithFormat:
            @"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X", result[0], result[1], result[2], result[3], result[4], result[5], result[6], result[7], result[8], result[9], result[10], result[11], result[12], result[13], result[14], result[15]];
}

-(void)sendCrashReportForInstall:(NSString *)installId withContent:(NSString *)crashReportContent onCrashDate:(NSDate *)crashDate withHandler:(SHCallbackHandler)handler
{
    if (!streetHawkIsEnabled())
    {
        return;
    }
    if (self.isSendingCrashReport)
        return;
    self.isSendingCrashReport = YES;
    NSString *upload_url = [NSString stringWithFormat:@"installs/%@/crash/", installId];
    NSMutableData *body = [NSMutableData data];
    NSMutableString *enclosingString = [NSMutableString string];
    [enclosingString appendString:@"-----------------------------114896232643685925846960113\r\n"];
    [enclosingString appendFormat:@"Content-Disposition: form-data; name=\"exception_file\"; filename=\"%@\"\r\n", @"Crash Report"];
    [enclosingString appendString:@"Content-Type: text/text\r\n\r\n"];
    [body appendData:[enclosingString dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[crashReportContent dataUsingEncoding:NSUTF8StringEncoding]];
    enclosingString = [NSMutableString string];
    [enclosingString appendString:@"-----------------------------114896232643685925846960113\r\n"];
    [enclosingString appendString:@"Content-Disposition: form-data; name=\"created\"\r\n\r\n"];
    [enclosingString appendString:shFormatStreetHawkDate(crashDate)];
    [enclosingString appendString:@"\r\n-----------------------------114896232643685925846960113--"];
    [body appendData:[enclosingString dataUsingEncoding:NSUTF8StringEncoding]];
    NSDictionary *header = @{@"Accept": @"*/*", @"Content-Type": @"multipart/form-data; boundary=---------------------------114896232643685925846960113", @"Content-Length": [NSString stringWithFormat:@"%d", (int)body.length]};
    SHRequest *request = [SHRequest requestWithPath:upload_url withVersion:SHHostVersion_V1 withParams:nil withMethod:@"POST" withHeaders:header withBodyOrStream:body];
    handler = [handler copy];
    request.requestHandler = ^(SHRequest *request)
    {
        self.isSendingCrashReport = NO;
        if (handler)
        {
            handler(nil, request.error);
        }
    };
    [request startAsynchronously];
}

@end
