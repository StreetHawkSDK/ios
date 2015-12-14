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

#import "SHAppStatus.h"
//header from StreetHawk
#import "SHUtils.h" //for SHLog
#import "SHApp.h" //for `StreetHawk.currentInstall`
#import "SHLogger.h" //for sending logline

#define APPSTATUS_STREETHAWKENABLED         @"APPSTATUS_STREETHAWKENABLED" //whether enable library functions
#define APPSTATUS_DEFAULT_HOST              @"APPSTATUS_DEFAULT_HOST" //default starting host url
#define APPSTATUS_ALIVE_HOST                @"APPSTATUS_ALIVE_HOST" //currently used alive host url
#define APPSTATUS_UPLOAD_LOCATION           @"APPSTATUS_UPLOAD_LOCATION" //whether send install/log for location update
#define APPSTATUS_SUBMIT_FRIENDLYNAME       @"APPSTATUS_SUBMIT_FRIENDLYNAME"  //whether server allow submit friendly name
#define APPSTATUS_REREGISTER                @"APPSTATUS_REREGISTER" //a flag set to notice next launch must re-register install
#define APPSTATUS_APPSTOREID                @"APPSTATUS_APPSTOREID" //server push itunes id to client side
#define APPSTATUS_DISABLECODES              @"APPSTATUS_DISABLECODES" //disable logline codes
#define APPSTATUS_PRIORITYCODES             @"APPSTATUS_PRIORITYCODES" //priority logline codes

#define APPSTATUS_CHECK_TIME                @"APPSTATUS_CHECK_TIME"  //the last successfully check app status time, record to avoid frequently call server.

NSString * const SHAppStatusChangeNotification = @"SHAppStatusChangeNotification";

@interface SHAppStatus ()

@property (nonatomic, strong) NSString *aliveHostInner; //inner memory variable

//make sure update happens in sequence for each property
@property (nonatomic) dispatch_semaphore_t semaphore_streethawkEnabled;
@property (nonatomic) dispatch_semaphore_t semaphore_aliveHost;
@property (nonatomic) dispatch_semaphore_t semaphore_uploadLocationChange;
@property (nonatomic) dispatch_semaphore_t semaphore_allowSubmitFriendlyNames;
@property (nonatomic) dispatch_semaphore_t semaphore_appstoreId;
@property (nonatomic) dispatch_semaphore_t semaphore_disableCodes;
@property (nonatomic) dispatch_semaphore_t semaphore_priorityCodes;

@end

@implementation SHAppStatus

#pragma mark - life cycle

+ (void)initialize
{
    if ([self class] == [SHAppStatus class])
	{
        NSMutableDictionary *initialDefaults = [NSMutableDictionary dictionary];
        initialDefaults[APPSTATUS_STREETHAWKENABLED] = @(YES);  //by default sdk is enabled
        initialDefaults[APPSTATUS_DEFAULT_HOST] = @"https://api.streethawk.com";  //by default host is this
        initialDefaults[APPSTATUS_UPLOAD_LOCATION] = @(YES);  //by default allow upload location by install/log
        initialDefaults[APPSTATUS_SUBMIT_FRIENDLYNAME] = @(NO); //by default not allow submit friendly name
        initialDefaults[APPSTATUS_REREGISTER] = @(NO); //by default not need to reregister

        [[NSUserDefaults standardUserDefaults] registerDefaults:initialDefaults];
    }
}

+ (SHAppStatus *)sharedInstance
{
    static SHAppStatus *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        instance = [[SHAppStatus alloc] init];
    });
    return instance;
}

- (id)init
{
    if (self = [super init])
    {
        self.semaphore_streethawkEnabled = dispatch_semaphore_create(1);
        self.semaphore_aliveHost = dispatch_semaphore_create(1);
        self.semaphore_uploadLocationChange = dispatch_semaphore_create(1);
        self.semaphore_allowSubmitFriendlyNames = dispatch_semaphore_create(1);
        self.semaphore_appstoreId = dispatch_semaphore_create(1);
        self.semaphore_disableCodes = dispatch_semaphore_create(1);
        self.semaphore_priorityCodes = dispatch_semaphore_create(1);
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - properties

- (BOOL)streethawkEnabled
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:APPSTATUS_STREETHAWKENABLED];
}

