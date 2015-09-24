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

#import "SHInterceptor.h"

@implementation SHInterceptor

#pragma mark - life cycle

-(id)init
{
    if (self = [super init])
    {
        self.firstResponder = nil;
        self.secondResponder = nil;
    }
    return self;
}

#pragma mark - pass handling

- (void)setFirstResponder:(id)firstResponder_
{
    //Fix a dead loop, if firstResponder_ is self, the following forwardingTargetForSelector and respondsToSelector dead loop.
    if (firstResponder_ != self)
    {
        _firstResponder = firstResponder_;
    }
}

-(void)setSecondResponder:(id)secondResponder_
{
    //Fix a dead loop, if secondResponder_ is self, the following forwardingTargetForSelector and respondsToSelector dead loop.
    //Also need to check not first Responder, because some first Responder also call backup Responder for supplement functions, if they are same cause dead loop. 
    if (secondResponder_ != self && secondResponder_ != self.firstResponder)
    {
        _secondResponder = secondResponder_;
    }
}

- (BOOL)respondsToSelector:(SEL)aSelector
{
    if ([self.firstResponder respondsToSelector:aSelector])
    {
        return YES;
    }
    else if ([self.secondResponder respondsToSelector:aSelector])
    {
        return YES;
    }
    else
    {
        return [super respondsToSelector:aSelector];
    }
}

- (id)forwardingTargetForSelector:(SEL)aSelector
{
    if ([self.firstResponder respondsToSelector:aSelector])
    {
        return self.firstResponder;
    }
    else if ([self.secondResponder respondsToSelector:aSelector])
    {
        return self.secondResponder;
    }
    else
    {
        return [super forwardingTargetForSelector:aSelector];        
    }
}

@end
