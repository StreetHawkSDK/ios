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

#import <StreetHawkCore/StreetHawkCore.h>

//The notification when log file content change.
extern NSString * const LogMonitorUpdatedNotification;

@interface BaseLogMonitor : NSObject

//Init a monitor with log file name, such as "***Log". 
- (id)initWithLogFileName:(NSString *)logFileName;

//Read log file to get the history content.
- (NSString *)logHistoryContent:(NSError **)error;

//Delete log file. It will create next time when write log.
- (void)clearLogHistory:(NSError **)error;

//Append the message to log file and post a notification for updating UI.
- (void)writeToLogFileAndPostNotification:(NSString *)log;

//Display log history to UITextView and scroll to end. 
+ (void)showLogToTextView:(UITextView *)viewLog fromMonitor:(BaseLogMonitor *)logMonitor;

@end
