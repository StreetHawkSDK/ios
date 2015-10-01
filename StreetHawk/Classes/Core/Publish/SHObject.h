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
#import "SHTypes.h"

/**
 Base class of StreetHawk objects, such as SHInstall, SHAlertSettings. It provides basic properties and common functions. If would like to create a new StreetHawk object, inherit from this base class and do:
 
 * add properties for the object itself.
 * override `serverLoadURL` and `loadFromDictionary:` if the object can be `loadFromServer:`.
 * override `serverSaveURL` and `saveBody` if the object can be `saveToServer:`.
 */
@interface SHObject : NSObject

/** @name Creator */

/**
 Create a SHObject with `suid`, which is unique id of the object in server. `suid` is mandatory for a StreetHawk object, but other properties are not ready when `initWithSuid:`. If would like to get other properties, either there is a dictionary from server so call `loadFromDictionary:`, or request from server by `loadFromServer:`. 
 @param suid Unique primary key match to StreetHawk server. This cannot be empty.
 */
- (id)initWithSuid:(NSString *)suid;

/** @name Properties */

/**
 Unique primary Id.
 */
@property (nonatomic, strong) NSString *suid;

/** @name Communicate With Server */

/**
 The URL that is used to load this object from the server. It's relative path to main host url, and no need to include parameter such as `installid`. A sample for load install details is @"installs/details/".
 */
- (NSString *)serverLoadURL;

/**
 Normally the object is requested from server. Server returns json and parsed to be dictionary, use this method to fill properties from dictionary.
 @param dict Server return json information.
 */
- (void)loadFromDictionary:(NSDictionary *)dict;

/**
 Send a request to StreetHawk server and fill the properties of this object. The process is common, normally child class should not override this function. It does:
 
 1. Send request to StreetHawk server, formatted by `serverLoadURL`.
 2. Get the request's response, process it. If meet error call `load_handler` to return; if not call `loadFromDictionary:` to fill properties and then call `load_handler` to return.
 
 @param loadhandler Asynchronous callback for handling.
 */
- (void)loadFromServer:(SHCallbackHandler)load_handler;

/**
 The URL that is used to post save request to server. It's relative path to main host url, and no need to include paramter such as `installid`. A sample for save install is @"installs/update/".
 */
- (NSString *)serverSaveURL;

/**
 The content post to server for saving this object.
 @param savePostBody The content for posting to server, it can be NSArray, NSDictionary, NSString or NSData.
 */
- (NSObject *)saveBody;

/**
 Send a request to StreetHawk server and post the content of this object to save. The process is common, normally child class should not override this function. It does:
 
 1. Send request to StreetHawk server, formatted by `serverSaveURL`.
 2. Get the request's response, process it. If meet error call `save_handler` to return; if not check whether it returns json, if so call `loadFromDictionary:` to fill properties,  and then call `save_handler` to return.
 */
- (void)saveToServer:(SHCallbackHandler)save_handler;

@end
