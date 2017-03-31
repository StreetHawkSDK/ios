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

#import "SHActionSheet.h"
//header from StreetHawk
#import "SHInterceptor.h"
#import "SHUtils.h" //get presentWindow

@interface SHActionSheet ()

@property (nonatomic, strong) SHInterceptor *delegateInterceptor;
//Dealloc call some set, and it should be avoid by really take effect.
@property (nonatomic) BOOL isCalledFromDealloc;

@end

@implementation SHActionSheet

#pragma mark - life cycle

- (id)initWithTitle:(NSString *)title withHandler:(SHActionSheetHandler)handler cancelButtonTitle:(NSString *)cancelTitle otherButtonTitles:(NSString *)otherButtonTitles,...
{
    if (self = [super initWithTitle:title delegate:nil cancelButtonTitle:cancelTitle destructiveButtonTitle:nil otherButtonTitles:nil])
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
        super.delegate = (id<UIActionSheetDelegate>)self.delegateInterceptor;
    }
    else
    {
        super.delegate = delegate; //to release delegate, same as self.delegate=nil but avoid dead loop.
    }
}

#pragma mark - UIActionSheetDelegate handler

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (self.closedHandler)
    {
        self.closedHandler(actionSheet, buttonIndex);
    }
    if ([self.delegateInterceptor.secondResponder respondsToSelector:@selector(actionSheet:clickedButtonAtIndex:)])
    {
        [self.delegateInterceptor.secondResponder actionSheet:actionSheet clickedButtonAtIndex:buttonIndex];
    }
}

#pragma mark - public function

- (void)show
{
    UIWindow *presentWindow = shGetPresentWindow();
    [self showInView:presentWindow];
}

@end

