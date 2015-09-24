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

//This is a temp workaround for present dialog in middle of screen. As iOS 6 shows full screen dialog, this creates a SHCoverWindow and add view in the middle of it.
//When StreetHawk SDK deprecate iOS 6, this will be removed, and use system's custom modal dialog instead.
//This file must be compiled mac.

/**
 Category extension of NSObject.
 */
@interface NSObject(StreetHawkExt)

/**
 Present the `contentViewController` in the middle of full screen. It covers on top as a new window and layout in middle of screen. The xib of `contentViewController` should setup right "Freedom" size. To dismiss this view controller, call `[contentViewController dismissModalDialogViewController]`.
 */
- (void)presentModalDialogViewController:(UIViewController *)contentViewController;

@end

/**
 Category extension of UIViewController.
 */
@interface UIViewController(StreetHawkExt)

/**
 Dismiss the view controller which is presented by `presentModalDialogViewController`.
 */
- (void)dismissModalDialogViewController;

@end
