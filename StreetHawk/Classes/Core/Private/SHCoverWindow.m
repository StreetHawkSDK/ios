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

#import "SHCoverWindow.h"

@implementation SHCoverWindow

-(id)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame])
    {
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}

-(void)drawRect:(CGRect) rect
{
    if (self.overlayColor == nil)
    {
        CGContextSetFillColorWithColor(UIGraphicsGetCurrentContext(), [UIColor lightGrayColor].CGColor); //draw light gray cover.
        CGContextSetAlpha(UIGraphicsGetCurrentContext(), 0.4);
    }
    else
    {
        CGContextSetFillColorWithColor(UIGraphicsGetCurrentContext(), self.overlayColor.CGColor);
        CGContextSetAlpha(UIGraphicsGetCurrentContext(), self.overlayAlpha);
    }
    CGContextFillRect(UIGraphicsGetCurrentContext(), CGRectMake(0, 0, self.frame.size.width, self.frame.size.height));
}

@end
