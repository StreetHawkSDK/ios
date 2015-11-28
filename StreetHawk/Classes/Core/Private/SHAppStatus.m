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
#ifdef SH_FEATURE_FEED
#import "SHApp+Feed.h" //for feed
#endif

#import "SHLocationManager.h"

#define APPSTATUS_STREETHAWKENABLED         @"APPSTATUS_STREETHAWKENABLED" //whether enable library functions
#define APPSTATUS_DEFAULT_HOST              @"APPSTATUS_DEFAULT_HOST" //default starting host url
#define APPSTATUS_ALIVE_HOST                @"APPSTATUS_ALIVE_HOST" //currently used alive host url
#define APPSTATUS_UPLOAD_LOCATION           @"APPSTATUS_UPLOAD_LOCATION" //whether send install/log for location update
#define APPSTATUS_SUBMIT_FRIENDLYNAME       @"APPSTATUS_SUBMIT_FRIENDLYNAME"  //whether server allow submit friendly name
#define APPSTATUS_GEOFENCE_FETCH_TIME       @"APPSTATUS_GEOFENCE_FETCH_TIME"  //last successfully fetch geofence list time
#define APPSTATUS_GEOFENCE_FETCH_LIST       @"APPSTATUS_GEOFENCE_FETCH_LIST"  //geofence list fetched from server, it contains parent geofence with child node. This is used as geofence monitor region.
#define APPSTATUS_REREGISTER                @"APPSTATUS_REREGISTER" //a flag set to notice next launch must re-register install
#define APPSTATUS_APPSTOREID                @"APPSTATUS_APPSTOREID" //server push itunes id to client side

#define APPSTATUS_CHECK_TIME                @"APPSTATUS_CHECK_TIME"  //the last successfully check app status time, record to avoid frequently call server.

NSString * const SHAppStatusChangeNotification = @"SHAppStatusChangeNotification";

#ifdef SH_FEATURE_GEOFENCE

/**
 An object to represend server fetch geofence region. It's two levels: parent fence and child fence.
 */
@interface SHServerGeofence : NSObject

/**
 Id from server for this fence. It will be used as `identifier` in `CLCircularRegion` so it must be not duplicated.
 */
@property (nonatomic, strong) NSString *serverId;

/**
 Latitude of this fence.
 */
@property (nonatomic) double latitude;

/**
 Longitude of this fence.
 */
@property (nonatomic) double longitude;

/**
 Radius of this fence. It will be adjust to not exceed `maximumRegionMonitoringDistance`.
 */
@property (nonatomic) double radius;

/**
 Whether device is inside this geofence.
 */
@property (nonatomic) BOOL isInside;

/**
 A weak reference to its parent fence.
 */
@property (nonatomic, weak) SHServerGeofence *parentFence;

/**
 Child nodes for parent fence. For child fence it's definity nil; for parent fence it would be nil.
 */
@property (nonatomic, strong) NSMutableArray *arrayNodes;

/**
 Whether this is actual geofence. Only actual geofence should send logline to server. Inner nodes's `id` starts with "_", actual geofence's `id` is "<id>-<distance>".
 */
@property (nonatomic, readonly) BOOL isLeaves;

/**
 Use this geofence data to create monitoring region.
 */
- (CLCircularRegion *)getGeoRegion;

/**
 Serialize self into a dictionary. Vice verse against `+ (SHServerGeofence *)parseGeofenceFromDict:(NSDictionary *)dict;`.
 */
- (NSDictionary *)serializeGeofeneToDict;

/**
 Compare function.
 */
- (BOOL)isEqualToCircleRegion:(CLCircularRegion *)geoRegion;

/**
 Parse an object from dictionary. If parse fail return nil.
 @param dict The dictionary information.
 @return If successfully parse return the object; otherwise return nil.
 */
+ (SHServerGeofence *)parseGeofenceFromDict:(NSDictionary *)dict;

