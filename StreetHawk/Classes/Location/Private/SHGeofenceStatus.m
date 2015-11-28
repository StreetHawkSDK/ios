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

#import "SHGeofenceStatus.h"
//header from StreetHawk
#import "SHUtils.h" //for SHLog
#import "SHApp.h" //for `StreetHawk.currentInstall`
#import "SHLogger.h" //for sending logline
#import "SHRequest.h" //for sending request
#import "SHLocationManager.h"

#define APPSTATUS_GEOFENCE_FETCH_TIME       @"APPSTATUS_GEOFENCE_FETCH_TIME"  //last successfully fetch geofence list time
#define APPSTATUS_GEOFENCE_FETCH_LIST       @"APPSTATUS_GEOFENCE_FETCH_LIST"  //geofence list fetched from server, it contains parent geofence with child node. This is used as geofence monitor region.

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

@interface SHGeofenceStatus ()

@property (strong, nonatomic) NSMutableArray *arrayGeofenceFetchList; //simiar as above but for geofence fetch list.
- (void)sendLogForGeoFence:(SHServerGeofence *)geoFence isInside:(BOOL)isInside; //Send install/log for enter/exit server geofence.
- (SHServerGeofence *)findServerGeofenceForRegion:(CLRegion *)region;  //get SHServerGeofence list, subset of self.arrayGeofenceFetchList, which match this region. It searches both parent and child list.
- (void)stopMonitorPreviousGeofencesOnlyForOutside:(BOOL)onlyForOutside parentCanKeepChild:(BOOL)parentKeep;  //Geofence monitor region need to change, stop previous monitor for server's geofence. If `onlyForOutside`=YES, only stop monitor those outside; otherwise stop all regardless inside or outside. `parentKeep`=YES take effect when `onlyForOutside`=YES, if it's parent fence is inside, child fence not stop although it's outside.
- (void)startMonitorGeofences:(NSArray *)arrayGeofences;  //Give an array of SHServerGeofence and convert to be monitored. It doesn't create region for child nodes.
- (void)markSelfAndChildGeofenceOutside:(SHServerGeofence *)geofence; //When a geofence outside, mark itself and child (if has) to be outside, send out geofene logline for previous inside leave geofence too. Make it a separate function because it's recurisive.
- (void)stopMonitorSelfAndChildGeofence:(SHServerGeofence *)geofence; //when stop monitor inner geofence, stop monitor its child too. As child not stop when exit due to parent keep it.
- (SHServerGeofence *)searchSelfAndChild:(SHServerGeofence *)geofence forRegion:(CLCircularRegion *)geoRegion; //search recursively to match
- (void)regionStateChangeNotificationHandler:(NSNotification *)notification; //monitor when a region state change.

@end

@implementation SHGeofenceStatus

@synthesize arrayGeofenceFetchList = _arrayGeofenceFetchList;

#pragma mark - life cycle

+ (SHGeofenceStatus *)sharedInstance
{
    static SHGeofenceStatus *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
      {
          instance = [[SHGeofenceStatus alloc] init];
      });
    return instance;
}

- (id)init
{
    if (self = [super init])
    {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(regionStateChangeNotificationHandler:) name:SHLMRegionStateChangeNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - properties

- (NSString *)geofenceTimeStamp
{
    NSAssert(NO, @"Should not call geofenceTimeStamp.");
    return nil;
}

- (void)setGeofenceTimeStamp:(NSString *)geofenceTimeStamp
{
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
}

#pragma mark - private functions

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

- (void)regionStateChangeNotificationHandler:(NSNotification *)notification
{
    //use state change instead of didEnterRegion/didExitRegion because when startMonitorRegion, state change delegate is called, didEnter/ExitRegion delegate not called until next enter/exit.
    CLRegion *region = notification.userInfo[SHLMNotification_kRegion];
    CLRegionState regionState = [notification.userInfo[SHLMNotification_kRegionState] intValue];
    if (regionState == CLRegionStateInside)
    {
        if ([region isKindOfClass:[CLCircularRegion class]])
        {
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
        }
    }
    else if (regionState == CLRegionStateOutside)
    {
        if ([region isKindOfClass:[CLCircularRegion class]])
        {
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
        }
    }
    //do nothing for state=unknown.
}

@end

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
