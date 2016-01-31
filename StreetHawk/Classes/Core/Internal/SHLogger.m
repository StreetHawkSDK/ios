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

#import "SHLogger.h"
//header from StreetHawk
#import "SHAppStatus.h" //for `uploadLocationChange`
#import "SHApp.h" //for register install
#import "SHUtils.h" //for streetHawkIsEnabled

#define tableName @"table_log" //not change table name, if need upgrade db schema, change to another file.
#define LOG_UPLOAD_INTERVAL 50  //local has this number then upload

#define FGBG_SESSION    @"FGBG_SESSION" //record current session id

#define MAX_LOGID       @"MAX_LOGID" //local SQLite table's log id increase, this field records latest inserted max logid.

enum
{
    LOG_COL_LOGID,
    LOG_COL_SESSIONID,
    LOG_COL_CREATED,
    LOG_COL_STATUS,
    LOG_COL_DOMAIN, //deprecated
    LOG_COL_CODE,
    LOG_COL_COMMENT,
    LOG_COL_LAT, //deprecated
    LOG_COL_LNG, //deprecated
    LOG_COL_MLOC, //deprecated
    LOG_COL_MSGID,
    LOG_COL_PUSHRESULT,
};

#import <sqlite3.h>

@interface SHLogger()
{
    sqlite3 *database;
}

@property (nonatomic) dispatch_queue_t logger_queue;  //queue used for db operation and upload request
@property (nonatomic) dispatch_semaphore_t upload_semaphore;  //a semaphore to control selecting and uploading, make sure it happen in sequence, so that avoid selecting duplicated records which the previous uploading is not finished and database not deleted.
@property (nonatomic) int numLogsWritten;  //current local record number
@property (nonatomic) NSInteger fgbgSession;  //When App start or go to FG, session+1; when App go to BG session ends.

//Log the information into local sqlite database. Normal events are uploaded after enough number. Special events are logged and uploaded immediately. This function has the flexibility, however for convenience [StreetHawk sendLogForCode:withComment:] is recommended.
- (void)logComment:(NSString *)comment atTime:(NSDate *)created forCode:(NSInteger)code forAssocId:(NSInteger)assocId withResult:(NSInteger)result withHandler:(SHCallbackHandler)handler;
//Uploads local sqlite's log records to the server. This is automatically called if system determine needs to upload.
- (void)uploadLogsToServerWithHandler:(SHCallbackHandler)handler;

//Open SQLite file, create it on demand.
- (void)openSqliteDatabase;
//Loads all local database log records from new to old
- (NSMutableArray *)loadLogRecords;
//Makes the actual POST request to the server to record the logs.
- (void)postLogRecords:(NSArray *)logRecords withHandler:(SHCallbackHandler)handler;
//Clear records not send again.
- (void)clearLogRecords:(NSArray *)logRecords;

//As for some reason local App needs to be treated as a fresh new install. This function clear necessary local NSUserDefaults and SQLite so that it starts from beginning. It must perform when App launch and nothing else is done, cannot perform during App running.
+ (void)clearLocalToMakeFreshInstall;

@end

@implementation SHLogger

#pragma mark - life cycle

+ (void)initialize
{
    if ([self class] == [SHLogger class])
    {
        int result = sqlite3_shutdown();
        NSAssert(result == SQLITE_OK, @"Fail to shutdown sqlite, result %d.", result);
        //config sqlite to work with the same connection on multiple threads.
        result = sqlite3_config(SQLITE_CONFIG_SERIALIZED);
        NSAssert(result == SQLITE_OK, @"Unable to set serialized mode for sqlite, result %d.", result);
        result = sqlite3_initialize();
        NSAssert(result == SQLITE_OK, @"Fail to initialize sqlite, result %d.", result);
    }
}

- (id)init
{
    if (self = [super init])
    {
        NSObject *sessionValue = [[NSUserDefaults standardUserDefaults] objectForKey:FGBG_SESSION]; //read history session id
        if (sessionValue != nil && [sessionValue isKindOfClass:[NSNumber class]])
        {
            self.fgbgSession = [(NSNumber *)sessionValue integerValue];
        }
        else
        {
            self.fgbgSession = 0;
        }
        self.logger_queue = dispatch_queue_create("com.streethawk.StreetHawk.logger", NULL); //NULL attribute same as DISPATCH_QUEUE_SERIAL, means this queue is FIFO.
        self.upload_semaphore = dispatch_semaphore_create(1);  //happen in sequence
        database = NULL;
        [self openSqliteDatabase];
    }
    return self;
}

#pragma mark - log and upload functions