/**
 Make this object array to string array for store to NSUserDefaults.
 */
+ (NSArray *)serializeToArrayDict:(NSArray *)parentFences;

/**
 When read from NSUserDefaults, parse back to object array.
 */
+ (NSArray *)deserializeToArrayObj:(NSArray *)arrayDict;

@end

#endif

@interface SHAppStatus ()

@property (nonatomic, strong) NSString *aliveHostInner; //inner memory variable

//make sure update happens in sequence for each property
@property (nonatomic) dispatch_semaphore_t semaphore_streethawkEnabled;
@property (nonatomic) dispatch_semaphore_t semaphore_aliveHost;
@property (nonatomic) dispatch_semaphore_t semaphore_uploadLocationChange;
@property (nonatomic) dispatch_semaphore_t semaphore_allowSubmitFriendlyNames;
@property (nonatomic) dispatch_semaphore_t semaphore_appstoreId;

- (void)recordCheckTime; //Save this check time to avoid frequent check. No matter any property changed or not, record the time.

#ifdef SH_FEATURE_GEOFENCE
@property (strong, nonatomic) NSMutableArray *arrayGeofenceFetchList; //simiar as above but for geofence fetch list.
- (void)sendLogForGeoFence:(SHServerGeofence *)geoFence isInside:(BOOL)isInside; //Send install/log for enter/exit server geofence.
- (SHServerGeofence *)findServerGeofenceForRegion:(CLRegion *)region;  //get SHServerGeofence list, subset of self.arrayGeofenceFetchList, which match this region. It searches both parent and child list.
- (void)stopMonitorPreviousGeofencesOnlyForOutside:(BOOL)onlyForOutside parentCanKeepChild:(BOOL)parentKeep;  //Geofence monitor region need to change, stop previous monitor for server's geofence. If `onlyForOutside`=YES, only stop monitor those outside; otherwise stop all regardless inside or outside. `parentKeep`=YES take effect when `onlyForOutside`=YES, if it's parent fence is inside, child fence not stop although it's outside.
- (void)startMonitorGeofences:(NSArray *)arrayGeofences;  //Give an array of SHServerGeofence and convert to be monitored. It doesn't create region for child nodes.
- (void)markSelfAndChildGeofenceOutside:(SHServerGeofence *)geofence; //When a geofence outside, mark itself and child (if has) to be outside, send out geofene logline for previous inside leave geofence too. Make it a separate function because it's recurisive.
- (void)stopMonitorSelfAndChildGeofence:(SHServerGeofence *)geofence; //when stop monitor inner geofence, stop monitor its child too. As child not stop when exit due to parent keep it.
- (SHServerGeofence *)searchSelfAndChild:(SHServerGeofence *)geofence forRegion:(CLCircularRegion *)geoRegion; //search recursively to match
#endif

#if  defined(SH_FEATURE_GEOFENCE)
- (void)regionStateChangeNotificationHandler:(NSNotification *)notification; //monitor when a region state change.
#endif

@end

@implementation SHAppStatus


#ifdef SH_FEATURE_GEOFENCE
@synthesize arrayGeofenceFetchList = _arrayGeofenceFetchList;
#endif

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
#if  defined(SH_FEATURE_GEOFENCE)
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(regionStateChangeNotificationHandler:) name:SHLMRegionStateChangeNotification object:nil];
#endif
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
        [self recordCheckTime];
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
    [self recordCheckTime];
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
        [self recordCheckTime];
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
        [self recordCheckTime];
    }
}

- (NSString *)iBeaconTimeStamp
{
    NSAssert(NO, @"Should not call iBeaconTimeStamp.");
    return nil;
}

- (void)setIBeaconTimeStamp:(NSString *)iBeaconTimeStamp
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_LMBridge_SetIBeaconTimeStamp" object:nil userInfo:@{@"timestamp": NONULL(iBeaconTimeStamp)}];
}

