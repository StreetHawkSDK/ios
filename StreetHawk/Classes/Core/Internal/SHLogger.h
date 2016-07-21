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

//common code
#define LOG_CODE_ERROR               -1
#define LOG_CODE_TIMEOFFSET          8050
#define LOG_CODE_HEARTBEAT           8051
#define LOG_CODE_CLIENTUPGRADE       8052

//app session code
#define LOG_CODE_APP_LAUNCH       8102 //not priority, send when App launch, both for first time (8101 is removed) and next.
#define LOG_CODE_APP_VISIBLE      8103 //priority, when App come to visible, including: manual launch, from BG to FG, unlock screen. Not include launch by BG location and stay BG, interrupt by phone.
#define LOG_CODE_APP_INVISIBLE    8104 //priority, when App come to invisible, including: from FG to BG, lock screen. Every 8103 should follow 8104 unless crash when visible.
#define LOG_CODE_APP_COMPLETE     8105

//view controller enter/exit
#define LOG_CODE_VIEW_ENTER          8108
#define LOG_CODE_VIEW_EXIT           8109
#define LOG_CODE_VIEW_COMPLETE       8110

//location
#define LOG_CODE_LOCATION_MORE       19
#define LOG_CODE_LOCATION_GEO        20
#define LOG_CODE_LOCATION_IBEACON    21
#define LOG_CODE_LOCATION_GEOFENCE   22
#define LOG_CODE_LOCATION_DENIED     8112

//feed
#define LOG_CODE_FEED_ACK           8200
#define LOG_CODE_FEED_RESULT        8201

//push
#define LOG_CODE_PUSH_ACK           8202
#define LOG_CODE_PUSH_RESULT        8203

//tag
#define LOG_CODE_TAG_INCREMENT      8997
#define LOG_CODE_TAG_DELETE         8998
#define LOG_CODE_TAG_ADD            8999

//remote notification result
#define LOG_RESULT_CANCEL       -1
#define LOG_RESULT_LATER        0
#define LOG_RESULT_ACCEPT       1

/**
 This is responsible for logging App's events and send to server. The events are logged in local database, once they have enough number (LOG_UPLOAD_INTERVAL (50)), they are uploaded to server automatically. Some special events upload local to server immediatly regardless local number. To record an event, the sample code is:
 
 * [StreetHawk sendLogForCode:withComment:]
 */
@interface SHLogger : NSObject

/**
 Static function to get log database file path. This is independent on SHLogger instance so must make it static. It's /Library/StreetHawk/logcache.db, this path can be backup by iTunes.
 @return Path to SQLite database path.
 */
+ (NSString *)databasePath;

/**
 If local SQLite db not exist, or max logid not match history, needs to clear NSUserDefaults such as `INSTALL_SUID_KEY` to treat as a new install.
 @return If refresh current install to be new install return YES; otherwise return NO.
 */
+ (BOOL)checkLogdbForFreshInstall;

/**
 Check if apns mode changed. If changed treat as new install.
 @return If refresh current install to be new install return YES; otherwise return NO.
 */
+ (BOOL)checkSentApnsModeForFreshInstall;

@end

#import "SHApp.h"

/**
 Internal implementation for SHApp (SHLoggerExt).
 */
@interface SHApp (LoggerExtImp)

/**
 Asynchronously log into local database, and follow the rule of SHLogger to upload to server.
 */
-(void)sendLogForCode:(NSInteger)code withComment:(NSString *)comment;

/**
 Asynchronously log into local database, and follow the rule of SHLogger to upload to server. 
 @param handler After finish this operation, trigger handler. 
 
 "finish this operation" means: 
 
   * if only need to save to database according to rule, trigger this handler after save to database.
   * if need to upload to server according to rule, trigger this handler after request finish sending to server.
 */
-(void)sendLogForCode:(NSInteger)code withComment:(NSString *)comment forAssocId:(NSString *)assocId withResult:(NSInteger)result withHandler:(SHCallbackHandler)handler;

/**
 Send log for tagging a user (add or remove). For example, you can send user's birthday as {"key": "sh_date_of_birth", "value": "2012-12-12 11:11:11", "type": "datetime"}.
 @param dict The dictionary contains user profile information. It must in the format of: 1. add tag: {"key": key_string, "value": data_value, "type": type_string} (case sensitive). type_string supports: string, numeric and datetime. data_value follows type. If data_value is a dictionary, use "string" as its type. 2. remove tag: {"key": key_string}.
 
 Code sample for add tag:
 `NSDictionary *dictWhen = [NSDictionary dictionaryWithObjectsAndKeys:@"When", @"key", [NSDate date], @"value", @"datetime", @"type", nil];`
 `NSDictionary *dictAction = [NSDictionary dictionaryWithObjectsAndKeys:@"Action", @"key", isLogin ? @"Login" : @"Logout", @"value", @"string", @"type", nil];`
 `NSDictionary *dictUser = [NSDictionary dictionaryWithObjectsAndKeys:@"User", @"key", NONULL(username), @"value", @"string", @"type", nil];`
 `NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:@"loginButtonClick", @"key", [NSArray arrayWithObjects:dictWhen, dictAction, dictUser, nil], @"value", @"string", @"type", nil];`
 `[StreetHawk sendLogForTag:dict withCode:8999];`
 
 Code sample for remove tag:
 `NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:@"sh_email", @"key", nil];`
 `[StreetHawk sendLogForTag:dict withCode:8998];`
 */
-(void)sendLogForTag:(NSDictionary *)dict withCode:(NSInteger)code;

@end
