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

#import "SHCoverView.h"

@implementation SHCoverView

-(id)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame])
    {
        self.backgroundColor = [UIColor clearColor];
        //add rotation notificaton observer
        [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationChanged:) name:UIDeviceOrientationDidChangeNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void)drawRect:(CGRect)rect
{
    //must use draw to avoid the subview's alpha not affected.
    if (self.overlayColor == nil)
    {
        CGContextSetFillColorWithColor(UIGraphicsGetCurrentContext(), [UIColor lightGrayColor].CGColor); //draw light gray cover.
        CGContextSetAlpha(UIGraphicsGetCurrentContext(), 0.5);
    }
    else
    {
        CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
        CGFloat colors[] =
        {
            1, 1, 1, 0.00,//start color(r,g,b,alpha)
            0, 0, 0, 0.7,
            0, 0, 0, 0.7,
            0, 0, 0, 0.8,
            0, 0, 0, 0.8,
            0, 0, 0, 0.8,
            0, 0, 0, 0.8,
            0, 0, 0, 0.8,
            0, 0, 0, 0.8,
            0, 0, 0, 0.8,
            0, 0, 0, 0.8,
            0, 0, 0, 0.8,
            0, 0, 0, 0.8,
            0, 0, 0, 0.8,
            0, 0, 0, 0.8,
            0, 0, 0, 0.8,
            0, 0, 0, 0.8,
            0, 0, 0, 0.8,
            0, 0, 0, 0.8,
            0, 0, 0, 0.8,//end color
        };
        
        CGGradientRef gradient = CGGradientCreateWithColorComponents
        (rgb, colors, NULL, 20);
        
        CGPoint start = CGPointMake(230,264);
        CGPoint end = CGPointMake(230,264);
        CGFloat startRadius = 30.0f;
        CGFloat endRadius = MAX(self.frame.size.width,self.frame.size.height);
        CGContextRef graCtx = UIGraphicsGetCurrentContext();
        CGContextDrawRadialGradient(graCtx, gradient, start, startRadius, end, endRadius, 0);
        
        CGGradientRelease(gradient);
        gradient=NULL;
        CGColorSpaceRelease(rgb);
        
        CGContextClearRect(UIGraphicsGetCurrentContext(), self.bounds);
        CGContextSetFillColorWithColor(UIGraphicsGetCurrentContext(), self.overlayColor.CGColor);
        CGContextSetAlpha(UIGraphicsGetCurrentContext(), self.overlayAlpha);
    }
    CGContextFillRect(UIGraphicsGetCurrentContext(), CGRectMake(0, 0, self.frame.size.width, self.frame.size.height));
}

- (void)orientationChanged:(NSNotification *)notification
{
    if (self.orientationChangedHandler)
    {
        self.orientationChangedHandler();
    }
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(nullable UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    //A safety precautions: this view is dim cover used for tip.
    //In case there is no tip available, the dim cover should be able to dismiss itself.
    //Check whether the dim cover has tip on it, if not, just remove it so that it won't stuck customer.
    if (self.subviews.count > 0)
    {
        if (self.touchedHandler)
        {
            self.touchedHandler([[[event allTouches] anyObject] locationInView:self]);
        }
    }
    else
    {
        [self removeFromSuperview];
    }
}

@end