- (void)setStreethawkEnabled:(BOOL)streethawkEnabled
{
    NSAssert(![NSThread isMainThread], @"setStreethawkEnabled wait in main thread.");
    if (![NSThread isMainThread])
    {
        dispatch_semaphore_wait(self.semaphore_streethawkEnabled, DISPATCH_TIME_FOREVER);
        if (self.streethawkEnabled != streethawkEnabled)
        {
            [[NSUserDefaults standardUserDefaults] setBool:streethawkEnabled forKey:APPSTATUS_STREETHAWKENABLED];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [[NSNotificationCenter defaultCenter] postNotificationName:SHAppStatusChangeNotification object:nil];
        }
        dispatch_semaphore_signal(self.semaphore_streethawkEnabled);
    }
}

- (NSString *)defaultHost
{
    return [[NSUserDefaults standardUserDefaults] objectForKey:APPSTATUS_DEFAULT_HOST];
}

- (void)setDefaultHost:(NSString *)defaultHost
{
    if (defaultHost != nil && defaultHost.length > 0)
    {
        //user must guarantee host address is complete and correct, no check here.
        if ([defaultHost hasSuffix:@"/"])
        {
            defaultHost = [defaultHost substringToIndex:defaultHost.length - 1];
        }
        [[NSUserDefaults standardUserDefaults] setObject:defaultHost forKey:APPSTATUS_DEFAULT_HOST];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (NSString *)aliveHostForVersion:(SHHostVersion)hostVersion
{
    //For sake of performance, keep a memory variable instead of fetch from NSUserDefaults each time.
    if (self.aliveHostInner == nil || self.aliveHostInner.length == 0)
    {
        self.aliveHostInner = [[NSUserDefaults standardUserDefaults] objectForKey:APPSTATUS_ALIVE_HOST];
        if (self.aliveHostInner == nil || self.aliveHostInner.length == 0)  //not setup yet, use default one.
        {
            self.aliveHostInner = self.defaultHost;
        }
    }
    if ([self.aliveHostInner hasSuffix:@"/"])
    {
        self.aliveHostInner = [self.aliveHostInner substringToIndex:self.aliveHostInner.length - 1]; //remove last "/"
    }
    switch (hostVersion)
    {
        case SHHostVersion_V1:
            return [NSString stringWithFormat:@"%@/%@", self.aliveHostInner, @"v1"];
            break;
        case SHHostVersion_V2:
            return [NSString stringWithFormat:@"%@/%@", self.aliveHostInner, @"v2"];
        default:
            NSAssert(NO, @"Meet unknown host version;");
            break;
    }
    return nil;
}

- (void)setAliveHost:(NSString *)aliveHost
{
    if (aliveHost != nil && aliveHost.length > 0)
    {
        //server must guarantee host address is complete and correct, no check here.
        if ([aliveHost hasSuffix:@"/"])
        {
            aliveHost = [aliveHost substringToIndex:aliveHost.length - 1]; //remove last "/"
        }
        NSAssert(![NSThread isMainThread], @"setAliveHost wait in main thread.");
        if (![NSThread isMainThread])
        {
            dispatch_semaphore_wait(self.semaphore_aliveHost, DISPATCH_TIME_FOREVER);
            if (self.aliveHostInner == nil) //try to read from local cache first
            {
                self.aliveHostInner = [[NSUserDefaults standardUserDefaults] objectForKey:APPSTATUS_ALIVE_HOST];
            }
            if (self.aliveHostInner == nil || [self.aliveHostInner compare:aliveHost options:NSCaseInsensitiveSearch] != NSOrderedSame)
            {
                NSString *oldHost = self.aliveHostInner;
                //change to new host
                [[NSUserDefaults standardUserDefaults] setObject:aliveHost forKey:APPSTATUS_ALIVE_HOST];
                [[NSUserDefaults standardUserDefaults] synchronize];
                self.aliveHostInner = aliveHost;
                [[NSNotificationCenter defaultCenter] postNotificationName:SHAppStatusChangeNotification object:nil];
                SHLog(@"Host change from %@ to %@.", oldHost, self.aliveHostInner);
            }
            dispatch_semaphore_signal(self.semaphore_aliveHost);
        }
    }
}

- (BOOL)uploadLocationChange
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:APPSTATUS_UPLOAD_LOCATION];
}

- (void)setUploadLocationChange:(BOOL)uploadLocationChange
{
    NSAssert(![NSThread isMainThread], @"setUploadLocationChange wait in main thread.");
    if (![NSThread isMainThread])
    {
        dispatch_semaphore_wait(self.semaphore_uploadLocationChange, DISPATCH_TIME_FOREVER);
        if (self.uploadLocationChange != uploadLocationChange)
        {
            [[NSUserDefaults standardUserDefaults] setBool:uploadLocationChange forKey:APPSTATUS_UPLOAD_LOCATION];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [[NSNotificationCenter defaultCenter] postNotificationName:SHAppStatusChangeNotification object:nil];
        }
        dispatch_semaphore_signal(self.semaphore_uploadLocationChange);
    }
}

