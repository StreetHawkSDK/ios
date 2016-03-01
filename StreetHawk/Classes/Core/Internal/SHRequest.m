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

//Json return type: {code: 0, value: ...}, 0 for successful, other for fail.
#define CODE_OK     0
#define CODE_Fail   -1

//Change this in build time to turn on/off request log, helpful for debug.
#define LOG_REQUESTS    NO

#import "SHRequest.h"
//header from StreetHawk
#import "SHTypes.h" //for SHErrorDomain
#import "SHApp.h" //for `StreetHawk` properties
#import "SHInstall.h" //for `StreetHawk.currentInstall.suid`
#import "SHAppStatus.h" //for alive host
#import "SHUtils.h" //for shAppendParamsArrayToString

@interface SHRequest()
{
    dispatch_semaphore_t flagsSemaphore;
}

//request and connection used to send HTTP communication.
@property (nonatomic, strong) NSURLRequest *request;
@property (nonatomic, strong) NSURLConnection *connection;

//internal used flag to know this connection's invokeHandlerAndRelease has been called. If it's already been invoked, no need to invoke again, as notify will notice all listeners.
@property (nonatomic) BOOL handlerInvoked;
//if request not in main thread, will start run loop. If run loop is hold, cannot call request finish handler until run loop done.
@property (nonatomic) BOOL runLoopRunning;
//The status of current operator. It will called by NSOperator return status.
@property (nonatomic) BOOL isRequestExecuting;
@property (nonatomic) BOOL isRequestFinished;
@property (nonatomic) BOOL isRequestCancelled;

//Time to do performance trace
@property (nonatomic) NSTimeInterval timeAddIntoQueue;
@property (nonatomic) NSTimeInterval timeStartExecute;
@property (nonatomic) NSTimeInterval timeEndExecute;

//header files declare them as readonly, make a read-write property as private
@property (nonatomic, strong) NSURLResponse *innerResponse;
@property (nonatomic) NSInteger responseStatusCode;
@property (nonatomic, strong) NSMutableData *innerResponseData;
@property (nonatomic, strong) NSError *innerError;
@property (nonatomic) int resultCode;
@property (nonatomic, strong) NSObject *innerResultValue;

//Initiates a StreetHawk with a url request and request handler.
+ (NSURLRequest *)urlRequestWithPath:(NSString *)path withVersion:(SHHostVersion)hostVersion withParams:(NSArray *)params withMethod:(NSString *)method withHeaders:(NSDictionary *)headers withBodyOrStream:(id)body_or_stream;
- (SHRequest *)initWithRequest:(NSURLRequest *)request;
//The Default queue for request to be handled. If `startAsynchronouslyInQueue:` set `queue`=nil, or call `startAsynchronously`, this queue is used. It's concurrent with max number 3.
+ (NSOperationQueue *)defaultOperationQueue;
//Fixed StreetHawk request header.
+ (NSDictionary *)requestHeader;
//Make isRequestExecuting=NO, isRequestFinished=YES, and set KOV values.
- (void)markAsFinished;
//Mark status to be finished, call requestHandler and release self.
- (void)invokeHandlerAndRelease;
//Create the resultCode, resultValue and error objects. It happens in `connectionDidFinishLoading:`, at this moment the responseData is fully downloaded. Use self.jsonToObjectConverter(self.responseData, &err) can get NSDictionary of {"code"=0, "value"=...}.
-(void)parseResponseForConnection:(NSURLConnection *)theConnection withContentType:(NSString *)contentType;

@end

@implementation SHRequest

#pragma mark - static singleton

+ (NSOperationQueue *)defaultOperationQueue
{
    static NSOperationQueue *sharedQueue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedQueue = [[NSOperationQueue alloc] init];
        sharedQueue.maxConcurrentOperationCount = 3;
        sharedQueue.name = @"SHRequestQueue";
    });
    return sharedQueue;
}

+ (NSError *)requestCancelledError
{
    static NSError *error = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        error = [[NSError alloc] initWithDomain:SHErrorDomain code:INT_MIN userInfo:@{NSLocalizedDescriptionKey: @"Request cancelled by user"}];
    });
    return error;
}

