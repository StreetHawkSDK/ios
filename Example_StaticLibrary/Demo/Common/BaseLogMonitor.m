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

#import "BaseLogMonitor.h"

NSString * const LogMonitorUpdatedNotification = @"LogMonitorUpdatedNotification";

@interface BaseLogMonitor ()

@property (nonatomic, strong) NSString *logFilePath;

@end

@implementation BaseLogMonitor

#pragma mark - life cycle

- (id)initWithLogFileName:(NSString *)logFileName
{
    if (self = [super init])
    {
        NSArray *libraryPaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        self.logFilePath = [libraryPaths[0] stringByAppendingPathComponent:logFileName];
    }
    return self;
}

#pragma mark - public functions

- (NSString *)logHistoryContent:(NSError **)error
{
    if (error != nil)
    {
        *error = nil;
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.logFilePath])
    {
        return [NSString stringWithContentsOfFile:self.logFilePath encoding:NSUTF8StringEncoding error:error];
    }
    return nil;
}

- (void)clearLogHistory:(NSError **)error
{
    if (error != nil)
    {
        *error = nil;
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.logFilePath])
    {
        [[NSFileManager defaultManager] removeItemAtPath:self.logFilePath error:error];
        [[NSNotificationCenter defaultCenter] postNotificationName:LogMonitorUpdatedNotification object:nil];
    }
}

- (void)writeToLogFileAndPostNotification:(NSString *)log
{
    //write to end of log file
    if (![[NSFileManager defaultManager] fileExistsAtPath:self.logFilePath])
    {
        [[NSFileManager defaultManager] createFileAtPath:self.logFilePath contents:nil attributes:nil];  //NSFileHandle must have the file exist first
    }
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:self.logFilePath];
    [fileHandle seekToEndOfFile];
    NSDateFormatter *dateFormat = shGetDateFormatter(nil, [NSTimeZone localTimeZone], nil);
    log = [NSString stringWithFormat:@"[%@] %@", [dateFormat stringFromDate:[NSDate date]], log];  //add time stamp
    [fileHandle writeData:[[log stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    [fileHandle closeFile];
    //post notification
    [[NSNotificationCenter defaultCenter] postNotificationName:LogMonitorUpdatedNotification object:nil];
}

+ (void)showLogToTextView:(UITextView *)viewLog fromMonitor:(BaseLogMonitor *)logMonitor
{
    dispatch_async(dispatch_get_main_queue(), ^
    {
        NSError *error;
        viewLog.text = [logMonitor logHistoryContent:&error];
        if (viewLog.text != nil && viewLog.text.length > 1)
        {
            viewLog.text = [viewLog.text stringByAppendingString:@"\n"];  //append a new line to avoid scroll hide last line
            [viewLog scrollRangeToVisible:NSMakeRange(viewLog.text.length - 1, 1)];
        }
        if (error)
        {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Fail to read log file" message:error.localizedDescription delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alertView show];
        }
    });
}

@end
