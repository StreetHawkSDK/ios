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

#import "SHObject.h"
//header from StreetHawk
#import "SHHTTPSessionManager.h" //for sending request save and load

@interface SHObject()

@end

@implementation SHObject

#pragma mark - Creator

-(id)init
{
    NSAssert(NO, @"SHObject without suid should never be called.");
    return nil;
}

- (id)initWithSuid:(NSString *)suid
{
    NSAssert(suid != nil && [suid isKindOfClass:[NSString class]] && suid.length > 0, @"suid is mandatory unique primary key.");
    if (self = [super init])
    {
        self.suid = suid;
    }
    return self;
}


//Overridden to show more info about the object.
- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p> - suid: %@", [self class], self, self.suid];
}

#pragma mark - Communicate With Server

- (NSString *)serverLoadURL
{
    NSAssert(NO, @"serverLoadURL for %@ is not yet implemented.", self.class);
    return nil;
}

- (void)loadFromDictionary:(NSDictionary *)dict
{
    NSAssert(NO, @"loadFromDictionary for %@ is not yet implemented.", self.class);
}

- (void)loadFromServer:(SHCallbackHandler)load_handler
{
    NSString *url = [self serverLoadURL];
    NSAssert(url != nil && [url isKindOfClass:[NSString class]] && url.length > 0, @"Fail to get server load url.");
    if (url == nil || ![url isKindOfClass:[NSString class]] || url.length == 0)
    {
        if (load_handler)
        {
            load_handler(nil, [NSError errorWithDomain:SHErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Fail to get server load url: %@.", url]}]);
        }
        return;
    }
    load_handler = [load_handler copy];
    [[SHHTTPSessionManager sharedInstance] GET:url hostVersion:SHHostVersion_V1 parameters:nil success:^(NSURLSessionDataTask * _Nullable task, id  _Nullable responseObject)
    {
        NSError *error = nil;
        NSAssert(responseObject != nil && [responseObject isKindOfClass:[NSDictionary class]], @"Load from server get wrong result value: %@.", responseObject);  //load request suppose to get json dictionary
        if (responseObject != nil && [responseObject isKindOfClass:[NSDictionary class]])
        {
            [self loadFromDictionary:(NSDictionary *)responseObject];
        }
        else
        {
            error = [NSError errorWithDomain:SHErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Load from server get wrong result value: %@.", responseObject]}];
        }
        if (load_handler)
        {
            load_handler(self, error);
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nullable error)
    {
        if (load_handler)
        {
            load_handler(self, error);
        }
    }];
}

- (NSString *)serverSaveURL
{
    NSAssert(NO, @"serverSaveURL for %@ is not yet implemented.", self.class);
    return nil;
}

- (NSDictionary *)saveBody
{
    NSAssert(NO, @"saveBody for %@ is not yet implemented.", self.class);
    return nil;
}

- (void)saveToServer:(SHCallbackHandler)save_handler
{
    NSString *url = [self serverSaveURL];
    NSAssert(url != nil && [url isKindOfClass:[NSString class]] && url.length > 0, @"Fail to get server save url.");
    if (url == nil || ![url isKindOfClass:[NSString class]] || url.length == 0)
    {
        if (save_handler)
        {
            save_handler(nil, [NSError errorWithDomain:SHErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Fail to get server save url: %@.", url]}]);
        }
        return;
    }
    NSDictionary *body = [self saveBody];
    NSAssert(body != nil, @"Fail to get server save body.");
    if (body == nil)
    {
        if (save_handler)
        {
            save_handler(nil, [NSError errorWithDomain:SHErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Fail to get server save body: %@.", body]}]);
        }
        return;
    }
    save_handler = [save_handler copy];
    [[SHHTTPSessionManager sharedInstance] POST:url hostVersion:SHHostVersion_V1 body:body success:^(NSURLSessionDataTask * _Nullable task, id  _Nullable responseObject)
    {
        NSError *error = nil;
        NSAssert(responseObject != nil && [responseObject isKindOfClass:[NSDictionary class]], @"Save to server get wrong result value: %@.", responseObject);  //save request suppose to get json dictionary
        if (responseObject != nil && [responseObject isKindOfClass:[NSDictionary class]]) //After save server may return complete dictionary, so no need to request detail again, just load from server's return.
        {
            [self loadFromDictionary:(NSDictionary *)responseObject];
        }
        else
        {
            error = [NSError errorWithDomain:SHErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Save to server get wrong result value: %@.", responseObject]}];
        }
        if (save_handler)
        {
            save_handler(self, error);
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nullable error)
    {
        if (save_handler)
        {
            save_handler(self, error);
        }
    }];
}

@end