- (NSString *)geofenceTimeStamp
{
    NSAssert(NO, @"Should not call geofenceTimeStamp.");
    return nil;
}

- (void)setGeofenceTimeStamp:(NSString *)geofenceTimeStamp
{
#ifdef SH_FEATURE_GEOFENCE
    if (StreetHawk.currentInstall == nil)
    {
        return; //not register yet, wait for next time.
    }
    if (!streetHawkIsEnabled())
    {
        return;
    }
    //If current device not support monitor geofence, no need to continue
    if (![SHLocationManager locationServiceEnabledForApp:NO] || ![CLLocationManager isMonitoringAvailableForClass:[CLCircularRegion class]])
    {
        return;
    }
    if (geofenceTimeStamp != nil && [geofenceTimeStamp isKindOfClass:[NSString class]])
    {
        NSDate *serverTime = shParseDate(geofenceTimeStamp, 0);
        if (serverTime != nil)
        {
            BOOL needFetch = NO;
            NSObject *localTimeVal = [[NSUserDefaults standardUserDefaults] objectForKey:APPSTATUS_GEOFENCE_FETCH_TIME];
            if (localTimeVal == nil || ![localTimeVal isKindOfClass:[NSNumber class]])
            {
                needFetch = YES;  //local never fetched, do fetch.
            }
            else
            {
                NSDate *localTime = [NSDate dateWithTimeIntervalSinceReferenceDate:[(NSNumber *)localTimeVal doubleValue]];
                if ([localTime compare:serverTime] == NSOrderedAscending)
                {
                    needFetch = YES;  //local fetched, but too old, do fetch.
                }
            }
            if (needFetch)
            {
                //update local cache time before send request, because this request has same format as others {app_status:..., code:0, value:...}, it will trigger `setGeofenceTimeStamp` again. If fail to get request, clear local cache time in callback handler, make next fetch happen.
                [[NSUserDefaults standardUserDefaults] setObject:@([[NSDate date] timeIntervalSinceReferenceDate]) forKey:APPSTATUS_GEOFENCE_FETCH_TIME];
                [[NSUserDefaults standardUserDefaults] synchronize];
                SHRequest *fetchRequest = [SHRequest requestWithPath:@"/geofences/tree/"];
                fetchRequest.requestHandler = ^(SHRequest *request)
                {
                    if (request.error == nil)
                    {
                        //successfully fetch server's geofence list. local cache time is already updated, store fetch list and active monitor.
                        SHLog(@"Fetch server geofence list: %@.", request.resultValue);
                        NSAssert([request.resultValue isKindOfClass:[NSArray class]] || [request.resultValue isKindOfClass:[NSDictionary class]], @"Server return should be array or empty dictionary.");
                        if ([request.resultValue isKindOfClass:[NSArray class]] || [request.resultValue isKindOfClass:[NSDictionary class]])
                        {
                            //Geofence would monitor parent or child, and it's possible `id` not change but latitude/longitude/radius change. When timestamp change, stop monitor existing geofences and start to monitor from new list totally.
                            [self stopMonitorPreviousGeofencesOnlyForOutside:NO parentCanKeepChild:NO]; //server's geofence change, stop monitor all.
                            if ([request.resultValue isKindOfClass:[NSArray class]]) //array means there is new geofence list from server
                            {
                                NSMutableArray *arrayList = [NSMutableArray array];
                                for (NSDictionary *dictParent in (NSArray *)request.resultValue)
                                {
                                    SHServerGeofence *geofence = [SHServerGeofence parseGeofenceFromDict:dictParent];
                                    NSAssert(geofence != nil, @"Fail to parse geofence from %@.", dictParent);
                                    if (geofence != nil)
                                    {
                                        [arrayList addObject:geofence];
                                    }
                                }
                                //Update local cache and memory, start monitor parent.
                                self.arrayGeofenceFetchList = arrayList;
                                [[NSUserDefaults standardUserDefaults] setObject:[SHServerGeofence serializeToArrayDict:arrayList] forKey:APPSTATUS_GEOFENCE_FETCH_LIST];
                                [[NSUserDefaults standardUserDefaults] synchronize];
                                [self startMonitorGeofences:arrayList];
                            }
                            else //dictionary means empty geofence list from server.
                            {
                                self.arrayGeofenceFetchList = [NSMutableArray array]; //cannot set to nil, as nil will read from NSUserDefaults again.
                                [[NSUserDefaults standardUserDefaults] setObject:[NSArray array] forKey:APPSTATUS_GEOFENCE_FETCH_LIST];  //clear local cache, not start when kill and launch App.
                                [[NSUserDefaults standardUserDefaults] synchronize];
                            }
                        }
                    }
                    else
                    {
                        [[NSUserDefaults standardUserDefaults] setObject:@(0) forKey:APPSTATUS_GEOFENCE_FETCH_TIME]; //make next fetch happen as this time fail.
                        [[NSUserDefaults standardUserDefaults] synchronize];
                    }
                };
                [fetchRequest startAsynchronously];
            }
            return;
        }
    }
    //when meet this, means server return nil or invalid timestamp. Clear local fetch list and stop monitor.
    [self stopMonitorPreviousGeofencesOnlyForOutside:NO parentCanKeepChild:NO];
    self.arrayGeofenceFetchList = [NSMutableArray array]; //cannot set to nil, as nil will read from NSUserDefaults again.
    [[NSUserDefaults standardUserDefaults] setObject:[NSArray array] forKey:APPSTATUS_GEOFENCE_FETCH_LIST];  //clear local cache, not start when kill and launch App.
    [[NSUserDefaults standardUserDefaults] synchronize];
#endif
}

