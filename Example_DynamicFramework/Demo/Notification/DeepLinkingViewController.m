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

#import "DeepLinkingViewController.h"

@interface DeepLinkingViewController ()

@property (nonatomic, strong) NSDictionary *dictParam;

@end

@implementation DeepLinkingViewController

#pragma mark - life cycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Show Deeplinking Param";
}

#pragma mark - deeplinking handler

- (void)receiveDeepLinkingData:(NSDictionary *)dictParam
{
    self.dictParam = dictParam;
    [self displayDeepLinkingToUI];
}

- (void)displayDeepLinkingToUI
{
    self.labelParam.text = [NSString stringWithFormat:@"%@", self.dictParam];
}

@end