- (void)logComment:(NSString *)comment atTime:(NSDate *)created forCode:(NSInteger)code forAssocId:(NSInteger)assocId withResult:(NSInteger)result withHandler:(SHCallbackHandler)handler
{
    if (!streetHawkIsEnabled())
    {
        if (handler)
        {
            handler(nil, nil);
        }
        return;
    }
    
    if ((code == LOG_CODE_LOCATION_GEO || code == LOG_CODE_LOCATION_IBEACON || code == LOG_CODE_LOCATION_GEOFENCE || code == LOG_CODE_LOCATION_MORE) && ![SHAppStatus sharedInstance].uploadLocationChange) //if current App Status requires disable location update
    {
        if (handler)
        {
            handler(nil, nil);
        }
        return;
    }
    
    //check app_status's ignore codes
    NSArray *arrayIgnoreCodes = [[NSUserDefaults standardUserDefaults] objectForKey:@"APPSTATUS_DISABLECODES"];
    BOOL isIgnored = NO;
    for (id ignoreCode in arrayIgnoreCodes)
    {
        if ([[NSString stringWithFormat:@"%@", ignoreCode] integerValue] == code)
        {
            isIgnored = YES;
            break;
        }
    }
    if (isIgnored)
    {
        if (handler)
        {
            handler(nil, nil);
        }
        return;
    }
    
    if (code == LOG_CODE_APP_VISIBLE) //From BG to FG (either launch or resume from BG), is a new session.
    {
        self.fgbgSession++;
        [[NSUserDefaults standardUserDefaults] setInteger:self.fgbgSession forKey:FGBG_SESSION];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    if (code == LOG_CODE_APP_VISIBLE || code == LOG_CODE_APP_INVISIBLE)
    {
        //check previous must be reverse side: if now is "to visible" previous must be "to invisible" or none; if now is "to invisible" previous must be "to visible". Crash is an exception but this assert not happen in release so not affect customer.
        NSInteger previousVisible = 0;
        NSObject *previousVisibleObj = [[NSUserDefaults standardUserDefaults] objectForKey:@"Previous_Visible_Status"];
        if (previousVisibleObj != nil && [previousVisibleObj isKindOfClass:[NSNumber class]])
        {
            previousVisible = [(NSNumber *)previousVisibleObj integerValue];
        }
        if (code == LOG_CODE_APP_VISIBLE)
        {
            [[NSUserDefaults standardUserDefaults] setObject:@([[NSDate date] timeIntervalSinceReferenceDate]) forKey:@"Previous_Visible_Time"];
            //NSAssert(previousVisible == 0 || previousVisible == LOG_CODE_SYSTEM_INVISIBLE, @"App to visible but previous is not none or invisible."); //Not do this as it cause crash when debugging.
        }
        if (code == LOG_CODE_APP_INVISIBLE)
        {
            NSAssert(previousVisible == LOG_CODE_APP_VISIBLE, @"App to invisible but previous is not visible.");
            NSDate *visibleTime = nil;
            NSObject *visibleTimeObj = [[NSUserDefaults standardUserDefaults] objectForKey:@"Previous_Visible_Time"];
            if (visibleTimeObj != nil && [visibleTimeObj isKindOfClass:[NSNumber class]])
            {
                double visibleTimeVal = [(NSNumber *)visibleTimeObj doubleValue];
                if (visibleTimeVal != 0)
                {
                    visibleTime = [NSDate dateWithTimeIntervalSinceReferenceDate:visibleTimeVal];
                }
            }
            NSAssert(visibleTime != nil, @"Not have visible time for this invisible.");
            if (visibleTime != nil)
            {
                NSMutableDictionary *dictAppSession = [NSMutableDictionary dictionary];
                dictAppSession[@"visible"] = shFormatStreetHawkDate(visibleTime);
                dictAppSession[@"invisible"] = shFormatStreetHawkDate([NSDate date]);
                dictAppSession[@"duration"] = @([[NSDate date] timeIntervalSinceDate:visibleTime]);
                [StreetHawk sendLogForCode:LOG_CODE_APP_COMPLETE withComment:shSerializeObjToJson(dictAppSession)];
                [[NSUserDefaults standardUserDefaults] setObject:@(0) forKey:@"Previous_Visible_Time"];
            }
        }
        [[NSUserDefaults standardUserDefaults] setObject:@(code) forKey:@"Previous_Visible_Status"]; //all pass, record this time as previous.
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    handler = [handler copy];
    dispatch_async(self.logger_queue, ^(void)
    {
        //first save to database
        NSString *columns = @"'status', 'sessionid', 'created', 'code', 'comment', 'lat', 'lng', 'mloc', 'msgid', 'pushresult'";
        BOOL isAppBG = ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground);
        //session_id must be set for: install_session, install_view, install_enter_exit_view, install_fg_bg; for other log lines it can be null.
        BOOL requireSession = (code == LOG_CODE_APP_LAUNCH) || (code == LOG_CODE_APP_VISIBLE) || (code == LOG_CODE_APP_INVISIBLE) || (code == LOG_CODE_APP_COMPLETE) || (code == LOG_CODE_VIEW_ENTER) || (code == LOG_CODE_VIEW_EXIT) || (code == LOG_CODE_VIEW_COMPLETE);
        NSInteger session = (isAppBG && !requireSession) ? 0/*App in BG and not forcely require session id, use 0, later change to NULL*/ : (self.fgbgSession > 0 ? self.fgbgSession : 1/*Phonegap first launch "app did finish launch" delay 2 second, make fgbgSession=0, but enter view called and log null for session_id.*/);
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_LMBridge_UpdateGeoLocation" object:nil]; //make value update
        double lat_deprecate = [[[NSUserDefaults standardUserDefaults] objectForKey:SH_GEOLOCATION_LAT] doubleValue];
        double lng_deprecate = [[[NSUserDefaults standardUserDefaults] objectForKey:SH_GEOLOCATION_LNG] doubleValue];
        NSString *values = [NSString stringWithFormat: @"0, %ld, '%@', %ld, '%@', %f, %f, 0, %ld, '%ld'", (long)session, shFormatStreetHawkDate(created), (long)code, [comment stringByReplacingOccurrencesOfString:@"'" withString:@"''"], lat_deprecate, lng_deprecate, (long)assocId, (long)result];
        NSString *sql_str = [NSString stringWithFormat:@"INSERT OR REPLACE INTO '%@' (%@) VALUES (%@)", tableName, columns, values];
        @synchronized(self)
        {
            sqlite3_stmt *insert_sql = NULL;
            int prepare_result = sqlite3_prepare_v2(database, [sql_str UTF8String], -1, &insert_sql, NULL);
            if (prepare_result != SQLITE_OK)
            {
                SHLog(@"Could not prepare sql [[[ %@ ]]], Error: %s", sql_str, sqlite3_errmsg(database));
                assert(NO);
            }
            int step_result = sqlite3_step(insert_sql);
            NSAssert(step_result == SQLITE_DONE, @"Could not perform row insertion: %s", sqlite3_errmsg(database));
            step_result = 0; //disable "Unused variable" due to NSAssert ignored in pods.
            sqlite3_reset(insert_sql);
            sqlite3_finalize(insert_sql);
            insert_sql = NULL;
            int logid = (int)sqlite3_last_insert_rowid(database);
            [[NSUserDefaults standardUserDefaults] setObject:@(logid) forKey:MAX_LOGID];
            [[NSUserDefaults standardUserDefaults] synchronize];
            SHLog(@"LOG (%d @ %@) <%d> %@", logid, shFormatStreetHawkDate(created), code, comment);
        }
        BOOL isForce = NO;
        NSArray *arrayPriorityCodes = [[NSUserDefaults standardUserDefaults] objectForKey:@"APPSTATUS_PRIORITYCODES"];
        if (arrayPriorityCodes == nil) //not set, same as before
        {
            isForce = (code == LOG_CODE_LOCATION_GEO || code == LOG_CODE_LOCATION_IBEACON || code == LOG_CODE_LOCATION_GEOFENCE || code == LOG_CODE_LOCATION_DENIED)  //immediately send for geo and ibeacon location, but not for code 19.
            || (code == LOG_CODE_APP_VISIBLE || code == LOG_CODE_APP_INVISIBLE)  //immediately send for session change
            || (code == LOG_CODE_TAG_INCREMENT || code == LOG_CODE_TAG_DELETE || code == LOG_CODE_TAG_ADD)  //immediately send for add/remove/increment user tag
            || (code == LOG_CODE_TIMEOFFSET)  //immediately send for time utc offset change
            || (code == LOG_CODE_HEARTBEAT)  //immediately send for heart beat
            || (code == LOG_CODE_PUSH_RESULT); //immediately send for pushresult
        }
        else
        {
            //If have list, must inside the list to be priority
            for (id priorityCode in arrayPriorityCodes)
            {
                if ([[NSString stringWithFormat:@"%@", priorityCode] integerValue] == code)
                {
                    isForce = YES;
                    break;
                }
            }
        }
        if (isForce || ((self.numLogsWritten != 0) && (self.numLogsWritten % LOG_UPLOAD_INTERVAL == 0)))
        {
            if (handler)
            {
                [self uploadLogsToServerWithHandler:handler]; //calling function waiting for handler back, must do this immediately. for example in background send push result.
            }
            else
            {
                //delay 1 second, if within 1 second there is some other records inserted, they can combine together. This is to combine priority logline together, because after delay first selection post all local logline, and all next will get empty records and directly return. If not combine together, serial priority logline such as sh_module_xxx make logline pending.
                //Must use `dispatch_after` to another thread, `performSelector` and `NSTimer` doesn't work, due to current queue ends.
                double delayInSeconds = 1;
                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                dispatch_after(popTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^(void)
                   {
                       [self uploadLogsToServerWithHandler:handler];
                   });
            }
            self.numLogsWritten = 0;
        }
        else
        {
            //no need upload to server this time, finish here
            self.numLogsWritten ++;
            if (handler)
            {
                handler(nil, nil);
            }
        }
    });
}

- (void)uploadLogsToServerWithHandler:(SHCallbackHandler)handler
{
    //The database logs are selected and post to server, after post successfully they are removed from database; However if another selecting happen before previous one finish, duplicated records are selected and sent to server. Server expects unique records. Make a semaphore here to let it happen in sequence.
    NSAssert(![NSThread isMainThread], @"uploadLogsToServer wait in main thread.");
    if (![NSThread isMainThread])
    {
        dispatch_semaphore_wait(self.upload_semaphore, DISPATCH_TIME_FOREVER);
        NSArray *logRecords = [self loadLogRecords];
        if (logRecords.count == 0)
        {
            dispatch_semaphore_signal(self.upload_semaphore);
            if (handler)
            {
                handler(nil, nil);
            }
        }
        else
        {
            [self postLogRecords:logRecords withHandler:handler];
        }
    }
}

#pragma mark - public functions

+ (NSString *)databasePath
{
    static NSString *dbPath = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
      {
          NSArray *libraryDirs = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);  //use /Library because it can be backup and restore by iTunes
          NSString *streetHawkDir = [libraryDirs[0] stringByAppendingPathComponent:@"StreetHawk"];
          NSError *error;
          if (![[NSFileManager defaultManager] createDirectoryAtPath:streetHawkDir withIntermediateDirectories:YES attributes:nil error:&error])
          {
              NSLog(@"Fail to create /Library/StreetHawk dictionary: %@.", error.localizedDescription);
          }
          dbPath = [streetHawkDir stringByAppendingPathComponent:@"logcache.db"];
      });
    return dbPath;
}