- (BOOL)allowSubmitFriendlyNames
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:APPSTATUS_SUBMIT_FRIENDLYNAME];
}

- (void)setAllowSubmitFriendlyNames:(BOOL)allowSubmitFriendlyNames
{
    NSAssert(![NSThread isMainThread], @"setAllowSubmitFriendlyNames wait in main thread.");
    if (![NSThread isMainThread])
    {
        dispatch_semaphore_wait(self.semaphore_allowSubmitFriendlyNames, DISPATCH_TIME_FOREVER);
        if (self.allowSubmitFriendlyNames != allowSubmitFriendlyNames)
        {
            [[NSUserDefaults standardUserDefaults] setBool:allowSubmitFriendlyNames forKey:APPSTATUS_SUBMIT_FRIENDLYNAME];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [[NSNotificationCenter defaultCenter] postNotificationName:SHAppStatusChangeNotification object:nil];        
        }
        dispatch_semaphore_signal(self.semaphore_allowSubmitFriendlyNames);
    }
}

- (NSString *)iBeaconTimestamp
{
    NSAssert(NO, @"Should not call iBeaconTimestamp.");
    return nil;
}

- (void)setIBeaconTimestamp:(NSString *)iBeaconTimestamp
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_LMBridge_SetIBeaconTimestamp" object:nil userInfo:@{@"timestamp": NONULL(iBeaconTimestamp)}];
}

- (NSString *)geofenceTimestamp
{
    NSAssert(NO, @"Should not call geofenceTimestamp.");
    return nil;
}

- (void)setGeofenceTimestamp:(NSString *)geofenceTimestamp
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_LMBridge_SetGeofenceTimestamp" object:nil userInfo:@{@"timestamp": NONULL(geofenceTimestamp)}];
}

- (NSString *)feedTimestamp
{
    NSAssert(NO, @"Should not call feedTimestamp.");
    return nil;
}

- (void)setFeedTimestamp:(NSString *)feedTimestamp
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_LMBridge_SetFeedTimestamp" object:nil userInfo:@{@"timestamp": NONULL(feedTimestamp)}];
}

- (BOOL)reregister
{
    NSAssert(NO, @"Should not call reregister.");
    return NO;
}

