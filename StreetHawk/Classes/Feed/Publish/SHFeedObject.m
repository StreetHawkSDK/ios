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

#import "SHFeedObject.h"
//header from StreetHawk
#import "SHUtils.h" //for shParseDate
#import "SHTypes.h" //for NONULL

@implementation SHFeedObject

- (NSString *)description
{
    return [NSString stringWithFormat:@"feed id = %@, title = %@, message = %@, campaign = %@, content = %@, activate on %@, expires on %@, created on %@, modified on %@, deleted on %@", self.feed_id, self.title, self.message, self.campaign, self.content, shFormatStreetHawkDate(self.activates), shFormatStreetHawkDate(self.expires), shFormatStreetHawkDate(self.created), shFormatStreetHawkDate(self.modified), shFormatStreetHawkDate(self.deleted)];
}

+ (SHFeedObject *)createFromDictionary:(NSDictionary *)dict
{
    SHFeedObject *obj = [[SHFeedObject alloc] init];
    obj.feed_id = [NSString stringWithFormat:@"%@", dict[@"id"]]; //server returns is int actually, make sure client use a string.
    NSObject *contentVal = dict[@"content"];
    NSAssert(contentVal != nil && [contentVal isKindOfClass:[NSDictionary class]], @"content should be dictionary.");
    if (contentVal != nil && [contentVal isKindOfClass:[NSDictionary class]])
    {
        NSDictionary *contentDict = (NSDictionary *)contentVal;
        NSObject *apsVal = contentDict[@"aps"];
        NSAssert(apsVal != nil && [apsVal isKindOfClass:[NSDictionary class]], @"aps should be dictionary.");
        if (apsVal != nil && [apsVal isKindOfClass:[NSDictionary class]])
        {
            NSDictionary *apsDict = (NSDictionary *)apsVal;
            NSString *alert = apsDict[@"alert"];
            int length = [contentDict[@"l"] intValue];
            if (length >= 0 && length <= alert.length)
            {
                obj.title = [[alert substringToIndex:length] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                obj.message = [[alert substringFromIndex:length] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            }
        }
        NSObject *data = contentDict[@"d"];
        NSDictionary *dataDict = shParseObjectToDict(data);
        if (dataDict != nil)
        {
            obj.content = dataDict;
        }
        else
        {
            obj.content = data;
        }
    }
    obj.campaign = [NSString stringWithFormat:@"%@", dict[@"campaign"]];
    obj.activates = shParseDate(dict[@"activates"], 0);
    obj.expires = shParseDate(dict[@"expires"], 0);
    obj.created = shParseDate(dict[@"created"], 0);
    obj.modified = shParseDate(dict[@"modified"], 0);
    obj.deleted = shParseDate(dict[@"deleted"], 0);
    return obj;
}

- (NSDictionary *)serializeToDictionary
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"feed_id"] = NONULL(self.feed_id);
    dict[@"title"] = NONULL(self.title);
    dict[@"message"] = NONULL(self.message);
    dict[@"campaign"] = NONULL(self.campaign);
    dict[@"content"] = self.content;
    dict[@"activates"] = shFormatStreetHawkDate(self.activates);
    dict[@"expires"] = shFormatStreetHawkDate(self.expires);
    dict[@"created"] = shFormatStreetHawkDate(self.created);
    dict[@"modified"] = shFormatStreetHawkDate(self.modified);
    dict[@"deleted"] = shFormatStreetHawkDate(self.deleted);
    return dict;
}

@end