- (NSString *)feedTimeStamp
{
    NSAssert(NO, @"Should not call feedTimeStamp.");
    return nil;
}

- (void)setFeedTimeStamp:(NSString *)feedTimeStamp
{
#ifdef SH_FEATURE_FEED
    if (StreetHawk.currentInstall == nil)
    {
        return; //not register yet, wait for next time.
    }
    if (StreetHawk.newFeedHandler == nil)
    {
        return; //no need to continue if user not setup fetch handler
    }
    if (!streetHawkIsEnabled())
    {
        return;
    }
    if (feedTimeStamp != nil && [feedTimeStamp isKindOfClass:[NSString class]])
    {
        NSDate *serverTime = shParseDate(feedTimeStamp, 0);
        if (serverTime != nil)
        {
            BOOL needFetch = NO;
            NSObject *localTimeVal = [[NSUserDefaults standardUserDefaults] objectForKey:APPSTATUS_FEED_FETCH_TIME];
            if (localTimeVal == nil || ![localTimeVal isKindOfClass:[NSNumber class]])
            {
                needFetch = YES;  //local never fetched, do fetch.
            }
            else
            {
                NSDate *localTime = [NSDate dateWithTimeIntervalSinceReferenceDate:[(NSNumber *)localTimeVal doubleValue]];
                if ([localTime compare:serverTime] == NSOrderedAscending)
                {
                    needFetch = YES;  //local fetched, but too old, do fetch.
                }
            }
            if (needFetch)
            {
                //update local cache time before notice user and send request, because this request has same format as others {app_status:..., code:0, value:...}, it will trigger `setFeedTimeStamp` again. Customer's code controls feed function, they can do fetch anytime want.
                [[NSUserDefaults standardUserDefaults] setObject:@([[NSDate date] timeIntervalSinceReferenceDate]) forKey:APPSTATUS_FEED_FETCH_TIME];
                [[NSUserDefaults standardUserDefaults] synchronize];
                StreetHawk.newFeedHandler(); //just notice user, not do fetch actually.
            }
        }
    }
#endif
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
        [self recordCheckTime];
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

#pragma mark - private functions

- (void)recordCheckTime
{
    [[NSUserDefaults standardUserDefaults] setObject:@([NSDate date].timeIntervalSinceReferenceDate) forKey:APPSTATUS_CHECK_TIME];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#ifdef SH_FEATURE_GEOFENCE

- (NSMutableArray *)arrayGeofenceFetchList
{
    if (_arrayGeofenceFetchList == nil) //never initialized
    {
        _arrayGeofenceFetchList = [NSMutableArray arrayWithArray:[SHServerGeofence deserializeToArrayObj:[[NSUserDefaults standardUserDefaults] objectForKey:APPSTATUS_GEOFENCE_FETCH_LIST]]]; //it will not get nil even empty
    }
    return _arrayGeofenceFetchList;
}

- (void)sendLogForGeoFence:(SHServerGeofence *)geoFence isInside:(BOOL)isInside
{
    NSInteger index = [geoFence.serverId rangeOfString:@"-"].location;
    NSAssert(index != NSNotFound, @"Server id for %@ is not valid.", geoFence.serverId);
    if (index > 0 && index < geoFence.serverId.length)
    {
        NSString *serverId = [geoFence.serverId substringToIndex:index];
        NSString *distance = [geoFence.serverId substringFromIndex:index + 1];
        NSDictionary *dictDistance = @{serverId : @(isInside ? [distance doubleValue] : -1)};
        NSString *distanceStr = shSerializeObjToJson(dictDistance);
        if (!shStrIsEmpty(distanceStr))
        {
            [StreetHawk sendLogForCode:LOG_CODE_LOCATION_GEOFENCE withComment:distanceStr];
        }
    }
}

- (SHServerGeofence *)findServerGeofenceForRegion:(CLRegion *)region
{
    if (![region isKindOfClass:[CLCircularRegion class]])
    {
        return nil;
    }
    CLCircularRegion *geoRegion = (CLCircularRegion *)region;
    for (SHServerGeofence *geofence in self.arrayGeofenceFetchList)
    {
        SHServerGeofence *matchGeofence = [self searchSelfAndChild:geofence forRegion:geoRegion];
        if (matchGeofence != nil)
        {
            return matchGeofence;
        }
    }
    return nil;
}

- (void)stopMonitorPreviousGeofencesOnlyForOutside:(BOOL)onlyForOutside parentCanKeepChild:(BOOL)parentKeep
{
    for (CLRegion *monitorRegion in StreetHawk.locationManager.monitoredRegions)
    {
        //only stop if this region is previous geofence, should not affect if it's iBeacon or from other source monitor.
        SHServerGeofence *matchGeofence = [self findServerGeofenceForRegion:monitorRegion];
        if (matchGeofence != nil) //stop monitor this as it's previous geofence
        {
            BOOL shouldStop = YES;
            if (onlyForOutside) //otherwise for both inside and outside, means stop all
            {
                if (matchGeofence.isInside)  //this one is inside, cannot stop
                {
                    shouldStop = NO;
                }
                else
                {
                    if (parentKeep && matchGeofence.parentFence != nil && matchGeofence.parentFence.isInside) //although this one is outside, but its parent is inside and can keep it.
                    {
                        shouldStop = NO;
                    }
                }
            }
            if (shouldStop)
            {
                //Test multiple levels case: level1 inner->level 2 inner->leave. Before exit it's inside leave. Suddenly exit them all, when exit leave it's kept monitor by level 2, when exit level 2 it stops monitor, but still leave is monitor. In this case should remove level geofence too.
                [self stopMonitorSelfAndChildGeofence:matchGeofence];
            }
        }
    }
}

- (void)startMonitorGeofences:(NSArray *)arrayGeofences
{
    for (SHServerGeofence *geofence in arrayGeofences)
    {
        [StreetHawk.locationManager startMonitorRegion:[geofence getGeoRegion]];
    }
}

- (void)markSelfAndChildGeofenceOutside:(SHServerGeofence *)geofence
{
    if (geofence.isInside)
    {
        geofence.isInside = NO;
        if (geofence.isLeaves) //for leave go outside, send logline.
        {
            [self sendLogForGeoFence:geofence isInside:NO];
        }
        else //if parent geofence out, make all child geofence outside too.
        {
            for (SHServerGeofence *childGeofence in geofence.arrayNodes)
            {
                [self markSelfAndChildGeofenceOutside:childGeofence]; //recurisively do it as child geofence may contains child too.
            }
        }
    }
}

- (void)stopMonitorSelfAndChildGeofence:(SHServerGeofence *)geofence
{
    [StreetHawk.locationManager stopMonitorRegion:[geofence getGeoRegion]];
    if (!geofence.isLeaves)
    {
        for (SHServerGeofence *childGeofence in geofence.arrayNodes)
        {
            [self stopMonitorSelfAndChildGeofence:childGeofence]; //recurisively do it as child geofence may contains child too.
        }
    }
}

- (SHServerGeofence *)searchSelfAndChild:(SHServerGeofence *)geofence forRegion:(CLCircularRegion *)geoRegion
{
    if ([geofence isEqualToCircleRegion:geoRegion])
    {
        return geofence;
    }
    for (SHServerGeofence *childGeoFence in geofence.arrayNodes)
    {
        SHServerGeofence *match = [self searchSelfAndChild:childGeoFence forRegion:geoRegion];
        if (match != nil)
        {
            return match;
        }
    }
    return nil;
}

#endif

#if  defined(SH_FEATURE_GEOFENCE)

- (void)regionStateChangeNotificationHandler:(NSNotification *)notification
{
    //use state change instead of didEnterRegion/didExitRegion because when startMonitorRegion, state change delegate is called, didEnter/ExitRegion delegate not called until next enter/exit.
    CLRegion *region = notification.userInfo[SHLMNotification_kRegion];
    CLRegionState regionState = [notification.userInfo[SHLMNotification_kRegionState] intValue];
    if (regionState == CLRegionStateInside)
    {
        if ([region isKindOfClass:[CLCircularRegion class]])
        {
#ifdef SH_FEATURE_GEOFENCE
            SHServerGeofence *geofence = [self findServerGeofenceForRegion:region];
            if (geofence != nil && !geofence.isInside/*only take action if change*/)
            {
                geofence.isInside = YES;
                [[NSUserDefaults standardUserDefaults] setObject:[SHServerGeofence serializeToArrayDict:self.arrayGeofenceFetchList] forKey:APPSTATUS_GEOFENCE_FETCH_LIST];
                [[NSUserDefaults standardUserDefaults] synchronize];
                if (geofence.isLeaves) //if this is actual geofence, send enter logline and it's done
                {
                    [self sendLogForGeoFence:geofence isInside:YES];
                }
                else //if this is parent geofence, stop monitor other outside parent geofence and add self's child node.
                {
                    [self stopMonitorPreviousGeofencesOnlyForOutside:YES parentCanKeepChild:YES]; //This is a tricky: parent fence may overlap. Case 1: simple case, if parent fence not overlap, enter this one means all others are outside, so stop all other parent fences and add this one's child. Case 2: if parent fence P1 overlap with parent fence P2, P1 is already inside, now enter P2. This check will keep P1 and P1's child fence in monitoring, while later add P2 and its child.
                    [self startMonitorGeofences:geofence.arrayNodes]; //geofence itself is already monitor
                }
            }
#endif
        }
    }
    else if (regionState == CLRegionStateOutside)
    {
        if ([region isKindOfClass:[CLCircularRegion class]])
        {
#ifdef SH_FEATURE_GEOFENCE
            SHServerGeofence *geofence = [self findServerGeofenceForRegion:region];
            if (geofence != nil && geofence.isInside/*only take action if change*/)
            {
                [self markSelfAndChildGeofenceOutside:geofence]; //recursively mark this geofence and its child all outside. It also sends exit logline for child if necessary, because if parent exit before child leave, child will be marked as outside, and this logic will not enter when child leave detect outside.
                [[NSUserDefaults standardUserDefaults] setObject:[SHServerGeofence serializeToArrayDict:self.arrayGeofenceFetchList] forKey:APPSTATUS_GEOFENCE_FETCH_LIST];
                [[NSUserDefaults standardUserDefaults] synchronize];
                if (!geofence.isLeaves) //if this is inner geofence, stop monitor its child geofence, add itself and it's same level.
                {
                    [self stopMonitorPreviousGeofencesOnlyForOutside:YES parentCanKeepChild:YES]; //in case overlap and in another parent geofence, this will keep it un-affected.
                    if (geofence.parentFence != nil && geofence.parentFence.isInside)
                    {
                        //Move out from a inner geofence, if its parent geofence is still inside, monitor itself and its same level. Cannot monitor top level in this case, because if monitor top level, its parent fence is already monitored, and not stop/add again, no enter happens, so the same level geofence (some maybe leave geofence), will not be monitored.
                        [self startMonitorGeofences:geofence.parentFence.arrayNodes];
                    }
                    else
                    {
                        [self startMonitorGeofences:self.arrayGeofenceFetchList]; //monitor all top level geofences.
                    }
                }
            }
#endif
        }
    }
    //do nothing for state=unknown.
}

#endif

@end


#ifdef SH_FEATURE_GEOFENCE

@implementation SHServerGeofence

@synthesize serverId = _serverId;
@synthesize latitude = _latitude;
@synthesize longitude = _longitude;
@synthesize radius = _radius;
@synthesize isLeaves = _isLeaves;

#pragma mark - life cycle

- (id)init
{
    if (self = [super init])
    {
        self.parentFence = nil;
        self.arrayNodes = [NSMutableArray array];
        self.isInside = NO;
    }
    return self;
}

#pragma mark - properties

- (void)setServerId:(NSString *)serverId
{
    NSAssert(!shStrIsEmpty(serverId), @"Invalid geofence server Id.");
    _serverId = serverId;
    _isLeaves = ![_serverId hasPrefix:@"_"];
}

- (void)setLatitude:(double)latitude
{
    NSAssert(latitude >= -90 && latitude <= 90, @"Invalid geofence latitude: %.f.", latitude);
    _latitude = latitude;
}

- (void)setLongitude:(double)longitude
{
    NSAssert(longitude >= -180 && longitude <= 180, @"Invalid geofence longitude: %f", longitude);
    _longitude = longitude;
}

- (void)setRadius:(double)radius
{
    if (radius > StreetHawk.locationManager.geofenceMaximumRadius)
    {
        _radius = StreetHawk.locationManager.geofenceMaximumRadius;
    }
    else
    {
        _radius = radius;
    }
}

- (BOOL)isLeaves
{
    return _isLeaves;
}

#pragma mark - public functions

- (NSString *)description
{
    return [NSString stringWithFormat:@"[%@](%f,%f)~%f. Is inside: %@. Nodes:%@", self.serverId, self.latitude, self.longitude, self.radius, shBoolToString(self.isInside), self.arrayNodes];
}

- (CLCircularRegion *)getGeoRegion
{
    return [[CLCircularRegion alloc] initWithCenter:CLLocationCoordinate2DMake(self.latitude, self.longitude) radius:self.radius identifier:self.serverId];
}

- (BOOL)isEqualToCircleRegion:(CLCircularRegion *)geoRegion
{
    //region only compares by `identifier`.
    return ([self.serverId compare:geoRegion.identifier] == NSOrderedSame);
}

- (NSDictionary *)serializeGeofeneToDict
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"id"] = self.serverId;
    dict[@"latitude"] = @(self.latitude);
    dict[@"longitude"] = @(self.longitude);
    dict[@"radius"] = @(self.radius);
    dict[@"inside"] = @(self.isInside);
    if (self.isLeaves)
    {
        NSAssert(self.arrayNodes.count == 0, @"Leave node should not have child.");
        return dict;
    }
    else
    {
        NSAssert(self.arrayNodes.count > 0, @"Inner node should have child.");
        NSMutableArray *arrayChild = [NSMutableArray array];
        for (SHServerGeofence *childFence in self.arrayNodes)
        {
            [arrayChild addObject:[childFence serializeGeofeneToDict]];
        }
        dict[@"geofences"] = arrayChild;
        return dict;
    }
}

