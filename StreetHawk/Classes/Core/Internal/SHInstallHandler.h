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
 A handler for install notifications.
 */
@interface SHInstallHandler : NSObject

/** @name Install notification handlers */

/**
 Called when install/register finish successfully.
 */
- (void)installRegistrationSucceeded:(NSNotification *)aNotification;

/**
 Called when install/register finish with error.
 */
- (void)installRegistrationFailure:(NSNotification *)aNotification;

/**
 Called when install/update finish successfully.
 */
- (void)installUpdateSucceeded:(NSNotification *)aNotification;

/**
 Called when install/update finish with error.
 */
- (void)installUpdateFailure:(NSNotification *)aNotification;

@end
