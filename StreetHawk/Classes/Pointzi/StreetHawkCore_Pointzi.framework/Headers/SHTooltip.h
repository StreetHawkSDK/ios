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

#import <UIKit/UIKit.h>

/**
 Where the tooltip should be placed relative to UI element.
 */
enum SHTooltipPosition
{
    SHTooltipPosition_Auto = 0,
    SHTooltipPosition_Left = 1,
    SHTooltipPosition_Right = 2,
    SHTooltipPosition_Up = 3,
    SHTooltipPosition_Down = 4,
};
typedef enum SHTooltipPosition SHTooltipPosition;

/**
 The type of tooltip.
 */
enum SHTooltipType
{
    /**
     A series of tooltips, when clicking "Next" button it goes through one by one.
     */
    SHTooltipType_Tour = 0,
    /**
     A single tooltip.
     */
    SHTooltipType_Tip = 1,
    /**
     A modal page.
     */
    SHTooltipType_Modal = 2,
};
typedef enum SHTooltipType SHTooltipType;

/**
 How should the tooltip appear.
 */
enum SHTooltipTrigger
{
    /**
     Appear immediately after page load.
     */
    SHTooltipTrigger_PageLoad = 0,
    /**
     Appear when target UI element is clicked.
     */
    SHTooltipTrigger_Click = 1,
    //TODO: will add more
};
typedef enum SHTooltipTrigger SHTooltipTrigger;

@class SHTooltipSeries;

/**
 Object representing a single tooltip.
 */
@interface SHTooltip : NSObject

/**
 "id" field of a tooltip. It's unique in a series.
 */
@property (nonatomic, strong) NSString *suid;

/**
 A unique identifier for the containing feed. This is got from parent feed object.
 */
@property (nonatomic) NSString * feed_id;

/**
 Title of the tooltip.
 */
@property (nonatomic, strong) NSString *title;

/**
 Message content of the tooltip.
 */
@property (nonatomic, strong) NSString *content;

/**
 Image of the tooltip. //TODO: not implement
 */
@property (nonatomic, strong) NSString *imageUrl;

/**
 Title color of the tooltip.
 */
@property (nonatomic, strong) UIColor *titleColor;

/**
 Title background color of the tooltip.
 */
@property (nonatomic, strong) UIColor *titleBackgroundColor;

/**
 Message content color of the tooltip.
 */
@property (nonatomic, strong) UIColor *contentColor;

/**
 Background of the tooltip.
 */
@property (nonatomic, strong) UIColor *backgroundColor;

/**
 Position of the tooltip relative to target UI element.
 */
@property (nonatomic) SHTooltipPosition position;

/**
 Delay seconds before this tooltip show.
 */
@property (nonatomic) double delaySeconds;

/**
 The view controller which this tooltip should display.
 */
@property (nonatomic, strong) NSString *view;

/**
 Target element's reference name or display name, for example: "btnLogin" or "Log in".
 */
@property (nonatomic, strong) NSString *target;

/**
 Only used for child element such as a cell in table. It's the child element's reference name or display name.
 */
@property (nonatomic, strong) NSString *childText;

/**
 Only used for child element such as a cell in table. It's the child element's index.
 */
@property (nonatomic, strong) NSString *childIndex;

/**
 Title for previous button, which is on the left.
 */
@property (nonatomic, strong) NSString *previousButton;

/**
 Title for next button, which is on the right.
 */
@property (nonatomic, strong) NSString *nextButton;

/**
 Button text color of the tooltip.
 */
@property (nonatomic, strong) UIColor *buttonTextColor;

/**
 Button background color of the tooltip.
 */
@property (nonatomic, strong) UIColor *buttonBackgroundColor;

/**
 Style for showing close button. //TODO: Currently it's a cross button.
 */
@property (nonatomic) BOOL showCloseButton;

/**
 Pair of predefined buttons. //TODO: not implement now.
 */
@property (nonatomic, strong) NSString *pair;

/**
 Button for positive on delete confirm dialog, which is on the left.
 */
@property (nonatomic, strong) NSString *DND_b1;

/**
 Button for negative on delete confirm dialog, which is on the right.
 */
@property (nonatomic, strong) NSString *DND_b2;

/**
 Title on delete confirm dialog.
 */
@property (nonatomic, strong) NSString *DND_title;

/**
 Message content on delete confirm dialog.
 */
@property (nonatomic, strong) NSString *DND_content;

/**
 Weak reference to containing series. This is assigned when a tooltip is added into a series.
 */
@property (nonatomic, weak) SHTooltipSeries *series;

/**
 Weak reference to this tooltip's view controller. It's assigned when showing a view controller and match this tooltip's.
 */
@property (nonatomic, weak) UIViewController *ctrl;

/**
 Weak reference of the target view which this tooltip is aligned with. It's assigned when parsing tooltip for a view controller.
 */
@property (nonatomic, weak) id targetView;

/**
 Weak reference of the trigger view which trigger this tooltip. It's for event handler. It's assigned when hooking event in a view controller. It can be same or not same as targetView.
 */
@property (nonatomic, weak) id triggerView;

/**
 Fill properties from feed json. Feed json is read from web console, which is not well-formatted. Return NO if fail to parse.
 @return Return YES if successfully parse; return NO if fail to parse.
 */
- (BOOL)loadFromFeedDict:(NSDictionary *)dictFeed;

/**
 Deserialize function. Create an object from dictionary.
 @return A created object.
 */
+ (SHTooltip *)loadFromDict:(NSDictionary *)dict;

/**
 Serialize function.
 @return Serialize self into a dictionary.
 */
- (NSDictionary *)serializeToDict;

@end

/**
 Representing a series of tooltips.
 */
@interface SHTooltipSeries : NSObject

/**
 Type of current tooltip series.
 */
@property (nonatomic) SHTooltipType tooltipType;

/**
 Trigger of current tooltip series.
 */
@property (nonatomic) SHTooltipTrigger trigger;

/**
 View controller of starting target page.
 */
@property (nonatomic, strong) NSString *view;

/**
 Array of the series.
 */
@property (nonatomic, strong) NSArray *arrayTooltips;

/**
 Deserialize function. Create an object from dictionary.
 @param dict The original dict.
 @return A created object.
 */
+ (SHTooltipSeries *)loadFromDict:(NSDictionary *)dict;

/**
 Serialize function.
 @return Serialize self into a dictionary.
 */
- (NSDictionary *)serializeToDict;

@end