+ (BOOL)checkLogdbForFreshInstall
{
    NSString *installId = [[NSUserDefaults standardUserDefaults] objectForKey:@"INSTALL_SUID_KEY"];
    if (installId == nil || installId.length == 0)
    {
        return NO; //This is actually really a fresh new install
    }
    //check local flag cache whether need re-register
    NSObject *reregisterObj = [[NSUserDefaults standardUserDefaults] objectForKey:@"APPSTATUS_REREGISTER"];
    if (reregisterObj != nil && [reregisterObj isKindOfClass:[NSNumber class]])
    {
        if ([(NSNumber *)reregisterObj boolValue])
        {
            //Treat as new install
            [SHLogger clearLocalToMakeFreshInstall];
            return YES;
        }
    }
    BOOL needClear = YES;
    if ([[NSFileManager defaultManager] fileExistsAtPath:[SHLogger databasePath]])
    {
        int maxLogidUserDefaults = -1;
        int maxlogidDb = -1;
        NSObject *maxLogidVal = [[NSUserDefaults standardUserDefaults] objectForKey:MAX_LOGID];
        if (maxLogidVal != nil && [maxLogidVal isKindOfClass:[NSNumber class]])
        {
            maxLogidUserDefaults = [(NSNumber *)maxLogidVal intValue];
        }
        NSAssert(maxLogidUserDefaults != -1, @"NSUserDefaults should have logid record.");
        if (maxLogidUserDefaults != -1)
        {
            sqlite3 *databaseCheck;
            int open_result = sqlite3_open_v2([[SHLogger databasePath] UTF8String], &databaseCheck, SQLITE_OPEN_READWRITE, NULL);
            if (open_result != SQLITE_OK)
            {
                sqlite3_close(databaseCheck);
                databaseCheck = nil;
                NSLog(@"Could not open database: %@, Error: %d", [SHLogger databasePath], open_result);
                assert(NO);
            }
            NSString *select_sql_str = [NSString stringWithFormat:@"SELECT seq from 'sqlite_sequence' WHERE name = '%@'", tableName];
            sqlite3_stmt *select_sql = NULL;
            int select_result = sqlite3_prepare_v2(databaseCheck, [select_sql_str UTF8String], -1, &select_sql, NULL);
            if (select_result != SQLITE_OK)
            {
                NSLog(@"Could not prepare sql [[[ %@ ]]], Error: %s", select_sql_str, sqlite3_errmsg(databaseCheck));
                assert(NO);
            }
            int select_step_result = sqlite3_step(select_sql);
            if (select_step_result == SQLITE_ROW)
            {
                maxlogidDb = sqlite3_column_int(select_sql, 0);
                select_step_result = sqlite3_step(select_sql);
            }
            if (select_step_result != SQLITE_DONE)
            {
                NSLog(@"Could not perform row select: %s", sqlite3_errmsg(databaseCheck));
                assert(NO);
            }
            sqlite3_reset(select_sql);
            sqlite3_finalize(select_sql);
            select_sql = NULL;
            NSAssert(maxlogidDb != -1, @"Local SQLite should have max logid.");
            if (maxlogidDb != -1)
            {
                if (maxLogidUserDefaults <= maxlogidDb) //use <= not ==, because maxLogidUserDefaults fail to permanently save when crash, causing it's less than maxlogidDb. Local SQLite logid larger than server is OK, it will not cause duplicate conflict. https://bitbucket.org/shawk/streethawk/issue/518/check-max-logid-in-sqlite-and. maxLogidUserDefaults will be recover when next log saved.
                {
                    needClear = NO; //local SQLite match last record in NSUserDefaults, expected, no need to refresh install.
                }
            }
        }
        if (needClear)
        {
            NSLog(@"Refresh as new install: SQLite max logid = %d but NSUserDefault max logid = %d.", maxlogidDb, maxLogidUserDefaults);
            NSAssert(NO, @"Refresh as new install: SQLite max logid = %d but NSUserDefault max logid = %d.", maxlogidDb, maxLogidUserDefaults); //this is rarely should happen
        }
    }
    else
    {
        NSLog(@"Refresh as new install: not find %@.", [SHLogger databasePath]);
    }
    if (needClear)
    {
        //Treat as new install
        [SHLogger clearLocalToMakeFreshInstall];
    }
    return needClear;
}

