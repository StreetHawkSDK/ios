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

#import "SHHTTPSessionManager.h"
//header from StreetHawk
#import "SHApp.h" //for `StreetHawk` properties
#import "SHAppStatus.h" //for alive host
#import "SHUtils.h" //for shStrIsEmpty

//Json return type: {code: 0, value: ...}, 0 for successful, other for fail.
#define CODE_OK     0

/**
 StreetHawk normally return a json value like {code: <int_code>, value: <value_object>}, make the parse result into this object.
 */
@interface SHHTTPParseResult : NSObject

/**
 Parse result.
 */
@property int resultCode;

/**
 Parse object, usually a NSDictionary.
 */
@property id resultObject;

@end

@interface SHHTTPSessionManager ()

- (NSString *)completeUrl:(NSString *)urlString withHostVersion:(SHHostVersion)hostVersion; //StreetHawk can change base url on-fly, and has version as /v1, /v2.
- (BOOL)isStreetHawkSpecific:(NSString *)completeUrl; //Whether talking to StreetHawk specific server, if yes need to add header and parameter.
- (void)completeHeader; //StreetHawk has specific header.
- (id)completeParameters:(id)parameters; //StreetHawk needs to add additional parameters.
- (void)setTimeout; //set timeout for the task

@end

@implementation SHHTTPSessionManager

#pragma mark - life cycle

+ (SHHTTPSessionManager *)sharedInstance
{
    static SHHTTPSessionManager *sharedHTTPSessionManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        sharedHTTPSessionManager = [[SHHTTPSessionManager alloc] initWithSessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    });
    return sharedHTTPSessionManager;
}

#pragma mark - override functions

- (nullable NSURLSessionDataTask *)GET:(nonnull NSString *)URLString hostVersion:(SHHostVersion)hostVersion parameters:(nullable id)parameters success:(nullable void (^)(NSURLSessionDataTask * _Nullable task, id _Nullable responseObject))success failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSError * _Nullable error))failure
{
    URLString = [self completeUrl:URLString withHostVersion:hostVersion];
    if ([self isStreetHawkSpecific:URLString])
    {
        [self completeHeader];
        parameters = [self completeParameters:parameters];
    }
    [self setTimeout];
    NSURLSessionDataTask *task = [super GET:URLString parameters:parameters progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject)
    {
        SHHTTPParseResult *parseResult = [self parseResponse:task.response withObject:responseObject]; //whenever success process a request, do parser as it affects AppStatus.
        if (parseResult.resultCode != CODE_OK) //If resultCode != 0 it means error too.
        {
            if (failure)
            {
                NSString *errorDescription = [NSString stringWithFormat:@"%@", responseObject];
                NSError *error = [NSError errorWithDomain:SHErrorDomain code:INT_MIN userInfo:@{NSLocalizedDescriptionKey: errorDescription}];
                failure(task, error);
            }
        }
        else
        {
            if (success)
            {
                success(task, parseResult.resultObject);
            }
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error)
    {
        if (failure)
        {
            failure(task, error);
        }
    }];
    SHLog(@"GET - %@", URLString);
    return task;
}

- (nullable NSURLSessionDataTask *)POST:(nonnull NSString *)URLString hostVersion:(SHHostVersion)hostVersion parameters:(nullable id)parameters success:(nullable void (^)(NSURLSessionDataTask * _Nullable task, id _Nullable responseObject))success failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSError * _Nullable error))failure
{
    URLString = [self completeUrl:URLString withHostVersion:hostVersion];
    if ([self isStreetHawkSpecific:URLString])
    {
        [self completeHeader];
        parameters = [self completeParameters:parameters];
    }
    [self setTimeout];
    NSURLSessionDataTask *task = [super POST:URLString parameters:parameters progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject)
    {
        SHHTTPParseResult *parseResult = [self parseResponse:task.response withObject:responseObject]; //whenever success process a request, do parser as it affects AppStatus.
        if (parseResult.resultCode != CODE_OK) //If resultCode != 0 it means error too.
        {
            if (failure)
            {
                NSString *errorDescription = [NSString stringWithFormat:@"%@", responseObject];
                NSError *error = [NSError errorWithDomain:SHErrorDomain code:INT_MIN userInfo:@{NSLocalizedDescriptionKey: errorDescription}];
                failure(task, error);
            }
        }
        else
        {
            if (success)
            {
                success(task, parseResult.resultObject);
            }
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error)
    {
        if (failure)
        {
            failure(task, error);
        }
    }];
    SHLog(@"POST - %@", URLString);
    return task;
}

#pragma mark - private functions

