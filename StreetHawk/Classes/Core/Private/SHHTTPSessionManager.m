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

@interface SHHTTPSessionManager ()

- (NSString *)completeStreetHawkSpecialUrl:(NSString *)urlString withHostVersion:(SHHostVersion)hostVersion; //StreetHawk can change base url on-fly, and has version as /v1, /v2, and must have additional header and "installid" in query string.
- (void)processSuccessCallback:(NSURLSessionDataTask * _Nonnull)task withData:(id _Nullable)responseObject success:(nullable void (^)(NSURLSessionDataTask * _Nullable task, id _Nullable responseObject))success failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSError * _Nullable error))failure; //process request successful callback.
- (void)processFailureCallback:(NSURLSessionDataTask * _Nonnull)task withError:(NSError * _Nullable)error failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSError * _Nullable error))failure; //process request failure callback.

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
          sharedHTTPSessionManager.completionQueue = dispatch_queue_create("com.streethawk.StreetHawk.network", NULL/*NULL attribute same as DISPATCH_QUEUE_SERIAL, means this queue is FIFO.*/); //set completionQueue otherwise completion callback runs in main thread.
          //add header
          [sharedHTTPSessionManager.requestSerializer setValue:[NSString stringWithFormat:@"%@(%@)", StreetHawk.appKey, StreetHawk.version] forHTTPHeaderField:@"User-Agent"]; //e.g: "SHSample(1.5.3)"
          [sharedHTTPSessionManager.requestSerializer setValue:NONULL(StreetHawk.appKey) forHTTPHeaderField:@"X-App-Key"];
          [sharedHTTPSessionManager.requestSerializer setValue:StreetHawk.version forHTTPHeaderField:@"X-Version"];
          [sharedHTTPSessionManager.requestSerializer setValue:!shStrIsEmpty(StreetHawk.currentInstall.suid) ? StreetHawk.currentInstall.suid : @"null" forHTTPHeaderField:@"X-Installid"];
          //Add install token for /v3 request. Cannot check host version here, add to all requests.
          NSString *installToken = [[NSUserDefaults standardUserDefaults] objectForKey:SH_INSTALL_TOKEN];
          if (!shStrIsEmpty(installToken))
          {
              [sharedHTTPSessionManager.requestSerializer setValue:installToken forHTTPHeaderField:@"X-Install-Token"];
          }
      });
    //By default it uses HTTP request and JSON response serializer.
    return sharedHTTPSessionManager;
}

#pragma mark - override functions

- (nullable NSURLSessionDataTask *)GET:(nonnull NSString *)URLString hostVersion:(SHHostVersion)hostVersion parameters:(nullable NSDictionary *)parameters success:(nullable void (^)(NSURLSessionDataTask * _Nullable task, id _Nullable responseObject))success failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSError * _Nullable error))failure
{
    URLString = [self completeStreetHawkSpecialUrl:URLString withHostVersion:hostVersion];
    NSURLSessionDataTask *task = [super GET:URLString parameters:parameters/*append as query string*/ progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) 
    {
        [self processSuccessCallback:task withData:responseObject success:success failure:failure];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error)
    {
        [self processFailureCallback:task withError:error failure:failure];
    }];
    SHLog(@"GET - %@", task.currentRequest.URL.absoluteString);
    return task;
}

- (nullable NSURLSessionDataTask *)POST:(nonnull NSString *)URLString hostVersion:(SHHostVersion)hostVersion body:(nullable NSDictionary *)body success:(nullable void (^)(NSURLSessionDataTask * _Nullable task, id _Nullable responseObject))success failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSError * _Nullable error))failure
{
    URLString = [self completeStreetHawkSpecialUrl:URLString withHostVersion:hostVersion];
    NSURLSessionDataTask *task = [super POST:URLString parameters:body/*will go to body*/ progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject)
    {
        [self processSuccessCallback:task withData:responseObject success:success failure:failure];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error)
    {
        [self processFailureCallback:task withError:error failure:failure];
    }];
    SHLog(@"POST - %@", task.currentRequest.URL.absoluteString);
    return task;
}

- (nullable NSURLSessionDataTask *)POST:(nonnull NSString *)URLString hostVersion:(SHHostVersion)hostVersion constructingBodyWithBlock:(nullable void (^)(id <SHAFMultipartFormData> _Nullable formData))block success:(nullable void (^)(NSURLSessionDataTask * _Nullable task, id _Nullable responseObject))success failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSError * _Nullable error))failure
{
    URLString = [self completeStreetHawkSpecialUrl:URLString withHostVersion:hostVersion];
    NSURLSessionDataTask *task = [super POST:URLString parameters:nil constructingBodyWithBlock:block progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject)
    {
        [self processSuccessCallback:task withData:responseObject success:success failure:failure];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error)
    {
        [self processFailureCallback:task withError:error failure:failure];
    }];
    SHLog(@"POST - %@", URLString);
    return task;
}