+ (BOOL)checkSentApnsModeForFreshInstall
{
    NSString *installId = [[NSUserDefaults standardUserDefaults] objectForKey:@"INSTALL_SUID_KEY"];
    if (installId == nil || installId.length == 0)
    {
        return NO; //This is actually really a fresh new install
    }
    SHAppMode sentMode = [[[NSUserDefaults standardUserDefaults] objectForKey:@"SentInstall_Mode"] intValue];
    BOOL needClear = (sentMode != shAppMode());
    if (needClear)
    {
        NSLog(@"Refresh as new install due to apns mode mismatch: previous %@, now %@.", shAppModeString(sentMode), shAppModeString(shAppMode()));
        //Treat as new install
        [SHLogger clearLocalToMakeFreshInstall];
    }
    return needClear;
}

#pragma mark - private functions

- (void)openSqliteDatabase
{
    NSString *databasePath = [SHLogger databasePath];
    int createResult = sqlite3_open_v2([databasePath UTF8String], &database, SQLITE_OPEN_CREATE |SQLITE_OPEN_READWRITE | SQLITE_OPEN_SHAREDCACHE, NULL);
    if (createResult != SQLITE_OK)
    {
        sqlite3_close(database);
        database = nil;
        SHLog(@"Could not create database: %@, Error: %d", databasePath, createResult);
        assert(NO);
    }
    //create the sql table for storing these log calls so they can be sent to the server later.
    NSMutableString *create_sql = [NSMutableString stringWithFormat:@"CREATE TABLE IF NOT EXISTS '%@' (", tableName];
    [create_sql appendString:@"'logid' INTEGER PRIMARY KEY AUTOINCREMENT, "];
    [create_sql appendString:@"'sessionid' INTEGER, "];
    [create_sql appendString:@"'created' TIMESTAMP NOT NULL, "];
    [create_sql appendString:@"'status' TINYINT, "]; // 0 = un uploaded, 1 = uploaded
    [create_sql appendString:@"'domain' TEXT, "];
    [create_sql appendString:@"'code' INTEGER, "];
    [create_sql appendString:@"'comment' TEXT, "];
    [create_sql appendString:@"'lat' FLOAT, "];
    [create_sql appendString:@"'lng' FLOAT, "];
    [create_sql appendString:@"'mloc' INTEGER, "];
    [create_sql appendString:@"'msgid' INTEGER, "];
    [create_sql appendString:@"'pushresult' INTEGER)"];
    sqlite3_stmt *create_stmt = NULL;
    int create_result = sqlite3_prepare_v2(database, [create_sql UTF8String], -1, &create_stmt, NULL);
    if (create_result != SQLITE_OK)
    {
        SHLog(@"Could not prepare sql [[[ %@ ]]], Error: %s", create_sql, sqlite3_errmsg(database));
        assert(NO);
    }    
    int step_result = sqlite3_step(create_stmt);
    if (step_result != SQLITE_DONE)
    {
        SHLog(@"Error in creating table (%@): %s", tableName, sqlite3_errmsg(database));
        assert(NO);
    }
    sqlite3_reset(create_stmt);
    sqlite3_finalize(create_stmt);
    create_stmt = NULL;
}

