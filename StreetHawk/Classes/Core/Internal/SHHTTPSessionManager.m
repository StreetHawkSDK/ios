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

@interface SHHTTPSessionManager ()

- (NSString *)completeUrl:(NSString *)urlString withHostVersion:(SHHostVersion)hostVersion; //StreetHawk can change base url on-fly, and has version as /v1, /v2.
- (BOOL)isStreetHawkSpecific:(NSString *)completeUrl; //Whether talking to StreetHawk specific server, if yes need to add header and parameter.
- (void)completeHeader; //StreetHawk has specific header.
- (NSDictionary *)completeParameters:(NSDictionary *)parameters; //StreetHawk needs to add additional parameters.
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
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error)
    {
        
    }];
    SHLog(@"GET - %@", URLString);
    [task resume];
    return task;
}

- (nullable NSURLSessionDataTask *)POST:(nonnull NSString *)URLString hostVersion:(SHHostVersion)hostVersion parameters:(nullable NSDictionary *)parameters success:(nullable void (^)(NSURLSessionDataTask * _Nullable task, id _Nullable responseObject))success failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSError * _Nullable error))failure
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
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error)
    {
        
    }];
    SHLog(@"POST - %@", URLString);
    [task resume];
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
    return [completeUrl.lowercaseString rangeOfString:@"streethawk.com"].location != NSNotFound;
}

- (void)completeHeader
{
    [self.requestSerializer setValue:[NSString stringWithFormat:@"%@(%@)", StreetHawk.appKey, StreetHawk.version] forHTTPHeaderField:@"User-Agent"]; //e.g: "SHSample(1.5.3)"
    [self.requestSerializer setValue:NONULL(StreetHawk.appKey) forHTTPHeaderField:@"X-App-Key"];
    [self.requestSerializer setValue:StreetHawk.version forHTTPHeaderField:@"X-Version"];
    [self.requestSerializer setValue:!shStrIsEmpty(StreetHawk.currentInstall.suid) ? StreetHawk.currentInstall.suid : @"null" forHTTPHeaderField:@"X-Installid"];
}

- (NSDictionary *)completeParameters:(NSDictionary *)parameters
{
    //Every streethawk.com request, no matter GET or POST, should include "installid" in the request. Add it no matter GET or POST in params.
    if (!shStrIsEmpty(StreetHawk.currentInstall.suid) && ![parameters.allKeys containsObject:@"installid"])
    {
        NSMutableDictionary *refinedParameters = [NSMutableDictionary dictionary];
        if (parameters)
        {
            [refinedParameters addEntriesFromDictionary:parameters];
        }
        [refinedParameters setObject:StreetHawk.currentInstall.suid forKey:@"installid"];
        return refinedParameters;
    }
    else
    {
        return parameters;
    }
}

- (void)setTimeout
{
    //Background fetch must be finished in 30 seconds, however when testing found `[UIApplication sharedApplication].backgroundTimeRemaining` sometimes is more than 30 seconds, for example if just enter background it's 180 seconds, if start background task it's 10 minutes. Thus cannot depend on `[UIApplication sharedApplication].backgroundTimeRemaining` to calculate timeout.
    //To be safe and simple, if in background, timeout is 13 seconds(sometimes heartbeat follow by location update), if in foreground, timeout is 60 seconds.
    [self.requestSerializer setTimeoutInterval:([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) ? 13 : 60];
}

@end
