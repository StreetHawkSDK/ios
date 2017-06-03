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
#import "SHUtils.h" //for shFormatISODate
#import "SHHTTPSessionManager.h" //for sending request
//header from System
#import <objc/runtime.h> //for associate object

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

-(void)sendCrashReportForInstall:(NSString *)installId withContent:(NSString *)crashReportContent onCrashDate:(NSDate *)crashDate withHandler:(SHCallbackHandler)handler
{
    if (!streetHawkIsEnabled())
    {
        return;
    }
    if (self.isSendingCrashReport)
        return;
    self.isSendingCrashReport = YES;
    handler = [handler copy];
    [[SHHTTPSessionManager sharedInstance] POST:[NSString stringWithFormat:@"installs/%@/crash/", installId] hostVersion:SHHostVersion_V1 constructingBodyWithBlock:^(id<SHAFMultipartFormData> formData)
    {
        [formData appendPartWithFileData:[crashReportContent dataUsingEncoding:NSUTF8StringEncoding] name:@"exception_file" fileName:@"Crash Report" mimeType:@"text/text"];
        [formData appendPartWithFormData:[shFormatISODate(crashDate) dataUsingEncoding:NSUTF8StringEncoding] name:@"created"];
    } success:^(NSURLSessionDataTask *task, id  _Nullable responseObject)
    {
        self.isSendingCrashReport = NO;
        if (handler)
        {
            handler(nil, nil);
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError *error)
    {
        self.isSendingCrashReport = NO;
        if (handler)
        {
            handler(nil, error);
        }
    }];
}

@end