- (NSMutableArray *)loadLogRecords
{
    NSMutableArray *logRecords = [NSMutableArray array];
    NSString *select_sql_str = [NSString stringWithFormat:@"SELECT * from '%@' WHERE status = 0 ORDER BY logid", tableName];
    @synchronized(self)
    {
        sqlite3_stmt *select_sql = NULL;
        int select_result = sqlite3_prepare_v2(database, [select_sql_str UTF8String], -1, &select_sql, NULL);
        if (select_result != SQLITE_OK)
        {
            SHLog(@"Could not prepare sql [[[ %@ ]]], Error: %s", select_sql_str, sqlite3_errmsg(database));
            assert(NO);
        }
        int select_step_result = sqlite3_step(select_sql);
        while (select_step_result == SQLITE_ROW)
        {
            NSMutableDictionary *logRecord = [NSMutableDictionary dictionary];
            int logid = sqlite3_column_int(select_sql, LOG_COL_LOGID);
            int sessionid = sqlite3_column_int(select_sql, LOG_COL_SESSIONID);
            const char *created = (const char *)sqlite3_column_text(select_sql, LOG_COL_CREATED);
            int code = sqlite3_column_int(select_sql, LOG_COL_CODE);
            const char *comment = (const char *)sqlite3_column_text(select_sql, LOG_COL_COMMENT);
            double lat_deprecate = sqlite3_column_double(select_sql, LOG_COL_LAT);
            double lng_deprecate = sqlite3_column_double(select_sql, LOG_COL_LNG);
            int assocId = sqlite3_column_int(select_sql, LOG_COL_MSGID);
            int result = sqlite3_column_int(select_sql, LOG_COL_PUSHRESULT);
            //mandatory parameters for each logline
            logRecord[@"log_id"] = @(logid);
            logRecord[@"session_id"] = (sessionid==0) ? [NSNull null] : @(sessionid);
            logRecord[@"created_on_client"] = shCstringToNSString(created);
            logRecord[@"code"] = @(code);
            //Code: -1. Error
            if (code == LOG_CODE_ERROR)
            {
                logRecord[@"string"] = shCstringToNSString(comment);
            }
            //Codes: 19, 20. Locations
            else if (code == LOG_CODE_LOCATION_MORE || code == LOG_CODE_LOCATION_GEO)
            {
                NSDictionary *dictLoc = shParseObjectToDict(shCstringToNSString(comment));
                NSAssert(dictLoc != nil, @"Fail to parse code 19 and 20 lat/lng json.");
                NSAssert(dictLoc.allKeys.count == 2 && [dictLoc.allKeys containsObject:@"lat"] && [dictLoc.allKeys containsObject:@"lng"], @"Wrong format for 19 and 20 json.");
                double lat = [dictLoc[@"lat"] doubleValue];
                if (lat == 0)
                {
                    lat = lat_deprecate; //location is passed by comment so it record right the moment, not affected by dispatch to queue. to keep compatible with old version whose comment not update to location json, still consider deprecated lat/lng.
                }
                double lng = [dictLoc[@"lng"] doubleValue];
                if (lng == 0)
                {
                    lng = lng_deprecate;
                }
                NSAssert(lat != 0 && lng != 0, @"Assert fail try to send 19 or 20 with location 0.");
                logRecord[@"latitude"] = @(lat);
                logRecord[@"longitude"] = @(lng);
                NSDate *recordDate = shParseDate(shCstringToNSString(created), 0);
                NSAssert(recordDate != nil, @"Fail to parse record date.");
                NSDateFormatter *localDateFormatter = shGetDateFormatter(nil, [NSTimeZone localTimeZone], nil);
                logRecord[@"created_local_time"] = [localDateFormatter stringFromDate:recordDate];
            }
            //Code: 21. Beacon Update
            else if (code == LOG_CODE_LOCATION_IBEACON)
            {
                NSDictionary *dictComment = shParseObjectToDict(shCstringToNSString(comment));
                NSAssert(dictComment != nil, @"Fail to parse code 21 iBeacon json.");
                logRecord[@"json"] = dictComment;
            }
            //Code: 22. Geofence Update
            else if (code == LOG_CODE_LOCATION_GEOFENCE)
            {
                NSDictionary *dictComment = shParseObjectToDict(shCstringToNSString(comment));
                NSAssert(dictComment != nil, @"Fail to parse code 22 geofence json.");
                logRecord[@"json"] = dictComment;
            }
            //Code: 8050. UTC Offset
            else if (code == LOG_CODE_TIMEOFFSET)
            {
                logRecord[@"numeric"] = shCstringToNSString(comment);
            }
            //Code: 8051. Heartbeat
            else if (code == LOG_CODE_HEARTBEAT)
            {
                //No further data required.
            }
            //Code: 8052. Client Upgrade
            else if (code == LOG_CODE_CLIENTUPGRADE)
            {
                logRecord[@"string"] = shCstringToNSString(comment);
            }
            //code: 8101. App First Run (deprecated, old SDK may send, new SDK should not send)
            //code: 8102. App Initialized (not in use, client side can send, server will not use it)
            else if (code == LOG_CODE_APP_LAUNCH)
            {
                logRecord[@"string"] = shCstringToNSString(comment);
            }
            //Codes: 8103, 8104. App FG and BG
            else if (code == LOG_CODE_APP_VISIBLE || code == LOG_CODE_APP_INVISIBLE)
            {
                NSDictionary *dictComment = shParseObjectToDict(shCstringToNSString(comment));
                NSAssert(dictComment != nil, @"Fail to parse App visible/invisible comment.");
                double lat = 0;
                if ([dictComment.allKeys containsObject:@"lat"])
                {
                    lat = [dictComment[@"lat"] doubleValue];
                }
                if (lat == 0)
                {
                    lat = lat_deprecate;
                }
                double lng = 0;
                if ([dictComment.allKeys containsObject:@"lng"])
                {
                    lng = [dictComment[@"lng"] doubleValue];
                }
                if (lng == 0)
                {
                    lng = lng_deprecate;
                }
                if (lat != 0/*automatical location not allow 0 as it means not detected*/)
                {
                    logRecord[@"latitude"] = @(lat);
                }
                if (lng != 0)
                {
                    logRecord[@"longitude"] = @(lng);
                }
                NSDate *recordDate = shParseDate(shCstringToNSString(created), 0);
                NSAssert(recordDate != nil, @"Fail to parse record date.");
                NSDateFormatter *localDateFormatter = shGetDateFormatter(nil, [NSTimeZone localTimeZone], nil);
                logRecord[@"created_local_time"] = [localDateFormatter stringFromDate:recordDate];
            }
            //Code: 8105. Sessions
            else if (code == LOG_CODE_APP_COMPLETE)
            {
                NSDictionary *dict = shParseObjectToDict(shCstringToNSString(comment));
                NSAssert(dict != nil, @"Fail to parse App session complete dictionary.");
                if (dict != nil)
                {
                    logRecord[@"start"] = dict[@"visible"];
                    logRecord[@"end"] = dict[@"invisible"];
                    logRecord[@"length"] = @((int)([dict[@"duration"] doubleValue] + 0.5));
                }
            }
            //Codes: 8108, 8109. Enter and Exit View/Activity
            else if (code == LOG_CODE_VIEW_ENTER || code == LOG_CODE_VIEW_EXIT)
            {
                logRecord[@"string"] = shCstringToNSString(comment);
            }
            //Code: 8110. Complete View/Activity
            else if (code == LOG_CODE_VIEW_COMPLETE)
            {
                NSDictionary *dictActivity = shParseObjectToDict(shCstringToNSString(comment));
                NSAssert(dictActivity != nil, @"Fail to parse view complete dict from db.");
                if (dictActivity != nil)
                {
                    logRecord[@"string"] = dictActivity[@"page"];
                    logRecord[@"start"] = dictActivity[@"enter"];
                    logRecord[@"end"] = dictActivity[@"exit"];
                    logRecord[@"length"] = @((int)([dictActivity[@"duration"] doubleValue] + 0.5));
                    logRecord[@"bg"] = [dictActivity[@"bg"] boolValue] ? @"true" : @"false";
                }
            }
            //Code: 8112. Location Service Disabled
            else if (code == LOG_CODE_LOCATION_DENIED)
            {
                //No further data required.
            }
            //Code: 8200. Feed ACK
            else if (code == LOG_CODE_FEED_ACK)
            {
                NSAssert(assocId != 0, @"Send feed ack without assocId.");
                logRecord[@"feed_id"] = @(assocId);
            }
            //Code: 8201. Feed Result
            else if (code == LOG_CODE_FEED_RESULT)
            {
                NSAssert(assocId != 0, @"Send feed result without assocId.");
                logRecord[@"feed_id"] = @(assocId);
                NSAssert(result == LOG_RESULT_ACCEPT || result == LOG_RESULT_CANCEL || result == LOG_RESULT_LATER, @"Send feed result with improper result.");
                logRecord[@"result"] = @(result);
            }
            //Code: 8202. Push ACK
            else if (code == LOG_CODE_PUSH_ACK)
            {
                NSAssert(assocId != 0, @"Send push ack without assocId.");
                logRecord[@"message_id"] = @(assocId);
            }
            //Code: 8203. Push Result
            else if (code == LOG_CODE_PUSH_RESULT)
            {
                NSAssert(assocId != 0, @"Send push result without assocId.");
                logRecord[@"message_id"] = @(assocId);
                NSAssert(result == LOG_RESULT_ACCEPT || result == LOG_RESULT_CANCEL || result == LOG_RESULT_LATER, @"Send push result with improper result.");
                logRecord[@"result"] = @(result);
                NSInteger pushCode = [shCstringToNSString(comment) integerValue];
                NSAssert(pushCode != 0, @"Send push result without code.");
                logRecord[@"numeric"] = @(pushCode);
            }
            //Code: 8997. Increment Tag
            //Code: 8998. Delete Tag
            //Code: 8999. Add Tag
            else if (code == LOG_CODE_TAG_INCREMENT || code == LOG_CODE_TAG_DELETE || code == LOG_CODE_TAG_ADD)
            {
                NSDictionary *dictTag = shParseObjectToDict(shCstringToNSString(comment));
                NSAssert(dictTag != nil, @"Fail to parse tag dictionary.");
                for (NSString *key in dictTag.allKeys)
                {
                    logRecord[key] = dictTag[key];
                }
            }
            else
            {
                NSAssert(NO, @"Unsupported code %d.", code);
            }
            [logRecords addObject:logRecord]; //even above data may not match assert format, still sends to server. server will return success and delete them.
            select_step_result = sqlite3_step(select_sql);
        }
        if (select_step_result != SQLITE_DONE)
        {
            SHLog(@"Could not perform row select: %s", sqlite3_errmsg(database));
            assert(NO);
        }
        sqlite3_reset(select_sql);
        sqlite3_finalize(select_sql);
        select_sql = NULL;
    }
    return logRecords;
}

