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

#import "SHBeaconStatus.h"
//header from StreetHawk
#import "SHUtils.h" //for SHLog
#import "SHApp.h" //for `StreetHawk.currentInstall`
#import "SHLogger.h" //for sending logline
#import "SHHTTPSessionManager.h" //for sending request
#import "SHLocationManager.h"

#define APPSTATUS_IBEACON_FETCH_TIME        @"APPSTATUS_IBEACON_FETCH_TIME"  //last successfully fetch iBeacon list time
#define APPSTATUS_IBEACON_FETCH_LIST        @"APPSTATUS_IBEACON_FETCH_LIST"  //iBeacon list fetched from server, it contains array for object: UUID, major, minor, id. This is used as iBeacon monitor region.

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

@interface SHBeaconStatus ()

@property (strong, nonatomic) NSMutableArray *arrayiBeaconFetchList;  //Server controls client to monitor a certain iBeacon list by request "/ibeacons", this list is cached locally and returned by this property. It's array of `SHServeriBeacon`. "app_status"'s "ibeacon" timestamp controls when to fetch this list again.
- (void)sendLogForiBeacons:(NSArray *)arrayServeriBeacons isInside:(BOOL)isInside; //Send install/log for enter or exit(stop monitor) server iBeacons. If enter region, distance = ranged first distance or 1; if exit region, distance = `null`. If not enter or exit but only distance change, not send this install/log. code=21, comment formatted as {serverid: distance}.
- (NSArray *)findServeriBeaconsInsideRegion:(CLBeaconRegion *)region onlyWithDistance:(BOOL)requireDistance needSetOutside:(BOOL)setOutside;  //get SHServeriBeacon list, subset of self.arrayiBeaconFetchList, which match this region. If `requireDistance` means get those with distance, otherwise get all SHServeriBeacon inside this region.
- (void)regionRangeNotificationHandler:(NSNotification *)notification; //when range a region to know exact iBeacons.
- (void)regionStateChangeNotificationHandler:(NSNotification *)notification; //monitor when a region state change.

@end

@implementation SHBeaconStatus

@synthesize arrayiBeaconFetchList = _arrayiBeaconFetchList;

#pragma mark - life cycle

+ (SHBeaconStatus *)sharedInstance
{
    static SHBeaconStatus *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
      {
          instance = [[SHBeaconStatus alloc] init];
      });
    return instance;
}

- (id)init
{
    if (self = [super init])
    {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(regionStateChangeNotificationHandler:) name:SHLMRegionStateChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(regionRangeNotificationHandler:) name:SHLMRangeiBeaconChangedNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - properties

- (NSString *)iBeaconTimestamp
{
    NSAssert(NO, @"Should not call iBeaconTimestamp.");
    return nil;
}

- (void)setIBeaconTimestamp:(NSString *)iBeaconTimestamp
{
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
    if (iBeaconTimestamp != nil && [iBeaconTimestamp isKindOfClass:[NSString class]])
    {
        NSDate *serverTime = shParseDate(iBeaconTimestamp, 0);
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
                //update local cache time before send request, because this request has same format as others {app_status:..., code:0, value:...}, it will trigger `setIBeaconTimestamp` again. If fail to get request, clear local cache time in callback handler, make next fetch happen.
                [[NSUserDefaults standardUserDefaults] setObject:@([[NSDate date] timeIntervalSinceReferenceDate]) forKey:APPSTATUS_IBEACON_FETCH_TIME];
                [[NSUserDefaults standardUserDefaults] synchronize];
                [[SHHTTPSessionManager sharedInstance] GET:@"/ibeacons/" hostVersion:SHHostVersion_V1 parameters:nil success:^(NSURLSessionDataTask * _Nullable task, id  _Nullable responseObject)
                {
                    //successfully fetch server's iBeacon list. local cache time is already updated, store fetch list and active monitor.
                    SHLog(@"Fetch server iBeacon list: %@.", responseObject);
                    NSAssert([responseObject isKindOfClass:[NSDictionary class]], @"Server return should be dictionary.");
                    if ([responseObject isKindOfClass:[NSDictionary class]])
                    {
                        NSMutableArray *arrayList = [NSMutableArray array];
                        NSDictionary *dictList = (NSDictionary *)responseObject;
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
                } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nullable error)
                {
                    [[NSUserDefaults standardUserDefaults] setObject:@(0) forKey:APPSTATUS_IBEACON_FETCH_TIME]; //make next fetch happen as this time fail.
                    [[NSUserDefaults standardUserDefaults] synchronize];
                }];
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
}

#pragma mark - private functions

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
            //Send notification to inform customer App.
            NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
            userInfo[@"uuid"] = NONULL(iBeacon.uuid);
            userInfo[@"major"] = @(iBeacon.major);
            userInfo[@"minor"] = @(iBeacon.minor);
            userInfo[@"serverId"] = @(iBeacon.serverId);
            userInfo[@"isInside"] = @(isInside);
            [[NSNotificationCenter defaultCenter] postNotificationName:SHLMEnterExitBeaconNotification object:nil userInfo:userInfo];            
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

- (void)regionStateChangeNotificationHandler:(NSNotification *)notification
{
    //use state change instead of didEnterRegion/didExitRegion because when startMonitorRegion, state change delegate is called, didEnter/ExitRegion delegate not called until next enter/exit.
    CLRegion *region = notification.userInfo[SHLMNotification_kRegion];
    CLRegionState regionState = [notification.userInfo[SHLMNotification_kRegionState] intValue];
    if (regionState == CLRegionStateInside)
    {
        if ([region isKindOfClass:[CLBeaconRegion class]])
        {
            //inside an iBeacon region, need to range to find what exactly iBeacons are meet.
            [StreetHawk.locationManager startRangeiBeaconRegion:(CLBeaconRegion *)region];
        }
    }
    else if (regionState == CLRegionStateOutside)
    {
        if ([region isKindOfClass:[CLBeaconRegion class]])
        {
            [StreetHawk.locationManager stopRangeiBeaconRegion:(CLBeaconRegion *)region];   //exit one region so stop ranging it, after each one iBeacon outside, it may range for a while and trigger exit region state.
            NSArray *arrayServeriBeacons = [self findServeriBeaconsInsideRegion:(CLBeaconRegion *)region onlyWithDistance:YES needSetOutside:YES]; //this updates distance already
            [self sendLogForiBeacons:arrayServeriBeacons isInside:NO];
            if (arrayServeriBeacons.count > 0)
            {
                //distance should be serialize to disk, in case re-launch and exit region, should find match server ibeacon from disk with distance.
                [[NSUserDefaults standardUserDefaults] setObject:[SHServeriBeacon serializeToStringArray:self.arrayiBeaconFetchList] forKey:APPSTATUS_IBEACON_FETCH_LIST];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }
        }
    }
    //do nothing for state=unknown.
}

@end

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
