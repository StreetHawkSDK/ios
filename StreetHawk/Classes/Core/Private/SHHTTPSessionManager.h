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

#import <Foundation/Foundation.h>
#import "SHAFHTTPSessionManager.h"

/**
 Current supporting host versions.
 */
enum SHHostVersion
{
    SHHostVersion_Unknown,
    SHHostVersion_V1,
    SHHostVersion_V2,
};
typedef enum SHHostVersion SHHostVersion;

#define SH_BODY  @"SH_BODY" //for string pass into post body, use this as key.

#define SMART_PUSH_PAYLOAD  @"SMART_PUSH_PAYLOAD"

/**
 All http requests used to communicate with server uses this class.
 */
@interface SHHTTPSessionManager : SHAFHTTPSessionManager

/** @name Creator */

/**
 Singleton instance. Caller normally only needs to use [SHHTTPSessionManager sharedInstance], which configures connection session to server.
 */
+ (nonnull SHHTTPSessionManager *)sharedInstance;

/**
 Wrapper for `SHAFHTTPSessionManager` Get method.
 @param URLString The path or complete url.
 @param hostVersion StreetHawk's request has version /v1, /v2 etc.
 @param parameters Request parameters. For Get request it will append as query string. The type must be NSDictionary as {key: value}.
 @param success Success callback.
 @param failure Failure callback.
 */
- (nullable NSURLSessionDataTask *)GET:(nonnull NSString *)URLString hostVersion:(SHHostVersion)hostVersion parameters:(nullable NSDictionary *)parameters success:(nullable void (^)(NSURLSessionDataTask * _Nullable task, id _Nullable responseObject))success failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSError * _Nullable error))failure;

/**
 Wrapper for `SHAFHTTPSessionManager` POST method for post json.
 @param URLString The path or complete url.
 @param hostVersion StreetHawk's request has version /v1, /v2 etc.
 @param body It will go to post body, and this body will be posted as content-type=application/x-www-form-urlencoded. The type must be NSDictionary as {key: value}. If it's not NSDictionary, for example a string, use {SH_BODY: <value>}.
 @param success Success callback.
 @param failure Failure callback.
 */
- (nullable NSURLSessionDataTask *)POST:(nonnull NSString *)URLString hostVersion:(SHHostVersion)hostVersion body:(nullable NSDictionary *)body success:(nullable void (^)(NSURLSessionDataTask * _Nullable task, id _Nullable responseObject))success failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSError * _Nullable error))failure;

/**
 Wrapper for `SHAFHTTPSessionManager` POST method for uploading multiple form.
 @param URLString The path or complete url.
 @param hostVersion StreetHawk's request has version /v1, /v2 etc.
 @param block It will go to post body, and this body will be posted as content-type=multipart/form-data.
 @param success Success callback.
 @param failure Failure callback.
 */
- (nullable NSURLSessionDataTask *)POST:(nonnull NSString *)URLString hostVersion:(SHHostVersion)hostVersion constructingBodyWithBlock:(nullable void (^)(id <SHAFMultipartFormData> _Nullable formData))block success:(nullable void (^)(NSURLSessionDataTask * _Nullable task, id _Nullable responseObject))success failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSError * _Nullable error))failure;

@end