- (void)postLogRecords:(NSArray *)logRecords withHandler:(SHCallbackHandler)handler
{
    // before we post anything to the server, make sure the installation ID is set
    if (StreetHawk.currentInstall == nil)
    {
        handler = [handler copy];
        [StreetHawk registerOrUpdateInstallWithHandler:^(NSObject *target, NSError *error)
         {
             if (StreetHawk.currentInstall)
             {
                 [self postLogRecords:logRecords withHandler:handler];  //after register successfully, do it again
             }
             else
             {
                 dispatch_semaphore_signal(self.upload_semaphore);  //give up and it will upload next time
                 if (handler)
                 {
                     handler(nil, nil);
                 }
             }
         }];
    }
    else  //install exist, do upload to server and delete local db
    {
        NSString *postBody = shSerializeObjToJson(logRecords);
        if (postBody == nil || postBody.length == 0)
        {
            [self clearLogRecords:logRecords];  //these logs cannot be serial to json, delete them to avoid next time fail again. this is rare, but logically may happen.
            dispatch_semaphore_signal(self.upload_semaphore);
            if (handler)
                handler(nil, nil);
            return;
        }
        SHRequest *request = [SHRequest requestWithPath:@"installs/log/" withVersion:SHHostVersion_V2 withParams:nil withMethod:@"POST" withHeaders:nil withBodyOrStream:@[@"records", postBody]];
        handler = [handler copy];
        request.requestHandler = ^(SHRequest *logRequest)
        {
            //Since 2014-02-10, server save log in asynchronous way, so it does not return any error.
            //Update on 2015-02-27: dev returns error message for debugging, api return immediately.
            if (logRequest.error != nil/* && error != [SHRequest requestCancelledError]*//*A running request still post data to server even it's canncelled, so still need to delete the logs from database to avoid sending duplicated logs.*/)
            {
                if (![logRequest.error.domain isEqualToString:@"NSURLErrorDomain"] && StreetHawk.isDebugMode && shAppMode() != SHAppMode_AppStore && shAppMode() != SHAppMode_Enterprise)
                {
                    //NSAssert(NO, @"Log meets error (%@) for records: %@.", logRequest.error, logRecords); //comment this as dev returns error and crash App, make it cannot continue.
                }
                if (logRequest.error.code == 404)
                {
                    StreetHawk.currentInstall = nil;
                    [StreetHawk registerOrUpdateInstallWithHandler:nil];
                }
                dispatch_semaphore_signal(self.upload_semaphore);
            }
            else
            {
                //record last successfully post logs time.
                BOOL postHeartbeat = NO;
                BOOL postLocation = NO;
                for (NSDictionary *logRecord in logRecords)
                {
                    int code = [logRecord[@"code"] intValue];
                    if (code == LOG_CODE_HEARTBEAT)
                    {
                        postHeartbeat = YES;
                    }
                    if (code == LOG_CODE_LOCATION_MORE || code == LOG_CODE_LOCATION_GEO)
                    {
                        postLocation = YES;
                    }
                    if (postHeartbeat && postLocation)
                    {
                        break;
                    }
                }
                if (postHeartbeat)
                {
                    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithDouble:[[NSDate date] timeIntervalSinceReferenceDate]] forKey:REGULAR_HEARTBEAT_LOGTIME];
                }
                if (postLocation)
                {
                    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithDouble:[[NSDate date] timeIntervalSinceReferenceDate]] forKey:REGULAR_LOCATION_LOGTIME];
                }
                if (postHeartbeat || postLocation)
                {
                    [[NSUserDefaults standardUserDefaults] synchronize];
                }
                [self clearLogRecords:logRecords];
                dispatch_semaphore_signal(self.upload_semaphore);
            }
            //finish
            if (handler)
                handler(nil, logRequest.error);
        };
        [request startAsynchronously];
    }    
}

