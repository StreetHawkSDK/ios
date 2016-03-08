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

@class SHRequest;

/**
 Callback when a request process done. 
 @param request The request object contains process result, for example error or resultValue.
 */
typedef void (^SHRequestHandler)(SHRequest *request);

#define SMART_PUSH_PAYLOAD  @"SMART_PUSH_PAYLOAD"

/**
 All http requests used to communicate with server uses this class. It's a wrapper of NSURLConnection and easier to use by block callback.
 */
@interface SHRequest : NSOperation

/** @name Create */

/**
 Helper method to create a request object.
 @param path The internal path after root url, for example: "products/product_id/description/".
 @param hostVersion The version of current host.
 @param params A key/value pair, which will format to paramters in URL, for example (@"family", @"tops") will become "?family=tops".
 @param method GET or POST. If pass nil it's GET by default.
 @param headers The header fields sent in request. Pass nil if no header need to set.
 @param body_or_stream Set to post body. It's usually array, dictionary or data.
 @return An auto-released request.
 */
+ (SHRequest *)requestWithPath:(NSString *)path withVersion:(SHHostVersion)hostVersion withParams:(NSArray *)params withMethod:(NSString *)method withHeaders:(NSDictionary *)headers withBodyOrStream:(id)body_or_stream;

/**
 Helper method to create a simple request object.
 @param path The internal path after root url, for example: "products/product_id/description/".
 @param params A key/value pair, which will format to paramters in URL, for example (@"family", @"tops") will become "?family=tops".
 @param method GET or POST. If pass nil it's GET by default.
 @return An auto-released request.
 */
+ (SHRequest *)requestWithPath:(NSString *)path withParams:(NSArray *)params withMethod:(NSString *)method;

/**
 Helper method to create a simple request object for GET methods.
 @param path The internal path after root url, for example: "products/product_id/description/".
 @param params A key/value pair, which will format to paramters in URL, for example (@"family", @"tops") will become "?family=tops".
 @return An auto-released request.
 */
+ (SHRequest *)requestWithPath:(NSString *)path withParams:(NSArray *)params;

/**
 Helper method to create a simple GET request object.
 @param path The internal path after root url, for example: "products/product_id/description/".
 @return An auto-released request.
 */
+ (SHRequest *)requestWithPath:(NSString *)path;

/**
 The request handler for caller to deal with returned value.
 */
@property (nonatomic, copy) SHRequestHandler requestHandler;

/** @name Start/Cancel functions */

/**
 Add request into operation queue. It will stay in the queue and start when ready to execute it, or caller to cancel it. Once it's finished or cancelled it's auto released. The result is callback by `requestHandler`.
 */
- (void)startAsynchronously;

/**
 Starts the request synchronously. When the request finish, it's dealloc. To start a request asynchronously, use the startAsynchronously method.
 @return The returned NSData value from the request. 
 */
- (NSData *)startSynchronously;

/**
 Cancel the connection and dealloc it. Only asynchronous request can be cancelled. `requestHandler` is invoked with error=`requestCancelledError`. 
 Note: Once a request is cancelled or finished, it cannot be added into queue again, otherwise exception occur.
 */
-(void)cancel;

/** @name Result */

/**
 The response of this request. 
 */
@property (nonatomic, readonly, weak) NSURLResponse *response;

/**
 The HTTP stauts code of response, for example 200 means OK, 404 means page not found.
 */
@property (nonatomic, readonly) NSInteger responseStatusCode;

/**
 The data of received response data. It's appended when connection didReceiveData.
 */
@property (nonatomic, readonly, weak) NSData *responseData;

/**
 The NSUTF8StringEncoding string of received response data (`responseData`).
 */
@property (nonatomic, readonly, weak) NSString *responseString;

/**
 The error of handling this request. 
 */
@property (nonatomic, readonly, weak) NSError *error;

/**
 Static function to get cancel request error.
 */
+ (NSError *)requestCancelledError;

/**
 The JSON returned from server is formatted as {"code"=0, "value"=...}. `resultCode` is the part of "code". It can only be got after successfully parse the JSON.
 */
@property (nonatomic, readonly) int resultCode;

/**
 The JSON returned from server is formatted as {"code"=0, "value"=...}. `resultValue` is the part of "value". It can only be got after successfully parse the JSON.
 */
@property (nonatomic, readonly, weak) NSObject *resultValue;

@end

