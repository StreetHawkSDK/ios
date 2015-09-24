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
 Callback when click button on SHActionSheet.
 */
typedef void(^SHActionSheetHandler)(UIActionSheet *view, NSInteger buttonIndex);

/**
 UIActionSheet needs to have delegate for the click events, which is not convenient and spread in different parts of code. SHActionSheet wrapper UIActionSheet by having handler to deal with callback. The create and button click can be in same piece of code.
 */
@interface SHActionSheet : UIActionSheet <UIActionSheetDelegate>

/**
 Callback when click button on SHActionSheet.
 */
@property (nonatomic, copy) SHActionSheetHandler closedHandler;

/**
 Create SHActionSheet.
 */
- (id)initWithTitle:(NSString *)title withHandler:(SHActionSheetHandler)handler cancelButtonTitle:(NSString *)cancelTitle otherButtonTitles:(NSString *)otherButtonTitles,...;

/**
 Show SHActionSheet in main windows.
 */
- (void)show;

@end
