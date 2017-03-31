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

#import "SHAlertView.h"
//header from StreetHawk
#import "SHInterceptor.h"

@interface SHAlertView ()

@property (nonatomic, strong) SHInterceptor *delegateInterceptor;
//Dealloc call some set, and it should be avoid by really take effect.
@property (nonatomic) BOOL isCalledFromDealloc;

@end

@implementation SHAlertView

#pragma mark - life cycle

- (id)initWithTitle:(NSString *)title message:(NSString *)message withHandler:(SHAlertViewHandler)handler cancelButtonTitle:(NSString *)cancelTitle otherButtonTitles:(NSString *)otherButtonTitles,...
{
    if (self = [super initWithTitle:title message:message delegate:nil cancelButtonTitle:cancelTitle otherButtonTitles:nil])
    {
        self.closedHandler = handler;
        //the following order cannot be changed.
        self.isCalledFromDealloc = NO;
        self.delegateInterceptor = [[SHInterceptor alloc] init];
        self.delegateInterceptor.firstResponder = self;
        self.delegate = self;
        // now add other titles
        va_list titles;
        if (otherButtonTitles)
        {
            [self addButtonWithTitle:otherButtonTitles];
            va_start(titles, otherButtonTitles);
            NSString *eachTitle;
            while ((eachTitle = va_arg(titles, NSString *)))
                [self addButtonWithTitle:eachTitle];
            va_end(titles);
        }
    }
    return self;
}

-(void)dealloc
{
    self.isCalledFromDealloc = YES;
    self.delegate = nil;
}

-(void)setDelegate:(id)delegate
{
    if (!self.isCalledFromDealloc)
    {
        self.delegateInterceptor.secondResponder = delegate;
        super.delegate = (id<UIAlertViewDelegate>)self.delegateInterceptor;
    }
    else
    {
        super.delegate = delegate; //to release delegate, same as self.delegate=nil but avoid dead loop.
    }
}

#pragma mark - UIAlertViewDelegate handler

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (self.closedHandler)
    {
        self.closedHandler(alertView, buttonIndex);
    }
    if ([self.delegateInterceptor.secondResponder respondsToSelector:@selector(alertView:clickedButtonAtIndex:)])
    {
        [self.delegateInterceptor.secondResponder alertView:alertView clickedButtonAtIndex:buttonIndex];
    }
}

@end

