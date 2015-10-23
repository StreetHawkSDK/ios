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
#if defined(SH_FEATURE_LATLNG) || defined(SH_FEATURE_GEOFENCE) || defined(SH_FEATURE_IBEACON)
#import "SHLocationManager.h" //for SHLMNotification defines
#endif
#import "SHUtils.h" //for SHLog
#import "SHApp.h" //for `StreetHawk.currentInstall`
#import "SHLogger.h" //for sending logline
#ifdef SH_FEATURE_FEED
#import "SHApp+Feed.h" //for feed
#endif

#define APPSTATUS_STREETHAWKENABLED         @"APPSTATUS_STREETHAWKENABLED" //whether enable library functions
#define APPSTATUS_DEFAULT_HOST              @"APPSTATUS_DEFAULT_HOST" //default starting host url
#define APPSTATUS_ALIVE_HOST                @"APPSTATUS_ALIVE_HOST" //currently used alive host url
#define APPSTATUS_UPLOAD_LOCATION           @"APPSTATUS_UPLOAD_LOCATION" //whether send install/log for location update
#define APPSTATUS_SUBMIT_FRIENDLYNAME       @"APPSTATUS_SUBMIT_FRIENDLYNAME"  //whether server allow submit friendly name
#define APPSTATUS_IBEACON_FETCH_TIME        @"APPSTATUS_IBEACON_FETCH_TIME"  //last successfully fetch iBeacon list time
#define APPSTATUS_IBEACON_FETCH_LIST        @"APPSTATUS_IBEACON_FETCH_LIST"  //iBeacon list fetched from server, it contains array for object: UUID, major, minor, id. This is used as iBeacon monitor region.
#define APPSTATUS_GEOFENCE_FETCH_TIME       @"APPSTATUS_GEOFENCE_FETCH_TIME"  //last successfully fetch geofence list time
#define APPSTATUS_GEOFENCE_FETCH_LIST       @"APPSTATUS_GEOFENCE_FETCH_LIST"  //geofence list fetched from server, it contains parent geofence with child node. This is used as geofence monitor region.
#define APPSTATUS_REREGISTER                @"APPSTATUS_REREGISTER" //a flag set to notice next launch must re-register install
#define APPSTATUS_APPSTOREID                @"APPSTATUS_APPSTOREID" //server push itunes id to client side

#define APPSTATUS_CHECK_TIME                @"APPSTATUS_CHECK_TIME"  //the last successfully check app status time, record to avoid frequently call server.

NSString * const SHAppStatusChangeNotification = @"SHAppStatusChangeNotification";

#ifdef SH_FEATURE_IBEACON

/**
 An object to represent server fetched iBeacon information. It's different from CLBeaconRegion and CLBeacon, so create an object to store it.
 */
@interface SHServeriBeacon : NSObject

/**
 Match to iBeacon's proximity UUID.
 */
@property (nonatomic, strong) NSString *uuid;

/**
 Match to iBeacon's major.
 */
@property (nonatomic) int major;

/**
 Match to iBeacon's minor.
 */
@property (nonatomic) int minor;

/**
 Server's id for this iBeacon.
 */
@property (nonatomic) int serverId;

/**
 Match to iBeacon's accuracy.
 */
@property (nonatomic) double distance;

/**
 Compare function.
 */
- (BOOL)isEqual:(id)object;

/**
 Get one iBeacon region from UUid, identifier also use the uuid to be unique. It may return nil if fail to create one.
 */
+ (CLBeaconRegion *)getBeaconRegionForUUid:(NSString *)uuid;

/**
 Make this object array to string array for store to NSUserDefaults.
 */
+ (NSArray *)serializeToStringArray:(NSArray *)objArray;

/**
 When read from NSUserDefaults, parse back to object array.
 */
+ (NSArray *)deserializeToObjArray:(NSArray *)stringArray;

@end

#endif

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

