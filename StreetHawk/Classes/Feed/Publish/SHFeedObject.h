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
 Callback once detect new feeds.
 */
typedef void (^SHNewFeedsHandler)();

/**
 Callback once fetch feeds.
 @param arrayFeeds NSArray of SHFeedObject.
 @param error If fetch meet error, return here.
 */
typedef void (^SHFeedsFetchHandler)(NSArray *arrayFeeds, NSError *error);

typedef enum
{
    /** News feed */
    SHFeedType_News,
    /** Offer feed */
    SHFeedType_Offer,
    /** Custom json feed */
    SHFeedType_Json,
    /** Unknown feed */
    SHFeedType_Unknown,
} SHFeedType;

/**
 Base class for feed object.
 */
@interface SHFeedObject : NSObject

/**
 A unique identifier for the feed item.
 */
@property (nonatomic) NSInteger feed_id;

/**
 Type of the feed item.
 */
@property (nonatomic) SHFeedType type;

/**
 Whether the Feed item is public or not. Public items are visible to all users. Non-public Feed items (templates) can be used in Campaign Actions or be added via assigning feed items.
 */
@property (nonatomic) BOOL isPublic;

/**
 Indicates if this item has been removed.
 */
@property (nonatomic) BOOL isDeleted;

/**
 A timestamp when the item activates (it will not be visible to clients before). It's possible to be nil.
 */
@property (nonatomic, strong) NSDate *activates;

/**
 A timestamp when the item expires (it will not be visible to clients after). It's possible to be nil.
 */
@property (nonatomic, strong) NSDate *expires;

/**
 When the Feed item has been created.
 */
@property (nonatomic, strong) NSDate *created;

/**
 When the Feed item was modified the last time.
 */
@property (nonatomic, strong) NSDate *modified;

/**
 Create from dictionary with filled properties, according to `type` it can create concrete object.
 */
+ (SHFeedObject *)createFromDictionary:(NSDictionary *)dict;

@end

/**
 News feed object.
 */
@interface SHFeedNewsObject : SHFeedObject

/**
 Title of this news.
 */
@property (nonatomic, strong) NSString *title;

/**
 Message of this news.
 */
@property (nonatomic, strong) NSString *message;

@end

/**
 Offer feed object.
 */
@interface SHFeedOfferObject : SHFeedObject

/**
 Title of this offer.
 */
@property (nonatomic, strong) NSString *title;

/**
 Description of this offer.
 */
@property (nonatomic, strong) NSString *desc;

/**
 Discount of this offer.
 */
@property (nonatomic, strong) NSString *discount;

/**
 Image_url of this offer.
 */
@property (nonatomic, strong) NSString *image_url;

@end

/**
 Json feed object.
 */
@interface SHFeedJsonObject : SHFeedObject

/**
 Json content, parse to NSObject.
 */
@property (nonatomic, strong) id content;

@end

/**
 Unknown feed object.
 */
@interface SHFeedUnknownObject : SHFeedObject

/**
 Content part, but type is not "json".
 */
@property (nonatomic, strong) id content;

/**
 Type read from dictionary.
 */
@property (nonatomic, strong) NSString *typeString;

@end
