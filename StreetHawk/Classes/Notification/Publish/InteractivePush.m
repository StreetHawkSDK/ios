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

#import "InteractivePush.h"

@implementation InteractivePush

#pragma mark - life cycle

- (id)initWithPairTitle:(NSString *)pairTitle withButton1:(NSString *)b1Title withButton2:(NSString *)b2Title
{
    if (self = [super init])
    {
        self.pairTitle = pairTitle;
        self.b1Title = b1Title;
        self.b2Title = b2Title;
    }
    return self;
}

@end