+ (SHServerGeofence *)parseGeofenceFromDict:(NSDictionary *)dict
{
    NSAssert([dict isKindOfClass:[NSDictionary class]], @"Geofence dict invalid type: %@.", dict);
    if ([dict isKindOfClass:[NSDictionary class]])
    {
        BOOL isValidKey = (dict.allKeys.count >= 4 && [dict.allKeys containsObject:@"id"] && [dict.allKeys containsObject:@"latitude"] && [dict.allKeys containsObject:@"longitude"] && [dict.allKeys containsObject:@"radius"]);
        NSAssert(isValidKey, @"Geofence key format invalid: %@.", dict);
        if (isValidKey)
        {
            BOOL isValidValue = [dict[@"id"] isKindOfClass:[NSString class]] && [dict[@"latitude"] isKindOfClass:[NSNumber class]] && [dict[@"longitude"] isKindOfClass:[NSNumber class]] && [dict[@"radius"] isKindOfClass:[NSNumber class]];
            NSAssert(isValidValue, @"Geofence value format invalid: %@.", dict);
            if (isValidValue)
            {
                SHServerGeofence *geofence = [[SHServerGeofence alloc] init];
                geofence.serverId = dict[@"id"];
                geofence.latitude = [dict[@"latitude"] doubleValue];
                geofence.longitude = [dict[@"longitude"] doubleValue];
                geofence.radius = [dict[@"radius"] doubleValue];
                if ([dict.allKeys containsObject:@"inside"])
                {
                    geofence.isInside = [dict[@"inside"] boolValue];
                }
                BOOL hasGeofence = [dict.allKeys containsObject:@"geofences"] && ([dict[@"geofences"] isKindOfClass:[NSArray class]]) && (((NSArray *)dict[@"geofences"]).count > 0);
                if (geofence.isLeaves)
                {
                    NSAssert(!hasGeofence, @"Leave dict should not have child.");
                    return geofence;
                }
                else
                {
                    NSAssert(hasGeofence, @"Inner dict should have child.");
                    if (hasGeofence)
                    {
                        for (NSDictionary *dictChild in dict[@"geofences"])
                        {
                            SHServerGeofence *childFence = [SHServerGeofence parseGeofenceFromDict:dictChild];
                            if (childFence != nil)
                            {
                                childFence.parentFence = geofence;
                                [geofence.arrayNodes addObject:childFence];
                            }
                        }
                    }
                    NSAssert(geofence.arrayNodes.count > 0, @"Inner node have none child.");
                    return geofence;
                }
            }
        }
    }
    return nil;
}

+ (NSArray *)serializeToArrayDict:(NSArray *)parentFences
{
    NSMutableArray *array = [NSMutableArray array];
    for (SHServerGeofence *parentFence in parentFences)
    {
        [array addObject:[parentFence serializeGeofeneToDict]];
    }
    return array;
}

+ (NSArray *)deserializeToArrayObj:(NSArray *)arrayDict
{
    NSMutableArray *array = [NSMutableArray array];
    for (NSDictionary *dict in arrayDict)
    {
        [array addObject:[SHServerGeofence parseGeofenceFromDict:dict]];
    }
    return array;
}

@end

#endif