- (NSString *)completeUrl:(NSString *)urlString withHostVersion:(SHHostVersion)hostVersion
{
    NSMutableString *completeUrl = [NSMutableString string];
    if (urlString != nil && ([urlString.lowercaseString hasPrefix:@"http://"] || [urlString.lowercaseString hasPrefix:@"https://"]))
    {
        [completeUrl appendString:urlString]; //urlString is just the complete url
    }
    else
    {
        //base url
        NSString *hostUrl = [[SHAppStatus sharedInstance] aliveHostForVersion:hostVersion];
        NSAssert(!shStrIsEmpty(hostUrl), @"No host base URL.");
        [completeUrl appendString:hostUrl];
        //adding path
        if (!shStrIsEmpty(urlString))
        {
            if ([completeUrl hasSuffix:@"/"])
            {
                [completeUrl deleteCharactersInRange:NSMakeRange(completeUrl.length-1, 1)]; //remove last "/"
            }
            if ([urlString characterAtIndex:0] == '/')
            {
                urlString = [urlString substringFromIndex:1];  //remove first "/"
            }
            if ([urlString hasSuffix:@"/"])  //remove last "/", recent change in StreetHawk server requires NOT have "/" at path end.
            {
                urlString = [urlString substringToIndex:urlString.length - 1];
            }
            [completeUrl appendFormat:@"/%@", urlString];
        }
    }
    return completeUrl;
}

- (BOOL)isStreetHawkSpecific:(NSString *)completeUrl
{
    return [completeUrl.lowercaseString hasPrefix:@"https://api.streethawk.com"];
}

- (void)completeHeader
{
    [self.requestSerializer setValue:[NSString stringWithFormat:@"%@(%@)", StreetHawk.appKey, StreetHawk.version] forHTTPHeaderField:@"User-Agent"]; //e.g: "SHSample(1.5.3)"
    [self.requestSerializer setValue:NONULL(StreetHawk.appKey) forHTTPHeaderField:@"X-App-Key"];
    [self.requestSerializer setValue:StreetHawk.version forHTTPHeaderField:@"X-Version"];
    [self.requestSerializer setValue:!shStrIsEmpty(StreetHawk.currentInstall.suid) ? StreetHawk.currentInstall.suid : @"null" forHTTPHeaderField:@"X-Installid"];
}

- (id)completeParameters:(id)parameters
{
    //Every streethawk.com request, no matter GET or POST, should include "installid" in the request. Add it no matter GET or POST in params.
    if (!shStrIsEmpty(StreetHawk.currentInstall.suid) && parameters != nil)
    {
        if ([parameters isKindOfClass:[NSDictionary class]])
        {
            NSDictionary *dictParameters = (NSDictionary *)parameters;
            if (![dictParameters.allKeys containsObject:@"installid"])
            {
                NSMutableDictionary *refinedParameters = [NSMutableDictionary dictionaryWithDictionary:parameters];
                [refinedParameters setObject:StreetHawk.currentInstall.suid forKey:@"installid"];
                return refinedParameters;
            }
        }
        else if ([parameters isKindOfClass:[NSArray class]])
        {
            NSArray *arrayParameters = (NSArray *)parameters;
            if (![arrayParameters containsObject:@"installid"])
            {
                NSMutableArray *refinedParameters = [NSMutableArray arrayWithArray:parameters];
                [refinedParameters addObject:@"installid"];
                [refinedParameters addObject:StreetHawk.currentInstall.suid];
                return refinedParameters;
            }
        }
    }
    return parameters;
}