#pragma mark - private functions

- (NSString *)completeStreetHawkSpecialUrl:(NSString *)urlString withHostVersion:(SHHostVersion)hostVersion
{
    NSMutableString *completeUrl = [NSMutableString string];
    if (urlString != nil && ([urlString.lowercaseString hasPrefix:@"http://"] || [urlString.lowercaseString hasPrefix:@"https://"]))
    {
        [completeUrl appendString:urlString]; //urlString is just the complete url
    }
    else //this case is special for StreetHawk server requirement
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
        //add "installid"
        NSAssert([completeUrl rangeOfString:@"?"].location == NSNotFound, @"Query should not contained.");
        if (!shStrIsEmpty(StreetHawk.currentInstall.suid))
        {
            [completeUrl appendFormat:@"?installid=%@", StreetHawk.currentInstall.suid];
        }
    }
    //Background fetch must be finished in 30 seconds, however when testing found `[UIApplication sharedApplication].backgroundTimeRemaining` sometimes is more than 30 seconds, for example if just enter background it's 180 seconds, if start background task it's 10 minutes. Thus cannot depend on `[UIApplication sharedApplication].backgroundTimeRemaining` to calculate timeout.
    //To be safe and simple, if in background, timeout is 13 seconds(sometimes heartbeat follow by location update), if in foreground, timeout is 60 seconds.
    [self.requestSerializer setTimeoutInterval:([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) ? 13 : 60];
    return completeUrl;
}