- (void)clearLogRecords:(NSArray *)logRecords
{
    //cannot dispatch_async otherwise this thread ends and not execute, cause semaphore not signal.
#if TARGET_IPHONE_SIMULATOR
    NSMutableString *delete_sql_str = [NSMutableString stringWithFormat:@"UPDATE '%@' set status = 1 WHERE status <> 1 AND logid in (", tableName];
#else
    NSMutableString *delete_sql_str = [NSMutableString stringWithFormat:@"DELETE FROM '%@' where logid in (", tableName];
#endif
    for (NSDictionary *logRecord in logRecords)
    {
        [delete_sql_str appendFormat:@"%d, ", [logRecord[@"log_id"] intValue]];
    }
    [delete_sql_str appendString:@"-1)"];
    @synchronized(self)
    {
        sqlite3_stmt *delete_sql = NULL;
        int delete_result = sqlite3_prepare_v2(database, [delete_sql_str UTF8String], -1, &delete_sql, NULL);
        if (delete_result != SQLITE_OK)
        {
            SHLog(@"Could not prepare sql [[[ %@ ]]], Error: %s", delete_sql_str, sqlite3_errmsg(database));
            assert(NO);
        }
        int step_result = sqlite3_step(delete_sql);
        NSAssert(step_result == SQLITE_DONE, @"Error in updating/deleting uploaded rows.");
        step_result = 0; //disable "Unused variable" due to NSAssert ignored in pods.
        sqlite3_reset(delete_sql);
        sqlite3_finalize(delete_sql);
        delete_sql = NULL;
    }
}

+ (void)clearLocalToMakeFreshInstall
{
    [[NSUserDefaults standardUserDefaults] setObject:@"" forKey:@"INSTALL_SUID_KEY"]; //clear local install id, next will register a new one. This is most important, otherwise logs cannot submit due to conflict logid.
    [[NSUserDefaults standardUserDefaults] setObject:@(NO) forKey:@"APPSTATUS_REREGISTER"];  //clear reregister flag
    [[NSUserDefaults standardUserDefaults] setObject:@(0) forKey:@"NumTimesAppUsed"]; //report "App first run" instead of "App started and engine initialized".
    [[NSUserDefaults standardUserDefaults] setObject:@(0) forKey:MAX_LOGID]; //local SQLite will be delete and rebuild, sent record reset to 0.
    [[NSUserDefaults standardUserDefaults] setObject:@"" forKey:@"SETTING_UTC_OFFSET"]; //make new install submit utc offset for first time.
    [[NSUserDefaults standardUserDefaults] setObject:@"" forKey:@"ENTER_PAGE_HISTORY"];  //new install not have enter/exit history
    [[NSUserDefaults standardUserDefaults] setObject:@"" forKey:@"ENTERBAK_PAGE_HISTORY"];
    [[NSUserDefaults standardUserDefaults] setObject:@"" forKey:@"EXIT_PAGE_HISTORY"];
    [[NSUserDefaults standardUserDefaults] setObject:@"" forKey:@"APPSTATUS_IBEACON_FETCH_TIME"]; //although App may still monitor these iBeacon regions, fetch them again for new intall.
    [[NSUserDefaults standardUserDefaults] setObject:[NSArray array] forKey:@"APPSTATUS_IBEACON_FETCH_LIST"]; //server side iBeacon UUID format changed in 1.6.0, must clear and re-register.
    [[NSUserDefaults standardUserDefaults] setObject:@"" forKey:@"APPSTATUS_GEOFENCE_FETCH_TIME"]; //although App may still monitor these geofence regions, fetch them again for new install.
    [[NSUserDefaults standardUserDefaults] setObject:@"" forKey:@"LOCATION_DENIED_SENT"]; //new install should send location denied log once.
    [[NSUserDefaults standardUserDefaults] setObject:@(0) forKey:FGBG_SESSION]; //new install session start from 1.
    [[NSUserDefaults standardUserDefaults] synchronize];
    //These not need to update
    //Remote notification: APNS_DISABLE_TIMESTAMP, APNS_SENT_DISABLE_TIMESTAMP, APNS_DEVICE_TOKEN. Because old data is correct when register new install, and old data is passed in install/register to server. Note: if revoked=timestamp, this will make revoked earlier than created, it's correct as revoked means first time when notification is disabled.
    //Sent history: SentInstall_AppKey, SentInstall_ClientVersion, SentInstall_ShVersion, SentInstall_Mode, SentInstall_Carrier, SentInstall_OSVersion, SentInstall_IBeacon. They are reset after install/register.
    //Module bridge: SH_GEOLOCATION_LAT, SH_GEOLOCATION_LNG, SH_BEACON_BLUETOOTH, SH_BEACON_iBEACON. They are reset after launch.
    //Crash report: CrashLog_MD5. Make sure not sent duplicate crash report again in new install.
    //Customer setting: ENABLE_LOCATION_SERVICE, ENABLE_PUSH_NOTIFICATION, FRIENDLYNAME_KEY. Cannot reset, must keep same setting as previous install.
    //Keep old version and adjust by App itself: APPKEY_KEY, NETWORK_RECOVER_TIME, APPSTATUS_STREETHAWKENABLED, APPSTATUS_DEFAULT_HOST, APPSTATUS_ALIVE_HOST, APPSTATUS_UPLOAD_LOCATION, APPSTATUS_SUBMIT_FRIENDLYNAME, APPSTATUS_CHECK_TIME, APPSTATUS_APPSTOREID, APPSTATUS_DISABLECODES, APPSTATUS_PRIORITYCODES, REGULAR_HEARTBEAT_LOGTIME, REGULAR_LOCATION_LOGTIME, SMART_PUSH_PAYLOAD. These will be updated automatically by App, keep old version till next App update them.
    //APPSTATUS_GEOFENCE_FETCH_LIST: cannot reset to empty, otherwise when change cannot find previous fence so not stop monitor.
    //User pass in: ADS_IDENTIFIER. Should not delete, move to next install.
    //SPOTLIGHT_DEEPLINKING_MAPPING: cannot reset to empty, otherwise when spotlight search cannot find mapping.
    //Rarely use: ALERTSETTINGS_MINUTES, PHONEGAP_8004_PAGE, PHONEGAP_8004_PUSHDATA. These are rarely use, and it will be correct when next customer call, ignore and not reset.
    //Delete SQLite database file, it will be re-build for this fresh new install, thus make sure logid start from 1.
    if ([[NSFileManager defaultManager] fileExistsAtPath:[SHLogger databasePath]])
    {
        NSError *error;
        BOOL success =[[NSFileManager defaultManager] removeItemAtPath:[SHLogger databasePath] error:&error];
        NSAssert(success, @"Fail to delete SQLite file: %@.", error.localizedDescription);
        success = YES; //disable "Unused variable" due to NSAssert ignored in pods.
    }
}

@end

