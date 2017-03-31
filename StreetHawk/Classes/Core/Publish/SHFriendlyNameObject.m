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

#import "SHFriendlyNameObject.h"

@implementation SHFriendlyNameObject

#pragma mark - public functions

+ (SHFriendlyNameObject *)findObjByFriendlyName:(NSString *)friendlyName
{
    SHFriendlyNameObject *findObj = nil;
    if (friendlyName != nil && friendlyName.length > 0)
    {
        NSArray *arrayFriendlyNames = [[NSUserDefaults standardUserDefaults] objectForKey:FRIENDLYNAME_KEY];
        for (NSDictionary *dict in arrayFriendlyNames)
        {
            if ([friendlyName compare:dict[FRIENDLYNAME_NAME] options:NSCaseInsensitiveSearch] == NSOrderedSame)
            {
                findObj = [[SHFriendlyNameObject alloc] init];
                findObj.friendlyName = friendlyName;
                findObj.vc = dict[FRIENDLYNAME_VC];
                findObj.xib_iphone = [dict.allKeys containsObject:FRIENDLYNAME_XIB_IPHONE] ? dict[FRIENDLYNAME_XIB_IPHONE] : nil;
                findObj.xib_ipad = [dict.allKeys containsObject:FRIENDLYNAME_XIB_IPAD] ? dict[FRIENDLYNAME_XIB_IPAD] : nil;
                break;
            }
        }
    }
    return findObj;
}

+ (NSString *)tryFriendlyName:(NSString *)vc
{
    //Check whether has friendly name for this page.
    NSArray *arrayFriendlyNames = [[NSUserDefaults standardUserDefaults] objectForKey:FRIENDLYNAME_KEY];
    for (NSDictionary *dict in arrayFriendlyNames)
    {
        if ([vc compare:dict[FRIENDLYNAME_VC]] == NSOrderedSame)
        {
            vc = dict[FRIENDLYNAME_NAME];
            break;
        }
    }
    return vc;
}

@end