- (void)setReregister:(BOOL)reregister
{
    if (reregister)
    {
        //During App running it cannot re-register a fresh install, for example db is running so cannot delete it. Record a flag locally so that next launch will do re-register.
        [[NSUserDefaults standardUserDefaults] setObject:@(YES) forKey:APPSTATUS_REREGISTER];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (NSString *)appstoreId
{
    NSObject *obj = [[NSUserDefaults standardUserDefaults] objectForKey:APPSTATUS_APPSTOREID];
    if ([obj isKindOfClass:[NSString class]] && !shStrIsEmpty((NSString *)obj))
    {
        return (NSString *)obj;
    }
    return nil;
}

- (void)setAppstoreId:(NSString *)appstoreId
{
    NSAssert(![NSThread isMainThread], @"setAppstoreId wait in main thread.");
    if (![NSThread isMainThread])
    {
        dispatch_semaphore_wait(self.semaphore_appstoreId, DISPATCH_TIME_FOREVER);
        if ([appstoreId isKindOfClass:[NSString class]] && !shStrIsEmpty(appstoreId))
        {
            if (shStrIsEmpty(self.appstoreId) || [appstoreId compare:self.appstoreId] != NSOrderedSame) //local not setup or server push a different one
            {
                [[NSUserDefaults standardUserDefaults] setObject:appstoreId forKey:APPSTATUS_APPSTOREID];
                [[NSUserDefaults standardUserDefaults] synchronize];
                [[NSNotificationCenter defaultCenter] postNotificationName:SHAppStatusChangeNotification object:nil];
            }
        }
        dispatch_semaphore_signal(self.semaphore_appstoreId);
    }
}

- (NSObject *)logDisableCodes
{
    NSAssert(NO, @"Should not call logDisableCodes.");
    return nil;
}

- (void)setLogDisableCodes:(NSObject *)logDisableCodes
{
    NSAssert(![NSThread isMainThread], @"setLogDisableCodes wait in main thread.");
    if (![NSThread isMainThread])
    {
        dispatch_semaphore_wait(self.semaphore_disableCodes, DISPATCH_TIME_FOREVER);
        NSArray *arrayLocal = [[NSUserDefaults standardUserDefaults] objectForKey:APPSTATUS_DISABLECODES];
        if (logDisableCodes == nil && arrayLocal != nil) //server get nil, local should clear.
        {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:APPSTATUS_DISABLECODES];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [[NSNotificationCenter defaultCenter] postNotificationName:SHAppStatusChangeNotification object:nil];
        }
        else if (logDisableCodes != nil)
        {
            NSAssert([logDisableCodes isKindOfClass:[NSArray class]], @"logDisableCodes should be array.");
            if ([logDisableCodes isKindOfClass:[NSArray class]])
            {
                if (!shArrayIsSame((NSArray *)logDisableCodes, arrayLocal))
                {
                    [[NSUserDefaults standardUserDefaults] setObject:logDisableCodes forKey:APPSTATUS_DISABLECODES];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                    [[NSNotificationCenter defaultCenter] postNotificationName:SHAppStatusChangeNotification object:nil];
                }
            }
        }
        dispatch_semaphore_signal(self.semaphore_disableCodes);
    }
}

- (NSObject *)logPriorityCodes
{
    NSAssert(NO, @"Should not call logPriorityCodes.");
    return nil;
}

- (void)setLogPriorityCodes:(NSObject *)logPriorityCodes
{
    NSAssert(![NSThread isMainThread], @"setLogPriorityCodes wait in main thread.");
    if (![NSThread isMainThread])
    {
        dispatch_semaphore_wait(self.semaphore_priorityCodes, DISPATCH_TIME_FOREVER);
        NSArray *arrayLocal = [[NSUserDefaults standardUserDefaults] objectForKey:APPSTATUS_PRIORITYCODES];
        if (logPriorityCodes == nil && arrayLocal != nil) //server get nil, local should clear.
        {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:APPSTATUS_PRIORITYCODES];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [[NSNotificationCenter defaultCenter] postNotificationName:SHAppStatusChangeNotification object:nil];
        }
        else if (logPriorityCodes != nil)
        {
            NSAssert([logPriorityCodes isKindOfClass:[NSArray class]], @"logPriorityCodes should be array.");
            if ([logPriorityCodes isKindOfClass:[NSArray class]])
            {
                if (!shArrayIsSame((NSArray *)logPriorityCodes, arrayLocal))
                {
                    [[NSUserDefaults standardUserDefaults] setObject:logPriorityCodes forKey:APPSTATUS_PRIORITYCODES];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                    [[NSNotificationCenter defaultCenter] postNotificationName:SHAppStatusChangeNotification object:nil];
                }
            }
        }
        dispatch_semaphore_signal(self.semaphore_priorityCodes);
    }
}

#pragma mark - public functions

- (void)sendAppStatusCheckRequest:(BOOL)force completeHandler:(SHRequestHandler)handler
{
    if (!force)
    {
        NSObject *lastCheckTimeVal = [[NSUserDefaults standardUserDefaults] objectForKey:APPSTATUS_CHECK_TIME];
        if (lastCheckTimeVal != nil/*fresh launch must check first*/ && self.streethawkEnabled/*No need to send request, as when StreetHawk is enabled, normal request are sent frequently*/)
        {
            if (handler)
            {
                handler(nil);
            }
            return;
        }
        double lastCheckTime = 0;
        if ([lastCheckTimeVal isKindOfClass:[NSNumber class]])
        {
            lastCheckTime = [(NSNumber *)lastCheckTimeVal doubleValue];
        }
        if (lastCheckTime != 0 && [NSDate date].timeIntervalSinceReferenceDate - lastCheckTime < 60*60*24) //not check again once in a day, ticket https://bitbucket.org/shawk/streethawk/issue/379/app-status-reworked
        {
            if (handler)
            {
                handler(nil);
            }
            return;
        }
    }
    SHRequest *request = [SHRequest requestWithPath:@"apps/status/" withParams:@[@"app_key", NONULL(StreetHawk.appKey)]];
    request.requestHandler = handler;
    [request startAsynchronously];
}

- (void)recordCheckTime
{
    [[NSUserDefaults standardUserDefaults] setObject:@([NSDate date].timeIntervalSinceReferenceDate) forKey:APPSTATUS_CHECK_TIME];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end