#ifdef SH_FEATURE_IBEACON
@property (strong, nonatomic) NSMutableArray *arrayiBeaconFetchList;  //Server controls client to monitor a certain iBeacon list by request "/ibeacons", this list is cached locally and returned by this property. It's array of `SHServeriBeacon`. "app_status"'s "ibeacon" timestamp controls when to fetch this list again.
- (void)sendLogForiBeacons:(NSArray *)arrayServeriBeacons isInside:(BOOL)isInside; //Send install/log for enter or exit(stop monitor) server iBeacons. If enter region, distance = ranged first distance or 1; if exit region, distance = `null`. If not enter or exit but only distance change, not send this install/log. code=21, comment formatted as {serverid: distance}.
- (NSArray *)findServeriBeaconsInsideRegion:(CLBeaconRegion *)region onlyWithDistance:(BOOL)requireDistance needSetOutside:(BOOL)setOutside;  //get SHServeriBeacon list, subset of self.arrayiBeaconFetchList, which match this region. If `requireDistance` means get those with distance, otherwise get all SHServeriBeacon inside this region.
- (void)regionRangeNotificationHandler:(NSNotification *)notification; //when range a region to know exact iBeacons.
#endif

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

#if defined(SH_FEATURE_IBEACON) || defined(SH_FEATURE_GEOFENCE)
- (void)regionStateChangeNotificationHandler:(NSNotification *)notification; //monitor when a region state change.
#endif

@end

@implementation SHAppStatus