- (void)processSuccessCallback:(NSURLSessionDataTask *)task withData:(id)responseObject success:(void (^)(NSURLSessionDataTask * _Nullable, id _Nullable))success failure:(void (^)(NSURLSessionDataTask * _Nullable, NSError * _Nullable))failure
{
    NSAssert(![NSThread isMainThread], @"Successfual callback wait in main thread for request %@.", task.currentRequest);
    if ([task.response.URL.absoluteString.lowercaseString containsString:@".streethawk.com"] //since route host server is flexible to change
        && ![task.response.URL.absoluteString.lowercaseString hasPrefix:NONULL([SHAppStatus sharedInstance].growthHost)] //growth is an exception
        && ![task.response.URL.absoluteString.lowercaseString containsString:@"/v3"]) //v3 endpoint doesn't have code-value format
    {
        //whenever success process a request, do parser as it affects AppStatus.
        int resultCode = CODE_OK;
        NSObject *resultValue = nil;
        if ([task.response.MIMEType compare:@"application/json" options:NSCaseInsensitiveSearch] == NSOrderedSame ||
            [task.response.MIMEType compare:@"text/json" options:NSCaseInsensitiveSearch] == NSOrderedSame ||
            [task.response.MIMEType compare:@"text/javascript" options:NSCaseInsensitiveSearch] == NSOrderedSame)
        {
            NSDictionary *dict = (NSDictionary *)responseObject;
            NSAssert(dict != nil && [dict isKindOfClass:[NSDictionary class]], @"Fail to parse response %@.", responseObject);
            if (dict != nil && [dict isKindOfClass:NSDictionary.class])
            {
                NSObject *code = dict[@"code"];
                NSObject *value = dict[@"value"];
                BOOL hasValidCode = (code != nil && [code isKindOfClass:[NSNumber class]]);
                BOOL hasValidValue = value != nil && (value == (id)[NSNull null] || [value isKindOfClass:[NSArray class]] || [value isKindOfClass:[NSDictionary class]] || [value isKindOfClass:[NSString class]]/*when fail value is error message*/ || [value isKindOfClass:[NSNumber class]]/*when invite friend, return task id*/);//only force check this format for StreetHawk server, customer may use it to do other request.
                NSAssert(hasValidCode, @"Wrong format to get resultCode. Dict: %@", dict);
                NSAssert(hasValidValue, @"Wrong format to get resultValue. Dict: %@", dict);
                hasValidValue = YES; //disable "Unused variable" due to NSAssert ignored in pods.
                if (hasValidCode)
                {
                    resultCode =  [(NSNumber *)code intValue];
                }
                if (value)
                {
                    resultValue = value;
                }
                //response may have "app_status" section, but it's not guranteed to have all keys, or even have this section.
                NSDictionary *dictStatus = nil;
                if ([dict.allKeys containsObject:@"app_status"] && [dict[@"app_status"] isKindOfClass:[NSDictionary class]])
                {
                    dictStatus = (NSDictionary *)dict[@"app_status"]; //Most request use "app_status" because they have installid
                }
                else if ([task.response.URL.absoluteString rangeOfString:@"apps/status"].location != NSNotFound && [resultValue isKindOfClass:[NSDictionary class]]) //First not have installid, Tobias return by value, must do it in else
                {
                    dictStatus = (NSDictionary *)resultValue;
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
                    //check "growth_host"
                    if ([dictStatus.allKeys containsObject:@"growth_host"] && [dictStatus[@"growth_host"] isKindOfClass:[NSString class]])
                    {
                        [SHAppStatus sharedInstance].growthHost = dictStatus[@"growth_host"];
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
                    if ([dictStatus.allKeys containsObject:@"submit_interactive_button"] && [dictStatus[@"submit_interactive_button"] respondsToSelector:@selector(boolValue)])
                    {
                        [SHAppStatus sharedInstance].allowSubmitInteractiveButton = [dictStatus[@"submit_interactive_button"] boolValue];
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
                        SHLog(@"feed timestamp in app_status: %@", dictStatus[@"feed"]);
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
        else if ([task.response.MIMEType compare:@"text/plain" options:NSCaseInsensitiveSearch] == NSOrderedSame)
        {
            //For example https://api.streethawk.com/v1/core/library?operating_system=ios just return 1.3.2, without any {code:0, value:...}
            resultCode = CODE_OK;
            resultValue = responseObject;
        }
        //Finish parse, give to handler
        if (resultCode != CODE_OK) //If resultCode != 0 it means error too.
        {
            NSString *errorDescription = [NSString stringWithFormat:@"%@", responseObject];
            NSError *error = [NSError errorWithDomain:SHErrorDomain code:INT_MIN userInfo:@{NSLocalizedDescriptionKey: errorDescription}];
            [self processFailureCallback:task withError:error failure:failure];
        }
        else
        {
            if (success)
            {
                success(task, resultValue);
            }
        }
    }
    else //directly give to handler
    {
        if (success)
        {
            success(task, responseObject);
        }
    }
}

- (void)processFailureCallback:(NSURLSessionDataTask * _Nonnull)task withError:(NSError * _Nullable)error failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSError * _Nullable error))failure
{
    NSAssert(![NSThread isMainThread], @"Failure callback wait in main thread for request %@.", task.currentRequest);
    NSString *detailError = nil; //if the detail error is inside error data, use it instead
    if (error.userInfo[@"com.alamofire.serialization.response.error.data"] != nil)
    {
        NSData *errorData = error.userInfo[@"com.alamofire.serialization.response.error.data"];
        detailError = [[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding];
    }
    if (failure)
    {
        if (shStrIsEmpty(detailError))
        {
            failure(task, error);
        }
        else
        {
            failure(task, [NSError errorWithDomain:SHErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey: detailError}]);
        }
    }
    //Show error on console when debug
    if (StreetHawk.isDebugMode && shAppMode() != SHAppMode_AppStore && shAppMode() != SHAppMode_Enterprise)
    {
        NSString *comment = nil;
        NSString *url = task.response.URL.absoluteString;
        NSString *method = task.currentRequest.HTTPMethod;
        if ([task.response isKindOfClass:[NSHTTPURLResponse class]])
        {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;
            comment = [NSString stringWithFormat:@"Status(%ld) %@ - %@. Error: %@.", (long)httpResponse.statusCode, method, url, error];
        }
        else
        {
            comment = [NSString stringWithFormat:@"URL request error: %@ - %@. Error: %@.", method, url, error];
        }
        if (method != nil && [method compare:@"POST" options:NSCaseInsensitiveSearch] == NSOrderedSame)
        {
            NSString *postStr = [[[NSString alloc] initWithData:task.currentRequest.HTTPBody encoding:NSUTF8StringEncoding] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            comment = [comment stringByAppendingFormat:@"\nPost body: %@.", postStr];
        }
        if (!shStrIsEmpty(detailError))
        {
            comment = [comment stringByAppendingFormat:@"\nError data: %@", detailError];
        }
        SHLog(@"Add breakpoint here to know error request happen for %@.", comment);
    }
}

@end

@implementation SHJSONSessionManager

+ (SHJSONSessionManager *)sharedInstance
{
    static SHJSONSessionManager *sharedJSONSessionManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
      {
          sharedJSONSessionManager = [[SHJSONSessionManager alloc] initWithSessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
          sharedJSONSessionManager.completionQueue = dispatch_queue_create("com.streethawk.StreetHawk.network", NULL/*NULL attribute same as DISPATCH_QUEUE_SERIAL, means this queue is FIFO.*/); //set completionQueue otherwise completion callback runs in main thread.
          //some APIs are moving to /v2 and must use JSON request, but some old APIs are still using HTTP request. Cannot switch requestSerializer otherwise cause random crash (https://streethawk.atlassian.net/browse/IOS-958). Keep individual singleton for each. Later when all server API moves to JSON, SHAFHTTPRequestSerializer can be removed.
          sharedJSONSessionManager.requestSerializer = [SHAFJSONRequestSerializer serializer];
      });
    return sharedJSONSessionManager;
}

@end
