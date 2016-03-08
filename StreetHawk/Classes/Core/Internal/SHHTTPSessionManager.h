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
#import "AFHTTPSessionManager.h"

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

/**
 All http requests used to communicate with server uses this class.
 */
@interface SHHTTPSessionManager : AFHTTPSessionManager

/** @name Creator */

/**
 Singleton instance. Caller normally only needs to use [SHHTTPSessionManager sharedInstance], which configures connection session to server.
 */
+ (nonnull SHHTTPSessionManager *)sharedInstance;

/**
 Wrapper for `AFHTTPSessionManager` Get method.
 @param URLString The path or complete url.
 @param hostVersion StreetHawk's request has version /v1, /v2 etc. 
 @param parameters Request parameters.
 @param success Success callback.
 @param failure Failure callback.
 */
- (nullable NSURLSessionDataTask *)GET:(nonnull NSString *)URLString hostVersion:(SHHostVersion)hostVersion parameters:(nullable NSDictionary *)parameters success:(nullable void (^)(NSURLSessionDataTask * _Nullable task, id _Nullable responseObject))success failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSError * _Nullable error))failure;

/**
 Wrapper for `AFHTTPSessionManager` POST method.
 @param URLString The path or complete url.
 @param hostVersion StreetHawk's request has version /v1, /v2 etc.
 @param parameters Request parameters.
 @param success Success callback.
 @param failure Failure callback.
 */
- (nullable NSURLSessionDataTask *)POST:(nonnull NSString *)URLString hostVersion:(SHHostVersion)hostVersion parameters:(nullable NSDictionary *)parameters success:(nullable void (^)(NSURLSessionDataTask * _Nullable task, id _Nullable responseObject))success failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSError * _Nullable error))failure;

@end


