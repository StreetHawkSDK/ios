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

#import "SHBaseViewController.h"
//header from StreetHawk
#import "SHApp.h" //for `StreetHawk shNotifyPageEnter/Exit`
#import "SHCoverWindow.h" //for cover window type check

@implementation StreetHawkBaseViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    if ([self respondsToSelector:@selector(displayDeepLinkingToUI)])
    {
        [self performSelector:@selector(displayDeepLinkingToUI)];
    }
}

//tricky: Record `viewWillAppear` as backup, become in canceled pop up `viewDidAppear` is not called.
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[NSUserDefaults standardUserDefaults] setObject:self.class.description forKey:@"ENTERBAK_PAGE_HISTORY"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

//tricky: Here must use `viewDidAppear` and `viewWillDisappear`.
//if use `viewWillAppear`, two issues: 1) Launch App `viewWillAppear` is called before `didFinishLaunchingWithOptions`, making home page not logged; 2) `viewWillAppear` cannot get self.view.window, always null, making it's unknown to check `SHCoverWindow`.
//if use `viewDidDisappear`, present modal view controller has problem. For example, A present modal B, first call B `viewDidAppear` then call A `viewDidDisappear`, making the order wrong, expecting A disappear first and then B appear. Use `viewWillDisappear` solve this problem.
//the mix just match requirement: disappear first and appear.
- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (![self.view.window isKindOfClass:[SHCoverWindow class]]) //several internal used vc not need log, such as SHFeedbackViewController, SHSlideWebViewController (it calls appear even not show).
    {
        [StreetHawk shNotifyPageEnter:self.class.description];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    if (![self.view.window isKindOfClass:[SHCoverWindow class]])  //If push two slides together, this happen.
    {
        [StreetHawk shNotifyPageExit:self.class.description];
    }
}

@end

@implementation StreetHawkBaseTableViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    if ([self respondsToSelector:@selector(displayDeepLinkingToUI)])
    {
        [self performSelector:@selector(displayDeepLinkingToUI)];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[NSUserDefaults standardUserDefaults] setObject:self.class.description forKey:@"ENTERBAK_PAGE_HISTORY"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (![self.view.window isKindOfClass:[SHCoverWindow class]]) //several internal used vc not need log, such as SHFeedbackViewController, SHSlideWebViewController (it calls appear even not show).
    {
        [StreetHawk shNotifyPageEnter:self.class.description];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    if (![self.view.window isKindOfClass:[SHCoverWindow class]])  //If push two slides together, this happen.
    {
        [StreetHawk shNotifyPageExit:self.class.description];
    }
}

@end