#ifdef SH_FEATURE_IBEACON
@synthesize arrayiBeaconFetchList = _arrayiBeaconFetchList;
#endif

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
#if defined(SH_FEATURE_IBEACON) || defined(SH_FEATURE_GEOFENCE)
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(regionStateChangeNotificationHandler:) name:SHLMRegionStateChangeNotification object:nil];
#endif
#ifdef SH_FEATURE_IBEACON
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(regionRangeNotificationHandler:) name:SHLMRangeiBeaconChangedNotification object:nil];
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
#ifdef SH_FEATURE_IBEACON
    if (StreetHawk.currentInstall == nil)
    {
        return; //not register yet, wait for next time.
    }
    if (!streetHawkIsEnabled())
    {
        return;
    }
    //By testing even if install/details set "ibeacon=false", means client report this device not support iBeacon, server still returns iBeacon timestamp in app_status. Must avoid continue for not support iBeacon device. As for pre-iOS 7 following code try to create CLBeaconRegion and causes crash. Bluetooth undecided state is SHiBeaconState_Unknown, bypass it is OK as this will called again next response.
    if (StreetHawk.locationManager.iBeaconSupportState != SHiBeaconState_Support)
    {
        return;
    }
    if (iBeaconTimeStamp != nil && [iBeaconTimeStamp isKindOfClass:[NSString class]])
    {
        NSDate *serverTime = shParseDate(iBeaconTimeStamp, 0);
        if (serverTime != nil)
        {
            BOOL needFetch = NO;
            NSObject *localTimeVal = [[NSUserDefaults standardUserDefaults] objectForKey:APPSTATUS_IBEACON_FETCH_TIME];
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
                //update local cache time before send request, because this request has same format as others {app_status:..., code:0, value:...}, it will trigger `setIBeaconTimeStamp` again. If fail to get request, clear local cache time in callback handler, make next fetch happen.
                [[NSUserDefaults standardUserDefaults] setObject:@([[NSDate date] timeIntervalSinceReferenceDate]) forKey:APPSTATUS_IBEACON_FETCH_TIME];
                [[NSUserDefaults standardUserDefaults] synchronize];
                SHRequest *fetchRequest = [SHRequest requestWithPath:@"/ibeacons/"];
                fetchRequest.requestHandler = ^(SHRequest *request)
                {
                    if (request.error == nil)
                    {
                        //successfully fetch server's iBeacon list. local cache time is already updated, store fetch list and active monitor.
                        SHLog(@"Fetch server iBeacon list: %@.", request.resultValue);
                        NSAssert([request.resultValue isKindOfClass:[NSDictionary class]], @"Server return should be dictionary.");
                        if ([request.resultValue isKindOfClass:[NSDictionary class]])
                        {
                            NSMutableArray *arrayList = [NSMutableArray array];
                            NSDictionary *dictList = (NSDictionary *)request.resultValue;
                            for (NSObject *uuidValue in dictList.allKeys)
                            {
                                NSAssert([uuidValue isKindOfClass:[NSString class]] && [dictList[uuidValue] isKindOfClass:[NSDictionary class]], @"UUID dictionary invalid: %@.", uuidValue);
                                if ([uuidValue isKindOfClass:[NSString class]] && [dictList[uuidValue] isKindOfClass:[NSDictionary class]])
                                {
                                    NSDictionary *dictuuid = (NSDictionary *)dictList[uuidValue];
                                    for (NSObject *majorValue in dictuuid.allKeys)
                                    {
                                        NSAssert(([majorValue isKindOfClass:[NSNumber class]] || [majorValue isKindOfClass:[NSString class]]) && [dictuuid[majorValue] isKindOfClass:[NSDictionary class]], @"Major dictionary invalid: %@.", majorValue);
                                        if (([majorValue isKindOfClass:[NSNumber class]] || [majorValue isKindOfClass:[NSString class]]) && [dictuuid[majorValue] isKindOfClass:[NSDictionary class]])
                                        {
                                            NSDictionary *dictMajor = (NSDictionary *)dictuuid[majorValue];
                                            for (NSObject *minorValue in dictMajor.allKeys)
                                            {
                                                NSAssert(([minorValue isKindOfClass:[NSNumber class]] || [minorValue isKindOfClass:[NSString class]]) && ([dictMajor[minorValue] isKindOfClass:[NSNumber class]] || [dictMajor[minorValue] isKindOfClass:[NSString class]]), @"Minor dictionary invalid: %@.", minorValue);
                                                if (([minorValue isKindOfClass:[NSNumber class]] || [minorValue isKindOfClass:[NSString class]]) && ([dictMajor[minorValue] isKindOfClass:[NSNumber class]] || [dictMajor[minorValue] isKindOfClass:[NSString class]]))
                                                {
                                                    SHServeriBeacon *serveriBeacon = [[SHServeriBeacon alloc] init];
                                                    serveriBeacon.uuid = (NSString *)uuidValue;
                                                    if ([majorValue isKindOfClass:[NSNumber class]])
                                                    {
                                                        serveriBeacon.major = [(NSNumber *)majorValue intValue];
                                                    }
                                                    else if ([majorValue isKindOfClass:[NSString class]])
                                                    {
                                                        serveriBeacon.major = [(NSString *)majorValue intValue];
                                                    }
                                                    if ([minorValue isKindOfClass:[NSNumber class]])
                                                    {
                                                        serveriBeacon.minor = [(NSNumber *)minorValue intValue];
                                                    }
                                                    else if ([minorValue isKindOfClass:[NSString class]])
                                                    {
                                                        serveriBeacon.minor = [(NSString *)minorValue intValue];
                                                    }
                                                    serveriBeacon.serverId = [dictMajor[minorValue] intValue];
                                                    [arrayList addObject:serveriBeacon];
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            //compare current memory's `arrayiBeaconFetchList` (same as cached APPSTATUS_IBEACON_FETCH_LIST), if not in new list, stop monitor; if find new, add monitor. Note: start/stop iBeacon region uses wild-match, that is ONLY uuid is used to create the region, major and minor not provided. This is because same identifier causes previous region removed, so must create unique identifier, the less region the better. CLLocationManager only supports 19 iBeacon regions. When find match, use major and minor to match to server id.
                            NSMutableArray *serverUUids = [[NSMutableArray alloc] init];
                            NSMutableArray *localUUids = [[NSMutableArray alloc] init];
                            for (SHServeriBeacon *ibeacon in arrayList)
                            {
                                if (![serverUUids containsObject:ibeacon.uuid])
                                {
                                    [serverUUids addObject:ibeacon.uuid];
                                }
                            }
                            for (SHServeriBeacon *ibeacon in self.arrayiBeaconFetchList)
                            {
                                if (![localUUids containsObject:ibeacon.uuid])
                                {
                                    [localUUids addObject:ibeacon.uuid];
                                }
                            }
                            for (NSString *serverUUid in serverUUids)
                            {
                                BOOL findInLocal = NO;
                                for (NSString *localUUid in localUUids)
                                {
                                    if ([serverUUid compare:localUUid options:NSCaseInsensitiveSearch] == NSOrderedSame)  //only consider uuid, wild-match
                                    {
                                        findInLocal = YES;
                                        break;
                                    }
                                }
                                if (!findInLocal) //server return one not in local cache, start monitor.
                                {
                                    SHLog(@"Start monitor server's iBeacon region for UUid: %@.", serverUUid);
                                    [StreetHawk.locationManager startMonitorRegion:[SHServeriBeacon getBeaconRegionForUUid:serverUUid]];
                                }
                            }
                            for (NSString *localUUid in localUUids)
                            {
                                BOOL findInServer = NO;
                                for (NSString *serverUUid in serverUUids)
                                {
                                    if ([serverUUid compare:localUUid options:NSCaseInsensitiveSearch] == NSOrderedSame)
                                    {
                                        findInServer = YES;
                                        break;
                                    }
                                }
                                if (!findInServer) //local has one not in server, stop monitor.
                                {
                                    CLBeaconRegion *stopRegion = [SHServeriBeacon getBeaconRegionForUUid:localUUid];
                                    [StreetHawk.locationManager stopMonitorRegion:stopRegion];
                                    NSArray *arrayStopMonitorServeriBeacons = [self findServeriBeaconsInsideRegion:stopRegion onlyWithDistance:NO/*all, not from inside to outside*/ needSetOutside:YES];
                                    NSAssert(arrayStopMonitorServeriBeacons.count != 0, @"Fail to find matching server iBeacons for region %@.", stopRegion);
                                    [self sendLogForiBeacons:arrayStopMonitorServeriBeacons isInside:NO]; //need this because "stop monitor" not trigger any delegate.
                                    SHLog(@"Stop monitor server's iBeacon region for UUid: %@.", localUUid);
                                }
                            }
                            //store server's list into local cache and update memory
                            self.arrayiBeaconFetchList = arrayList;
                            [[NSUserDefaults standardUserDefaults] setObject:[SHServeriBeacon serializeToStringArray:arrayList] forKey:APPSTATUS_IBEACON_FETCH_LIST];
                            [[NSUserDefaults standardUserDefaults] synchronize];
                        }
                    }
                    else
                    {
                        [[NSUserDefaults standardUserDefaults] setObject:@(0) forKey:APPSTATUS_IBEACON_FETCH_TIME]; //make next fetch happen as this time fail.
                        [[NSUserDefaults standardUserDefaults] synchronize];
                    }
                };
                [fetchRequest startAsynchronously];
            }
            return;
        }
    }
    //when meet this, means server return nil or invalid timestamp. Clear local fetch list and stop monitor.
    for (SHServeriBeacon *localiBeacon in self.arrayiBeaconFetchList)
    {
        [StreetHawk.locationManager stopMonitorRegion:[SHServeriBeacon getBeaconRegionForUUid:localiBeacon.uuid]]; //harmless for duplicate call
    }
    [self sendLogForiBeacons:self.arrayiBeaconFetchList isInside:NO]; //set all to be distance=null in server, need this because "stop monitor" not trigger any delegate.
    self.arrayiBeaconFetchList = [NSMutableArray array]; //cannot set to nil, as nil will read from NSUserDefaults again.
    [[NSUserDefaults standardUserDefaults] setObject:[NSArray array] forKey:APPSTATUS_IBEACON_FETCH_LIST];  //clear local cache, not start when kill and launch App.
    [[NSUserDefaults standardUserDefaults] synchronize];
#endif
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

#ifdef SH_FEATURE_IBEACON

- (NSMutableArray *)arrayiBeaconFetchList
{
    if (_arrayiBeaconFetchList == nil) //never initialized
    {
        _arrayiBeaconFetchList = [NSMutableArray arrayWithArray:[SHServeriBeacon deserializeToObjArray:[[NSUserDefaults standardUserDefaults] objectForKey:APPSTATUS_IBEACON_FETCH_LIST]]]; //it will not get nil even empty
    }
    return _arrayiBeaconFetchList;
}

- (void)sendLogForiBeacons:(NSArray *)arrayServeriBeacons isInside:(BOOL)isInside
{
    if (arrayServeriBeacons != nil && arrayServeriBeacons.count > 0)
    {
        NSMutableDictionary *dictDistance = [[NSMutableDictionary alloc] init];
        for (SHServeriBeacon *iBeacon in arrayServeriBeacons)
        {
            double distance = isInside ? (iBeacon.distance > 0 ? iBeacon.distance : 1)/*enter region set distance=meter value*/ : -1/*exit region set distance=-1*/;
            [dictDistance setObject:[NSNumber numberWithDouble:distance] forKey:[NSString stringWithFormat:@"%d", iBeacon.serverId]/*must use string for key, cannot use NSNumber*/];
        }
        NSString *distanceStr = shSerializeObjToJson(dictDistance);
        if (!shStrIsEmpty(distanceStr))
        {
            [StreetHawk sendLogForCode:LOG_CODE_LOCATION_IBEACON withComment:distanceStr];
        }
    }
}

- (NSArray *)findServeriBeaconsInsideRegion:(CLBeaconRegion *)region onlyWithDistance:(BOOL)requireDistance needSetOutside:(BOOL)setOutside
{
    NSMutableArray *arrayMatchServeriBeacons = [[NSMutableArray alloc] init];
    for (SHServeriBeacon *serveriBeacon in self.arrayiBeaconFetchList)
    {
        if ([serveriBeacon.uuid compare:region.proximityUUID.UUIDString options:NSCaseInsensitiveSearch] == NSOrderedSame)
        {
            if (!requireDistance || serveriBeacon.distance > 0)
            {
                [arrayMatchServeriBeacons addObject:serveriBeacon];
                if (setOutside)
                {
                    serveriBeacon.distance = INT64_MIN; //set to outside, used for exit region.
                }
            }
        }
    }
    return arrayMatchServeriBeacons;
}

- (void)regionRangeNotificationHandler:(NSNotification *)notification
{
    CLBeaconRegion *region = notification.userInfo[SHLMNotification_kRegion];
    NSArray *arrayThisRanging = notification.userInfo[SHLMNotification_kBeacons];
    //inside one region must keep ranging, because in case iBeacon1 and iBeacon2 have same UUID so in same region, when iBeacon1 out and iBeacon2 still in, the region state won't change until iBeacon2 out. To know exactly what iBeacons inside must keep ranging until exit this region. But server does not expect receive duplicated logs, so only when one iBeacon int or out send log.
    NSArray *arrayPreviousRanging = [self findServeriBeaconsInsideRegion:region onlyWithDistance:NO needSetOutside:NO]; //all server iBeacon inside this region.
    NSMutableArray *arrayChangeIn = [NSMutableArray array];
    NSMutableArray *arrayChangeOut = [NSMutableArray array];
    for (CLBeacon *iBeacon in arrayThisRanging)
    {
        SHServeriBeacon *matchingServeriBeacon = nil;
        for (SHServeriBeacon *serveriBeacon in arrayPreviousRanging)
        {
            NSAssert([iBeacon.proximityUUID.UUIDString compare:serveriBeacon.uuid options:NSCaseInsensitiveSearch] == NSOrderedSame, @"Range should in same region.");
            if (iBeacon.major.intValue == serveriBeacon.major && iBeacon.minor.intValue == serveriBeacon.minor)
            {
                matchingServeriBeacon = serveriBeacon;
                break;
            }
        }
        if (matchingServeriBeacon != nil) //possible to monitor other iBeacon not added into streethawk server
        {
            if (matchingServeriBeacon.distance < 0) //means newly inside
            {
                matchingServeriBeacon.distance = iBeacon.accuracy > 0/*by testing it occassionally negative*/ ? iBeacon.accuracy : 1; //self.arrayiBeaconFetchList object's distance also updated
                [arrayChangeIn addObject:matchingServeriBeacon];
            }
        }
    }
    for (SHServeriBeacon *serveriBeacon in arrayPreviousRanging)
    {
        if (serveriBeacon.distance > 0 && ![arrayChangeIn containsObject:serveriBeacon])
        {
            BOOL findInThis = NO;
            for (CLBeacon *iBeacon in arrayThisRanging)
            {
                NSAssert([iBeacon.proximityUUID.UUIDString compare:serveriBeacon.uuid options:NSCaseInsensitiveSearch] == NSOrderedSame, @"Range should in same region.");
                if (iBeacon.major.intValue == serveriBeacon.major && iBeacon.minor.intValue == serveriBeacon.minor)
                {
                    findInThis = YES;
                    break;
                }
            }
            if (!findInThis) //means newly outside
            {
                serveriBeacon.distance = INT64_MIN;
                [arrayChangeOut addObject:serveriBeacon];
            }
        }
    }
    if (arrayChangeIn.count > 0)
    {
        [self sendLogForiBeacons:arrayChangeIn isInside:YES];
    }
    if (arrayChangeOut.count > 0)
    {
        [self sendLogForiBeacons:arrayChangeOut isInside:NO];
    }
    if (arrayChangeIn.count > 0 || arrayChangeOut.count > 0)
    {
        //distance should be serialize to disk, in case re-launch and exit region, should find match server ibeacon from disk with distance.
        [[NSUserDefaults standardUserDefaults] setObject:[SHServeriBeacon serializeToStringArray:self.arrayiBeaconFetchList] forKey:APPSTATUS_IBEACON_FETCH_LIST];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

#endif

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

#if defined(SH_FEATURE_IBEACON) || defined(SH_FEATURE_GEOFENCE)

- (void)regionStateChangeNotificationHandler:(NSNotification *)notification
{
    //use state change instead of didEnterRegion/didExitRegion because when startMonitorRegion, state change delegate is called, didEnter/ExitRegion delegate not called until next enter/exit.
    CLRegion *region = notification.userInfo[SHLMNotification_kRegion];
    CLRegionState regionState = [notification.userInfo[SHLMNotification_kRegionState] intValue];
    if (regionState == CLRegionStateInside)
    {
        if ([region isKindOfClass:[CLBeaconRegion class]])
        {
#ifdef SH_FEATURE_IBEACON
        //inside an iBeacon region, need to range to find what exactly iBeacons are meet.
        [StreetHawk.locationManager startRangeiBeaconRegion:(CLBeaconRegion *)region];
#endif
        }
        else if ([region isKindOfClass:[CLCircularRegion class]])
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
        if ([region isKindOfClass:[CLBeaconRegion class]])
        {
#ifdef SH_FEATURE_IBEACON
            [StreetHawk.locationManager stopRangeiBeaconRegion:(CLBeaconRegion *)region];   //exit one region so stop ranging it, after each one iBeacon outside, it may range for a while and trigger exit region state.
            NSArray *arrayServeriBeacons = [self findServeriBeaconsInsideRegion:(CLBeaconRegion *)region onlyWithDistance:YES needSetOutside:YES]; //this updates distance already
            [self sendLogForiBeacons:arrayServeriBeacons isInside:NO];
            if (arrayServeriBeacons.count > 0)
            {
                //distance should be serialize to disk, in case re-launch and exit region, should find match server ibeacon from disk with distance.
                [[NSUserDefaults standardUserDefaults] setObject:[SHServeriBeacon serializeToStringArray:self.arrayiBeaconFetchList] forKey:APPSTATUS_IBEACON_FETCH_LIST];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }
#endif
        }
        else if ([region isKindOfClass:[CLCircularRegion class]])
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

#ifdef SH_FEATURE_IBEACON

@implementation SHServeriBeacon

@synthesize uuid = _uuid;
@synthesize major = _major;
@synthesize minor = _minor;

#pragma mark - life cycle

- (id)init
{
    if (self = [super init])
    {
        self.distance = INT64_MIN; //means not in range
    }
    return self;
}

#pragma mark - properties

- (void)setUuid:(NSString *)uuid
{
    NSAssert(!shStrIsEmpty(uuid), @"Invalid UUID: %@.", uuid);
    _uuid = uuid;
}

- (void)setMajor:(int)major
{
    NSAssert(major >= 0 && major <= 65535, @"Invalid major: %d.", major);
    _major = major;
}

- (void)setMinor:(int)minor
{
    NSAssert(minor >= 0 && minor <= 65535, @"Invalid minor: %d.", minor);
    _minor = minor;
}

#pragma mark - public functions

- (NSString *)description
{
    return [NSString stringWithFormat:@"[%d]%@,%d,%d/%f", self.serverId, self.uuid, self.major, self.minor, self.distance];
}

- (BOOL)isEqual:(id)object
{
    if ([object isKindOfClass:[SHServeriBeacon class]])
    {
        SHServeriBeacon *serveriBeacon = (SHServeriBeacon *)object;
        if ([self.uuid compare:serveriBeacon.uuid options:NSCaseInsensitiveSearch] == NSOrderedSame
            && self.major == serveriBeacon.major
            && self.minor == serveriBeacon.minor
            && self.serverId == serveriBeacon.serverId)
        {
            return YES;
        }
    }
    return NO;
}

+ (CLBeaconRegion *)getBeaconRegionForUUid:(NSString *)uuid
{
    //March 23 2015: customer reports serious issue: iBeacon enter/exit not trigger. https://bitbucket.org/shawk/streethawk/issue/599/unable-to-detect-beacons-for-shsample
    //It worked before but today test shows it really has this issue. Test shows identifier cannot use UUID. For example, test in FG:
    //case 1: monitor region A with identifier UUID first, and region A with identifier aaa, it cannot trigger delegate.
    //case 2: monitor region A with identifier aaa first, and region A with identifier UUID, it triggers delegate and show two regions.
    //So must format identifier like "StreetHawk1".
    NSString *identifier = nil;
    NSInteger sufixNumber = 0;
    BOOL isUsed = YES;
    while (isUsed)
    {
        sufixNumber++;
        identifier = [NSString stringWithFormat:@"StreetHawk%ld", (long)sufixNumber];
        isUsed = NO;
        for (CLRegion *region in StreetHawk.locationManager.monitoredRegions)
        {
            if ([identifier compare:region.identifier options:NSCaseInsensitiveSearch] == NSOrderedSame)
            {
                isUsed = YES;
                break;
            }
        }
    }
    NSAssert(identifier != nil, @"Fail to generate identifier.");
    CLBeaconRegion *region = [[CLBeaconRegion alloc] initWithProximityUUID:[[NSUUID alloc] initWithUUIDString:uuid] identifier:identifier];
    NSAssert(region != nil, @"Fail to create CLBeaconRegion from UUID: %@.", uuid);
    region.notifyOnEntry = YES; //trigger didEnter, it's also default settings
    region.notifyOnExit = YES; //trigger didExit, it's also default settings
    region.notifyEntryStateOnDisplay = NO; //no matter screen is on or off, should trigger delegate
    return region;
}

+ (NSArray *)serializeToStringArray:(NSArray *)objArray
{
    NSMutableArray *strArray = [NSMutableArray array];
    for (SHServeriBeacon *obj in objArray)
    {
        [strArray addObject:obj.description];
    }
    return strArray;
}

+ (NSArray *)deserializeToObjArray:(NSArray *)stringArray
{
    NSMutableArray *objArray = [NSMutableArray array];
    for (NSString *str in stringArray)
    {
        //[4725]F7826DA6-4FA2-4E98-8024-BC5B71E0893E,23548,15844/1.5
        SHServeriBeacon *obj = [[SHServeriBeacon alloc] init];
        NSRange rangeId = [str rangeOfString:@"]"];
        if (rangeId.location != NSNotFound && rangeId.location > 1)
        {
            obj.serverId = [[str substringWithRange:NSMakeRange(1, rangeId.location - 1)] intValue];
        }
        NSRange rangeUuid = [str rangeOfString:@","];
        if (rangeUuid.location != NSNotFound && rangeUuid.location > rangeId.location + 1)
        {
            obj.uuid = [str substringWithRange:NSMakeRange(rangeId.location + 1, rangeUuid.location - rangeId.location - 1)];
        }
        NSRange rangeMajor = [str rangeOfString:@"," options:NSCaseInsensitiveSearch range:NSMakeRange(rangeUuid.location + 1, str.length - rangeUuid.location - 1)];
        if (rangeMajor.location != NSNotFound && rangeMajor.location > rangeUuid.location + 1)
        {
            obj.major = [[str substringWithRange:NSMakeRange(rangeUuid.location + 1, rangeMajor.location - rangeUuid.location - 1)] intValue];
        }
        NSRange rangeDistance = [str rangeOfString:@"/"];
        if (rangeDistance.location != NSNotFound && rangeDistance.location > rangeMajor.location + 1 && rangeDistance.location + 1 < str.length) //new format, add distance as /1.5
        {
            obj.minor = [[str substringWithRange:NSMakeRange(rangeMajor.location + 1, rangeDistance.location - rangeMajor.location - 1)] intValue];
            obj.distance = [[str substringFromIndex:rangeDistance.location + 1] doubleValue];
        }
        else //old format, not include distance
        {
            if (rangeMajor.location + 1 < str.length)
            {
                obj.minor = [[str substringFromIndex:rangeMajor.location + 1] intValue];
            }
        }
        [objArray addObject:obj];
    }
    return objArray;
}

@end

#endif

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