@interface SHApp (private)

//Check and parse tag user dict. It must conform to some rule, otherwise return nil.
- (NSDictionary *)formatTagUserDict:(NSDictionary *)dict;

@end

@implementation SHApp (LoggerExtImp)

#pragma mark - public functions

- (void)sendLogForCode:(NSInteger)code withComment:(NSString *)comment
{
    [self sendLogForCode:code withComment:comment forAssocId:0 withResult:100/*ignore*/ withHandler:nil];
}

-(void)sendLogForCode:(NSInteger)code withComment:(NSString *)comment forAssocId:(NSInteger)assocId withResult:(NSInteger)result withHandler:(SHCallbackHandler)handler
{
    BOOL mustContainAssocId = NO;
    if (code == LOG_CODE_PUSH_RESULT || code == LOG_CODE_FEED_RESULT)
    {
        NSAssert(result == LOG_RESULT_ACCEPT || result == LOG_RESULT_CANCEL || result == LOG_RESULT_LATER, @"Log push result with invalid result (%ld).", (long)result);
        mustContainAssocId = YES;
    }
    else
    {
        result = 100/*ignore*/;
        if (code == LOG_CODE_PUSH_ACK || code == LOG_CODE_FEED_ACK)
        {
            mustContainAssocId = YES;
        }
    }
    if (mustContainAssocId)
    {
        NSAssert(assocId != 0, @"Try to do push or feed related log (%@) without assoc id.", comment);
    }
    else
    {
        NSAssert(assocId == 0, @"Try to do none push or feed related log (%@) with assoc id (%ld).", comment, (long)assocId);
    }
    NSAssert(self.logger != nil, @"Lose logline due to logger is not ready.");
    [self.logger logComment:comment atTime:[NSDate date] forCode:code forAssocId:assocId withResult:result withHandler:handler];
}

- (void)sendLogForTag:(NSDictionary *)dict withCode:(NSInteger)code
{
    if (!streetHawkIsEnabled())
    {
        return;
    }
    NSDictionary *formatDict = [self formatTagUserDict:dict];
    NSAssert(formatDict != nil, @"Fail to parse dict for tag: %@", dict);
    if (formatDict != nil)
    {
        NSString *formatStr = shSerializeObjToJson(formatDict);
        if (formatStr != nil && formatStr.length > 0)
        {
            [self sendLogForCode:code withComment:formatStr];
        }
    }
}

#pragma mark - private functions

- (NSDictionary *)formatTagUserDict:(NSDictionary *)dict
{
    //check dict's key must be "key" or "value" or "type".
    if ((dict.allKeys.count == 2 && [dict.allKeys containsObject:@"key"])  //for add or increment tag
        || (dict.allKeys.count == 1 && [dict.allKeys containsObject:@"key"]))  //for remove tag
    {
        NSMutableDictionary *mutableDict = [NSMutableDictionary dictionaryWithDictionary:dict];
        if (dict.allKeys.count  == 2)
        {
            if ([dict.allKeys containsObject:@"datetime"])
            {
                //value must be NSDate or eaque string, parse it into format as "2013-11-01 03:24:46".
                NSObject *valueObj = dict[@"datetime"];
                if ([valueObj isKindOfClass:[NSDate class]])
                {
                    mutableDict[@"datetime"] = shFormatStreetHawkDate((NSDate *)valueObj);
                }
                else if ([valueObj isKindOfClass:[NSString class]])
                {
                    NSDate *formatDate = shParseDate((NSString *)valueObj, 0);
                    if (formatDate != nil)
                    {
                        mutableDict[@"datetime"] = shFormatStreetHawkDate(formatDate);
                    }
                    else
                    {
                        SHLog(@"Error: Tag user dict uses wrong string for type \"datetime\" %@.", valueObj);
                        return nil;
                    }
                }
                else
                {
                    SHLog(@"Error: Tag user dict must use NSDate or NSString for type \"datetime\", but it's %@.", valueObj);
                    return nil;
                }
            }
            else if ([dict.allKeys containsObject:@"string"])
            {
                //string value would be a dictionary or array, need to check internal.
                NSObject *valueObj = dict[@"string"];
                if ([valueObj isKindOfClass:[NSDictionary class]])
                {
                    NSDictionary *formatDict = [self formatTagUserDict:(NSDictionary *)valueObj];
                    if (formatDict != nil)
                    {
                        mutableDict[@"string"] = formatDict;
                    }
                    else
                    {
                        SHLog(@"Error: Tag user dict has error when format internal dictionary: %@.", valueObj);
                        return nil;
                    }
                }
                else if ([valueObj isKindOfClass:[NSArray class]])
                {
                    NSMutableArray *mutableArray = [NSMutableArray arrayWithArray:(NSArray *)valueObj];
                    for (int i = 0; i < mutableArray.count; i ++)
                    {
                        NSObject *arrayObj = mutableArray[i];
                        if ([arrayObj isKindOfClass:[NSDictionary class]])
                        {
                            NSDictionary *formatDict = [self formatTagUserDict:(NSDictionary *)arrayObj];
                            if (formatDict != nil)
                            {
                                mutableArray[i] = formatDict;
                            }
                            else
                            {
                                SHLog(@"Error: Tag user dict has error when format internal array: %@.", arrayObj);
                                return nil;
                            }
                        }
                        else
                        {
                            SHLog(@"Error: Tag user dict has non dictionary object inside array %@.", arrayObj);
                            return nil;
                        }
                    }
                    mutableDict[@"string"] = mutableArray;
                }
                else if ([valueObj isKindOfClass:[NSString class]])
                {
                    //currently for string nothing to check. Previous there was a check to forbid empty string, however since more cases are included such as `sh_advertising_identifier`, empty string should be possible.
                }
                else
                {
                    SHLog(@"Error: Tag user dict has unexpected string value %@.", valueObj);
                    return nil;
                }
            }
            else if ([dict.allKeys containsObject:@"numeric"])
            {
                //numeric value would be a NSNumber, need to check internal.
                NSObject *valueObj = dict[@"numeric"];
                if (![valueObj isKindOfClass:[NSNumber class]])
                {
                    SHLog(@"Error: Tag user dict has wrong value for numeric %@.", valueObj);
                    return nil;
                }
            }
            else
            {
                SHLog(@"Error: Tag user dict has wrong type %@.", dict);
                return nil;
            }
        }
        return mutableDict;
    }
    else
    {
        SHLog(@"Error: Tag user dict must apply to format.");
        return nil;
    }
}

@end

