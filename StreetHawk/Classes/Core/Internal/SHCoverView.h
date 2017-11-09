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

typedef void (^SHCoverViewOrientationChanged) (void);
typedef void (^SHCoverViewTouched) (CGPoint touchPoint);

/**
 Transparent light color cover view.
 */
@interface SHCoverView : UIView

@property (nonatomic, strong) UIViewController *contentVC;

/**
 The color of the overlay.
 */
@property (nonatomic, strong) UIColor *overlayColor;

/**
 The alpha of the overlay.
 */
@property (nonatomic) CGFloat overlayAlpha;

/**
 Callback when orientation changes.
 */
@property (nonatomic, copy) SHCoverViewOrientationChanged orientationChangedHandler;

/**
 Callback when full screen cover view is touched.
 */
@property (nonatomic, copy) SHCoverViewTouched touchedHandler;

- (void)orientationChanged:(NSNotification *)notification;

@end