- (void)setTimeout
{
    //Background fetch must be finished in 30 seconds, however when testing found `[UIApplication sharedApplication].backgroundTimeRemaining` sometimes is more than 30 seconds, for example if just enter background it's 180 seconds, if start background task it's 10 minutes. Thus cannot depend on `[UIApplication sharedApplication].backgroundTimeRemaining` to calculate timeout.
    //To be safe and simple, if in background, timeout is 13 seconds(sometimes heartbeat follow by location update), if in foreground, timeout is 60 seconds.
    [self.requestSerializer setTimeoutInterval:([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) ? 13 : 60];
}

- (SHHTTPParseResult *)parseResponse:(NSURLResponse *)response withObject:(id)responseObject
{
    SHHTTPParseResult *parseResult = [[SHHTTPParseResult alloc] init];
    if ([response.MIMEType compare:@"application/json" options:NSCaseInsensitiveSearch] == NSOrderedSame ||
        [response.MIMEType compare:@"text/json" options:NSCaseInsensitiveSearch] == NSOrderedSame ||
        [response.MIMEType compare:@"text/javascript" options:NSCaseInsensitiveSearch] == NSOrderedSame)
    {
        NSDictionary *dict = (NSDictionary *)responseObject;
        NSAssert(dict != nil && [dict isKindOfClass:[NSDictionary class]], @"Fail to parse response %@.", responseObject);
        if (dict != nil && [dict isKindOfClass:NSDictionary.class])
        {
            NSObject *code = dict[@"code"];
            NSObject *value = dict[@"value"];
            BOOL hasValidCode = (code != nil && [code isKindOfClass:[NSNumber class]]);
            BOOL hasValidValue = value != nil && (value == (id)[NSNull null] || [value isKindOfClass:[NSArray class]] || [value isKindOfClass:[NSDictionary class]] || [value isKindOfClass:[NSString class]]/*when fail value is error message*/ || [value isKindOfClass:[NSNumber class]]/*when invite friend, return task id*/);
            if ([response.URL.absoluteString.lowercaseString hasPrefix:@"https://api.streethawk.com"])
            {
                //only force check this format for StreetHawk server, customer may use it to do other request.
                NSAssert(hasValidCode, @"Wrong format to get resultCode. Dict: %@", dict);
                NSAssert(hasValidValue, @"Wrong format to get resultValue. Dict: %@", dict);
            }
            hasValidValue = YES; //disable "Unused variable" due to NSAssert ignored in pods.
            if (hasValidCode)
            {
                parseResult.resultCode =  [(NSNumber *)code intValue];
            }
            if (value)
            {
                parseResult.resultObject = value;
            }
            //response may have "app_status" section, but it's not guranteed to have all keys, or even have this section.
            NSDictionary *dictStatus = nil;
            if ([dict.allKeys containsObject:@"app_status"] && [dict[@"app_status"] isKindOfClass:[NSDictionary class]])
            {
                dictStatus = (NSDictionary *)dict[@"app_status"]; //Most request use "app_status" because they have installid
            }
            else if ([response.URL.absoluteString rangeOfString:@"apps/status"].location != NSNotFound && [parseResult.resultObject isKindOfClass:[NSDictionary class]]) //First not have installid, Tobias return by value, must do it in else
            {
                dictStatus = (NSDictionary *)parseResult.resultObject;
            }
            if (dictStatus != nil)
            {
                //check "streethawk" to enable/disable library function
                if ([dictStatus.allKeys containsObject:@"streethawk"] && [dictStatus[@"streethawk"] respondsToSelector:@selector(boolValue)])
                {
                    [SHAppStatus sharedInstance].streethawkEnabled = [dictStatus[@"streethawk"] boolValue];
                }
                //check "host"
                if ([dictStatus.allKeys containsObject:@"host"] && [dictStatus[@"host"] isKindOfClass:[NSString class]])
                {
                    [SHAppStatus sharedInstance].aliveHost = dictStatus[@"host"];
                }
                //check "location_updates"
                if ([dictStatus.allKeys containsObject:@"location_updates"] && [dictStatus[@"location_updates"] respondsToSelector:@selector(boolValue)])
                {
                    [SHAppStatus sharedInstance].uploadLocationChange = [dictStatus[@"location_updates"] boolValue];
                }
                //check "submit_views"
                if ([dictStatus.allKeys containsObject:@"submit_views"] && [dictStatus[@"submit_views"] respondsToSelector:@selector(boolValue)])
                {
                    [SHAppStatus sharedInstance].allowSubmitFriendlyNames = [dictStatus[@"submit_views"] boolValue];
                }
                //check "ibeacon"
                if ([dictStatus.allKeys containsObject:@"ibeacon"])
                {
                    [SHAppStatus sharedInstance].iBeaconTimestamp = dictStatus[@"ibeacon"]; //it may be nil
                }
                //check "geofences"
                if ([dictStatus.allKeys containsObject:@"geofences"])
                {
                    [SHAppStatus sharedInstance].geofenceTimestamp = dictStatus[@"geofences"];
                }
                //check "feed"
                if ([dictStatus.allKeys containsObject:@"feed"])
                {
                    [SHAppStatus sharedInstance].feedTimestamp = dictStatus[@"feed"];
                }
                //check "reregister"
                if ([dictStatus.allKeys containsObject:@"reregister"])
                {
                    [SHAppStatus sharedInstance].reregister = [dictStatus[@"reregister"] boolValue];
                }
                //check "app_store_id"
                if ([dictStatus.allKeys containsObject:@"app_store_id"])
                {
                    [SHAppStatus sharedInstance].appstoreId = dictStatus[@"app_store_id"];
                }
                //check "disable_logs"
                [SHAppStatus sharedInstance].logDisableCodes = dictStatus[@"disable_logs"]; //directly pass nil
                //check "priority"
                [SHAppStatus sharedInstance].logPriorityCodes = dictStatus[@"priority"];
                //refresh app_status check time
                [[SHAppStatus sharedInstance] recordCheckTime];
            }
            //response may have "push" for smart push.
            if ([dict.allKeys containsObject:@"push"] && [dict[@"push"] isKindOfClass:[NSDictionary class]])
            {
                NSDictionary *payload = (NSDictionary *)dict[@"push"]; //it's same format as remote notification.
                [[NSUserDefaults standardUserDefaults] setObject:payload forKey:SMART_PUSH_PAYLOAD];
                [[NSUserDefaults standardUserDefaults] synchronize];
                //App not in FG, store locally and wait for `applicationDidBecomeActiveNotificationHandler` to handle it.
                if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) //App in FG, directly handle this smart push.
                {
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PushBridge_Smart_Notification" object:nil];
                }
            }
        }
    }
    else if ([response.MIMEType compare:@"text/plain" options:NSCaseInsensitiveSearch] == NSOrderedSame)
    {
        //For example https://api.streethawk.com/v1/core/library?operating_system=ios just return 1.3.2, without any {code:0, value:...}
        parseResult.resultCode = CODE_OK;
        parseResult.resultObject = responseObject;
    }
    return parseResult;
}

@end

@implementation SHHTTPParseResult

@end