+ (NSDictionary *)requestHeader
{
    static NSMutableDictionary *dictHeader = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        dictHeader = [[NSMutableDictionary alloc] init];
        [dictHeader setObject:[NSString stringWithFormat:@"%@(%@)", StreetHawk.appKey, StreetHawk.version] forKey:@"User-Agent"]; //e.g: "SHSample(1.5.3)"
        [dictHeader setObject:NONULL(StreetHawk.appKey) forKey:@"X-App-Key"];
        [dictHeader setObject:StreetHawk.version forKey:@"X-Version"];
    });
    [dictHeader setObject:StreetHawk.currentInstall.suid != nil ? StreetHawk.currentInstall.suid : @"null" forKey:@"X-Installid"]; //move out of singleton, otherwise first launch not reset again.
    return dictHeader;
}

#pragma mark - life cycle

- (SHRequest *)initWithRequest:(NSURLRequest *)request
{
    if ((self = [super init]))
    {
        self.request = request;
        self.handlerInvoked = NO;
        self.runLoopRunning = NO; //default not use run loop
        self.responseStatusCode = 0;
        self.innerResponseData = [NSMutableData data];
        self.resultCode = CODE_OK;
        flagsSemaphore = dispatch_semaphore_create(1);
        //clear newly created request's status
        self.isRequestExecuting = NO;
        self.isRequestFinished = NO;
        self.isRequestCancelled = NO;
    }
    return self;
}

