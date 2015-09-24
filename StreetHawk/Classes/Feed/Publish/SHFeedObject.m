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

@implementation SHFeedObject

+ (SHFeedObject *)createFromDictionary:(NSDictionary *)dict
{
    SHFeedObject *obj = nil;
    NSObject *typeVal = dict[@"type"];
    NSString *typeStr = nil;
    NSAssert(typeVal != nil && [typeVal isKindOfClass:[NSString class]], @"Type is not string for feed: %@.", dict);
    if (typeVal != nil && [typeVal isKindOfClass:[NSString class]])
    {
        typeStr = (NSString *)typeVal;
    }
    NSObject *contentVal = dict[@"content"];
    if (contentVal != nil && [contentVal isKindOfClass:[NSDictionary class]])
    {
        NSDictionary *contentDict = (NSDictionary *)contentVal;
        if (typeStr != nil && typeStr.length > 0 && [typeStr compare:@"news" options:NSCaseInsensitiveSearch] == NSOrderedSame)
        {
            obj = [[SHFeedNewsObject alloc] init];
            obj.type = SHFeedType_News;
            SHFeedNewsObject *newsObj = (SHFeedNewsObject *)obj;
            newsObj.title = contentDict[@"title"];
            newsObj.message = contentDict[@"message"];
        }
        else if (typeStr != nil && typeStr.length > 0 && [typeStr compare:@"offer" options:NSCaseInsensitiveSearch] == NSOrderedSame)
        {
            obj = [[SHFeedOfferObject alloc] init];
            obj.type = SHFeedType_Offer;
            SHFeedOfferObject *offerObj = (SHFeedOfferObject *)obj;
            offerObj.title = contentDict[@"title"];
            offerObj.desc = contentDict[@"description"];
            offerObj.discount = contentDict[@"discount"];
            offerObj.image_url = contentDict[@"image_url"];
        }
    }
    if (obj == nil)
    {
        if (typeStr != nil && typeStr.length > 0 && [typeStr compare:@"json" options:NSCaseInsensitiveSearch] == NSOrderedSame)
        {
            obj = [[SHFeedJsonObject alloc] init];
            obj.type = SHFeedType_Json;
            SHFeedJsonObject *jsonObj = (SHFeedJsonObject *)obj;
            jsonObj.content = contentVal;
        }
        else
        {
            obj = [[SHFeedUnknownObject alloc] init];
            obj.type = SHFeedType_Unknown;
            SHFeedUnknownObject *unknownObj = (SHFeedUnknownObject *)obj;
            unknownObj.content = contentVal;
            unknownObj.typeString = typeStr;
        }
    }
    NSAssert(obj != nil, @"Fail to create feed object from dict: %@.", dict);
    obj.feed_id = [dict[@"id"] integerValue];
    obj.isPublic = ([dict[@"public"] integerValue] == 1);
    obj.isDeleted = ([dict[@"deleted"] integerValue] == 1);
    obj.activates = shParseDate(dict[@"activates"], 0);
    obj.expires = shParseDate(dict[@"expires"], 0);
    obj.created = shParseDate(dict[@"created"], 0);
    obj.modified = shParseDate(dict[@"modified"], 0);
    return obj;
}

@end

@implementation SHFeedNewsObject

- (NSString *)description
{
    return [NSString stringWithFormat:@"News feed, title = %@, message = %@.", self.title, self.message];
}

@end

@implementation SHFeedOfferObject

- (NSString *)description
{
    return [NSString stringWithFormat:@"Offer feed, title = %@, description = %@, discount = %@, image url = %@.", self.title, self.desc, self.discount, self.image_url];
}

@end

@implementation SHFeedJsonObject

- (NSString *)description
{
    return [NSString stringWithFormat:@"Json feed, content = %@.", self.content];
}

@end

@implementation SHFeedUnknownObject

- (NSString *)description
{
    return [NSString stringWithFormat:@"Unsupported feed, type = %@, content = %@.", self.typeString, self.content];
}

@end