+ (NSURLRequest *)urlRequestWithPath:(NSString *)path withVersion:(SHHostVersion)hostVersion withParams:(NSArray *)params withMethod:(NSString *)method withHeaders:(NSDictionary *)headers withBodyOrStream:(id)body_or_stream
{
    NSMutableString *completeUrl = [NSMutableString string];
    if (path != nil && ([path.lowercaseString hasPrefix:@"http://"] || [path.lowercaseString hasPrefix:@"https://"]))
    {
        [completeUrl appendString:path];
    }
    else
    {
        //base url
        NSString *hostUrl = [[SHAppStatus sharedInstance] aliveHostForVersion:hostVersion];
        NSAssert(hostUrl != nil && hostUrl.length > 0, @"No host base URL.");
        [completeUrl appendString:hostUrl];
        //adding path
        if (path != nil && path.length > 0)
        {
            if ([completeUrl hasSuffix:@"/"])
            {
                [completeUrl deleteCharactersInRange:NSMakeRange(completeUrl.length-1, 1)]; //remove last "/"
            }
            if ([path characterAtIndex:0] == '/')
            {
                path = [path substringFromIndex:1];  //remove first "/"
            }
            if ([path hasSuffix:@"/"])  //remove last "/", recent change in StreetHawk server requires NOT have "/" at path end.
            {
                path = [path substringToIndex:path.length - 1];
            }
            [completeUrl appendFormat:@"/%@", path];
        }
    }
    //Every api.streethawk.com request, no matter GET or POST, should include "installid" in the request. Add it no matter GET or POST in params.
    BOOL needAddInstallId = [completeUrl.lowercaseString hasPrefix:@"https://api.streethawk.com"] && !shStrIsEmpty(StreetHawk.currentInstall.suid);
    NSMutableArray *refinedParams = [NSMutableArray arrayWithArray:params];
    if (needAddInstallId && ![params containsObject:@"installid"])
    {
        [refinedParams addObject:@"installid"];
        [refinedParams addObject:StreetHawk.currentInstall.suid];
    }
    shAppendParamsArrayToString(completeUrl, refinedParams, NO);
    //method
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:completeUrl]];
    request.HTTPShouldHandleCookies = NO;
    if (method == nil || ([method compare:@"GET" options:NSCaseInsensitiveSearch] != NSOrderedSame && [method compare:@"POST" options:NSCaseInsensitiveSearch] != NSOrderedSame))
    {
        method = @"GET";
    }
    [request setHTTPMethod:method];
    //header, both from customer and from fixed StreetHawk request fields. it should be setup before body.
    if (headers)
    {
        [request setAllHTTPHeaderFields:headers];
    }
    [[SHRequest requestHeader] enumerateKeysAndObjectsUsingBlock:^(id header, id value, BOOL *stop)
     {
         if (![headers.allKeys containsObject:header])
         {
             [request setValue:value forHTTPHeaderField:header];
         }
     }];
    //body
    if (body_or_stream)
    {
        if ([body_or_stream isKindOfClass:[NSArray class]])
        {
            if (![request.allHTTPHeaderFields.allKeys containsObject:@"Content-Type"])
            {
                [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
            }
            NSMutableArray *body_fields = [NSMutableArray arrayWithArray:(NSArray *)body_or_stream];
            if (needAddInstallId && ![body_fields containsObject:@"installid"])
            {
                [body_fields addObject:@"installid"];
                [body_fields addObject:StreetHawk.currentInstall.suid];
            }
            NSMutableString *form_string = [NSMutableString stringWithCapacity:64];
            shAppendParamsArrayToString(form_string, body_fields, YES);
            [request setHTTPBody:[form_string dataUsingEncoding:NSUTF8StringEncoding]];
        }
        else if ([body_or_stream isKindOfClass:[NSDictionary class]])
        {
            if (![request.allHTTPHeaderFields.allKeys containsObject:@"Content-Type"])
            {
                [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
            }
            NSMutableDictionary *body_fields = [NSMutableDictionary dictionaryWithDictionary:(NSDictionary *)body_or_stream];
            if (needAddInstallId && ![body_fields.allKeys containsObject:@"installid"])
            {
                body_fields[@"installid"] = StreetHawk.currentInstall.suid;
            }
            NSMutableString *form_string = [NSMutableString stringWithCapacity:64];
            shAppendParamsDictToString(form_string, body_fields, YES);
            [request setHTTPBody:[form_string dataUsingEncoding:NSUTF8StringEncoding]];
        }
        else if ([body_or_stream isKindOfClass:[NSData class]])
        {
            if (![request.allHTTPHeaderFields.allKeys containsObject:@"Content-Type"])
            {
                [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
            }
            [request setHTTPBody:(NSData *)body_or_stream];
        }
        else if ([body_or_stream isKindOfClass:[NSString class]])
        {
            if (![request.allHTTPHeaderFields.allKeys containsObject:@"Content-Type"])
            {
                [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
            }
            [request setHTTPBody:[body_or_stream dataUsingEncoding:NSUTF8StringEncoding]];
        }
        else
        {
            NSAssert(NO, @"Should not reach here for post body: %@.", body_or_stream);
            if (![request.allHTTPHeaderFields.allKeys containsObject:@"Content-Type"])
            {
                [request setValue:@"multipart/form-data" forHTTPHeaderField:@"Content-Type"];
            }
            [request setHTTPBodyStream:(NSInputStream *)body_or_stream];
        }
    }
    //Background fetch must be finished in 30 seconds, however when testing found `[UIApplication sharedApplication].backgroundTimeRemaining` sometimes is more than 30 seconds, for example if just enter background it's 180 seconds, if start background task it's 10 minutes. Thus cannot depend on `[UIApplication sharedApplication].backgroundTimeRemaining` to calculate timeout.
    //To be safe and simple, if in background, timeout is 13 seconds(sometimes heartbeat follow by location update), if in foreground, timeout is 60 seconds.
    [request setTimeoutInterval:([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) ? 13 : 60];
    SHLog(@"%@ - %@", method, completeUrl);
    return request;
}

+ (SHRequest *)requestWithPath:(NSString *)path withVersion:(SHHostVersion)hostVersion withParams:(NSArray *)params withMethod:(NSString *)method withHeaders:(NSDictionary *)headers withBodyOrStream:(id)body_or_stream
{
    if (path != nil)
    {
        NSURLRequest *req = [SHRequest urlRequestWithPath:path withVersion:hostVersion withParams:params withMethod:method withHeaders:headers withBodyOrStream:body_or_stream];
        SHRequest *request = [[SHRequest alloc] initWithRequest:req];
        return request;
    }
    return nil;
}

+ (SHRequest *)requestWithPath:(NSString *)path withParams:(NSArray *)params withMethod:(NSString *)method
{
    return [self requestWithPath:path withVersion:SHHostVersion_V1 withParams:params withMethod:method withHeaders:nil withBodyOrStream:nil];
}

+ (SHRequest *)requestWithPath:(NSString *)path withParams:(NSArray *)params
{
    return [self requestWithPath:path withVersion:SHHostVersion_V1 withParams:params withMethod:nil withHeaders:nil withBodyOrStream:nil];
}

+ (SHRequest *)requestWithPath:(NSString *)path
{
    return [self requestWithPath:path withVersion:SHHostVersion_V1 withParams:nil withMethod:nil withHeaders:nil withBodyOrStream:nil];
}

- (void)dealloc
{
    flagsSemaphore = 0;
}

#pragma mark - start/cancel functions

- (void)startAsynchronously
{
    self.timeAddIntoQueue = [NSDate timeIntervalSinceReferenceDate];
    if (LOG_REQUESTS)
    {
        SHLog(@"Request (%@) add into operation queue: %@", self, self.request.URL);
    }
    [[SHRequest defaultOperationQueue] addOperation:self];  //it's added into queue, but not start until queue start it. The start function is called by queue.
}

- (NSData *)startSynchronously
{
    NSAssert(self.requestHandler == nil, @"Request handler does not work in synchronous mode.");
    self.isRequestExecuting = YES;
    //synchronous request not use self.connection and make self as delegate.
    self.connection = nil;
    //directly send connection request, and finish in this method. 
    NSURLResponse *response_ = nil;
    NSError *error_ = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:self.request returningResponse:&response_ error:&error_];
    self.innerResponse = response_;
    self.innerError = error_;
    self.innerResponseData = [NSMutableData dataWithData:data];
    [self invokeHandlerAndRelease];
    return data;
}

#pragma mark - override NSOperation functions

//called by NSOperationQueue to start the operation inside it. 
- (void)start
{   
    if (!self.isRequestCancelled && !self.isRequestExecuting) //only start if neither executing nor cancelled
    {
        [self willChangeValueForKey:@"isExecuting"];
        self.isRequestExecuting = YES;
        [self didChangeValueForKey:@"isExecuting"];
        self.timeStartExecute = [NSDate timeIntervalSinceReferenceDate];
        if (LOG_REQUESTS)
        {
            SHLog(@"Request (%@) started (after %0.6fs): %@", self, (self.timeStartExecute-self.timeAddIntoQueue), self.request.URL);
        }
        self.connection = [[NSURLConnection alloc] initWithRequest:self.request delegate:self];
        [self.connection start];
    }
    //If this request is not running in main thread, keep its run loop until it's finished. Otherwise the run loop disappear and it cannot run successfully.
    if (![NSThread isMainThread])
    {
        while(!self.isRequestFinished)
        {
            //Run loop response slow, even set timeout 0.001 still crash. To make sure request handler not called (causing fetch completion handler end) when run loop not finished, add this flag. By testing if use run loop request handler are mostly called from here.
            self.runLoopRunning = YES;
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
            self.runLoopRunning = NO;
            if (self.isRequestFinished && self.requestHandler)
            {
                self.requestHandler(self);
                self.requestHandler = nil;
            }
        }
    }
}

//Asynchronous request is concurrent, as operation queue max concurrent number = 3. Synchronous request not need this override.
- (BOOL)isConcurrent
{
    return YES;
}

- (BOOL)isCancelled
{
    return self.isRequestCancelled;
}

- (BOOL)isExecuting
{
    return self.isRequestExecuting;
}

- (BOOL)isFinished
{
    return self.isRequestFinished;
}

- (void)markAsFinished
{
    [self willChangeValueForKey:@"isExecuting"];
    self.isRequestExecuting = NO;
    [self didChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    self.isRequestFinished = YES;
    [self didChangeValueForKey:@"isFinished"];
}

#pragma mark - result

- (NSURLResponse *)response
{
    return self.innerResponse;
}

- (NSData *)responseData
{
    return self.innerResponseData;
}

- (NSString *)responseString
{
    if (self.responseData != nil)
        return [[NSString alloc] initWithData:self.responseData encoding:NSUTF8StringEncoding];
    else
        return @"";
}

- (NSError *)error
{
    return self.innerError;
}

- (NSObject *)resultValue
{
    return self.innerResultValue;
}

#pragma mark - UIConnection delegate handlers

//Mark status to be finished, call requestHandler and release self.
- (void)invokeHandlerAndRelease
{
    [self markAsFinished];
    NSAssert(![NSThread isMainThread], @"invokeHandlerAndRelease wait in main thread for request %@.", self);
    dispatch_semaphore_wait(flagsSemaphore, DISPATCH_TIME_FOREVER);
    if (self.handlerInvoked)
    {
        dispatch_semaphore_signal(flagsSemaphore);
        return;
    }
    else
    {
        self.handlerInvoked = YES;
        dispatch_semaphore_signal(flagsSemaphore);
    }
    self.timeEndExecute = [NSDate timeIntervalSinceReferenceDate];
    if (LOG_REQUESTS)
    {
        SHLog(@"Request (%@) completed in %0.6fs: %@", self, (self.timeEndExecute-self.timeStartExecute), self.request.URL);
    }
    //handle result, such as error
    if (self.error == nil && (self.resultCode != CODE_OK || self.responseStatusCode >= 300/*2XX is OK, above is wrong*/))
    {
        //If resultCode != 0 it means error too. The error message contains in resultValue but need to parse it.
        NSObject *errorDescription = self.resultValue.description;
        NSInteger errorCode = INT_MIN;
        if (self.responseStatusCode >= 300)
        {
            errorCode = self.responseStatusCode;
            errorDescription = [NSString stringWithFormat:@"Server returned %ld: %@", (long)self.responseStatusCode, errorDescription];
        }
        self.innerError = [NSError errorWithDomain:SHErrorDomain code:errorCode userInfo:@{NSLocalizedDescriptionKey: errorDescription}];
    }
    if (self.error == nil && self.isRequestCancelled)
    {
        self.innerError = [SHRequest requestCancelledError];
    }
    //Show error on console when debug
    if (self.error != nil && self.error != [SHRequest requestCancelledError] && StreetHawk.isDebugMode && shAppMode() != SHAppMode_AppStore && shAppMode() != SHAppMode_Enterprise)
    {
        NSString *url = self.request.URL.absoluteString;
        NSString *method = self.request.HTTPMethod;
        NSString *comment = [NSString stringWithFormat:@"Status(%ld) %@ - %@. Error: %@.", (long)self.responseStatusCode, method, url, self.error];
        if (method != nil && [method compare:@"POST" options:NSCaseInsensitiveSearch] == NSOrderedSame)
        {
            NSString *postStr = [[[NSString alloc] initWithData:self.request.HTTPBody encoding:NSUTF8StringEncoding] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            comment = [comment stringByAppendingFormat:@"\nPost body: %@.", postStr];
        }
        SHLog(@"Add breakpoint here to know error request happen for %@.", comment);
    }
    //finish handling, move this to end as it may trigger background fetch's completion handler, make sure nothing execute after this.
    if (self.requestHandler && !self.runLoopRunning/*mostly used when request in main thread and not need run loop*/)
    {
        self.requestHandler(self);
        self.requestHandler = nil;
    }
}

- (void)connection:(NSURLConnection *)connection_ didFailWithError:(NSError *)error_
{
    if (!self.isRequestCancelled)  //cancel function has invokeHandlerAndRelease, here error and response can be ignored.
    {
        self.innerError = error_;
        self.innerResponseData = nil;
        self.innerResultValue = nil;
        [self invokeHandlerAndRelease];
    }
}

- (void)connection:(NSURLConnection *)connection_ didReceiveResponse:(NSURLResponse *)response_
{
    if (!self.isRequestCancelled)
    {
        self.innerResponse = response_;
        self.responseStatusCode = ((NSHTTPURLResponse *)self.response).statusCode;
        //https://bitbucket.org/shawk/streethawk/issue/230/make-sure-handling-other-status-codes-than
        if (self.responseStatusCode / 100 == 2)  // 2XX status codes are ok
        {
            //introduce a fake delay for testing
            if (StreetHawk.isDebugMode && shAppMode() != SHAppMode_AppStore && shAppMode() != SHAppMode_Enterprise)
            {
                NSObject *delayValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"SHRequest_Delay"];
                if (delayValue != nil && [delayValue isKindOfClass:[NSNumber class]])
                {
                    int delaySeconds = [(NSNumber *)delayValue intValue];
                    if (delaySeconds > 0)
                    {
                        sleep(delaySeconds);
                        NSLog(@"Request delay %d seconds.", delaySeconds);
                    }
                }
            }
        }
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    if (!self.isRequestCancelled)
    {
        [self.innerResponseData appendData:data];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection_
{
    if (!self.isRequestCancelled)
    {
        NSString *contentType = [((NSHTTPURLResponse *)self.response) allHeaderFields][@"Content-Type"];
        [self parseResponseForConnection:connection_ withContentType:contentType];
        [self invokeHandlerAndRelease];
    }
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection_ willCacheResponse:(NSCachedURLResponse *)cachedResponse
{
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)[cachedResponse response];
    // Look up the cache policy used in our request
    if(self.request.cachePolicy == NSURLRequestUseProtocolCachePolicy)
    {
        NSDictionary *headers = [httpResponse allHeaderFields];
        NSString *cacheControl = [headers valueForKey:@"Cache-Control"];
        NSString *expires = [headers valueForKey:@"Expires"];
        if((cacheControl == nil) && (expires == nil))
        {
            return nil; // don't cache this
        }
    }
    return cachedResponse;
}

#pragma mark - parse function

-(void)parseResponseForConnection:(NSURLConnection *)theConnection withContentType:(NSString *)contentType
{
    if (self.responseStatusCode >= 300/*2XX is OK, above is wrong*/) //server change format, if http status code is wrong it will not have "code" and "value".
    {
        self.resultCode = CODE_Fail;
        self.innerResultValue = self.responseString;
    }
    else
    {
        if ([contentType hasPrefix:@"application/json"] ||
            [contentType hasPrefix:@"text/json"])
        {
            NSString *jsonStr = self.responseString;
            NSDictionary *dict = shParseObjectToDict(jsonStr);
            NSAssert(dict != nil && [dict isKindOfClass:[NSDictionary class]], @"Fail to parse response %@.", self.responseString);
            if (dict != nil && [dict isKindOfClass:NSDictionary.class])
            {
                NSObject *code = dict[@"code"];
                NSObject *value = dict[@"value"];
                BOOL hasValidCode = (code != nil && [code isKindOfClass:[NSNumber class]]);
                BOOL hasValidValue = value != nil && (value == (id)[NSNull null] || [value isKindOfClass:[NSArray class]] || [value isKindOfClass:[NSDictionary class]] || [value isKindOfClass:[NSString class]]/*when fail value is error message*/ || [value isKindOfClass:[NSNumber class]]/*when invite friend, return task id*/);
                if ([theConnection.currentRequest.URL.absoluteString hasPrefix:@"https://api.streethawk.com"])
                {
                    //only force check this format for StreetHawk server, customer may use it to do other request.
                    NSAssert(hasValidCode, @"Wrong format to get resultCode. Dict: %@", dict);
                    NSAssert(hasValidValue, @"Wrong format to get resultValue. Dict: %@", dict);
                }
                hasValidValue = YES; //disable "Unused variable" due to NSAssert ignored in pods.
                if (hasValidCode)
                {
                    self.resultCode =  [(NSNumber *)code intValue];
                }
                if (value)
                {
                    self.innerResultValue = value;
                }
                //response may have "app_status" section, but it's not guranteed to have all keys, or even have this section.
                NSDictionary *dictStatus = nil;
                if ([dict.allKeys containsObject:@"app_status"] && [dict[@"app_status"] isKindOfClass:[NSDictionary class]])
                {
                    dictStatus = (NSDictionary *)dict[@"app_status"]; //Most request use "app_status" because they have installid
                }
                else if ([theConnection.currentRequest.URL.absoluteString rangeOfString:@"apps/status"].location != NSNotFound && [self.innerResultValue isKindOfClass:[NSDictionary class]]) //First not have installid, Tobias return by value, must do it in else
                {
                    dictStatus = (NSDictionary *)self.innerResultValue;
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
        else if ([contentType hasPrefix:@"text/plain"])
        {
            //For example https://api.streethawk.com/v1/core/library?operating_system=ios just return 1/1.3.2, without any {code:0, value:...}
            self.resultCode = CODE_OK;
            self.innerResultValue = self.responseString;
        }
    }
}

@end
