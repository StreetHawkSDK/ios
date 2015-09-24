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

#import "SHPresentDialog.h"
//header from StreetHawk
#import "SHCoverWindow.h" //for cover window

//ARC: This file is specifically marked with "-fno-objc-arc" to force it to use MRC instead of ARC. Because it must have `retain` in `presentModalDialogViewController`, otherwise nothing can show because window dealloc when function end. Tried to add property of UIViewController to retain the UIWindow but still not work.
//Test current implementation:
//1. present dialog successfully.
//2. content view controller is dealloc after dismiss.
//3. window is dealloc after dismiss.

@implementation NSObject(StreetHawkExt)

- (void)presentModalDialogViewController:(UIViewController *)contentViewController
{
    [contentViewController retain];  //retain the contentViewController otherwise it's released because nothing retain it.
    CGRect fullScreenRect = [UIScreen mainScreen].bounds;
    SHCoverWindow *windowCover = [[SHCoverWindow alloc] initWithFrame:fullScreenRect];  //cannot release window otherwise nothing get show, this window will be manually release when dismissModalDialogViewController
    UIViewController *vcBackground = [[[UIViewController alloc] initWithNibName:nil bundle:nil] autorelease];  //The root view controller covers whole window, so must create a background VC.
    windowCover.rootViewController = vcBackground;  //set rootViewController so that it can rotate
    vcBackground.view.backgroundColor = [UIColor clearColor];  //The background VC is invisible, show light gray window.
    contentViewController.view.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;  //must set this otherwise contentViewController's location is not right after rotate. The xib of contentViewController's view can avoid set in size.
    [vcBackground.view addSubview:contentViewController.view];
    CGRect contentSize = contentViewController.view.bounds;  //The xib of contentViewController's view should set Freedom and set the size.
    contentViewController.view.frame = CGRectMake(fullScreenRect.origin.x + contentSize.origin.x + (fullScreenRect.size.width - contentSize.size.width)/2, fullScreenRect.origin.y + contentSize.origin.y + (fullScreenRect.size.height - contentSize.size.height)/2, contentSize.size.width, contentSize.size.height);
    [windowCover makeKeyAndVisible];  //show it
}

@end

@implementation UIViewController(StreetHawkExt)

- (void)dismissModalDialogViewController
{
    //To make this function more reliable. When it was created, it assumes that the view was presented by `presentModalDialogViewController`, so safe to release self.view.window. However later test find it maybe presented by other way, for example by navigate. If so it will crash if release self.view.window. Ticket https://bitbucket.org/shawk/streethawk/issue/370/crash-push-notification-8004-dismiss.
    //So to be safe, first check it's called by `presentModalDialogViewController`, if not try to navigate back, if not try to `dismissModalViewControllerAnimated`.
    if ([self.view.window isKindOfClass:[SHCoverWindow class]])  //SHCoverWindow is private, only way to use it is by `presentModalDialogViewController`.
    {
        self.view.window.hidden = YES;  //must set hidden otherwise window is not invisible immediately until next touch
        [self.view.window release];  //release the window
        [self release];  //release self, matching [contentViewController retain].
    }
    else if (self.navigationController != nil)
    {
        [self.navigationController popViewControllerAnimated:YES];
    }
    else
    {
        [self dismissViewControllerAnimated:YES completion:nil];  //this is harmless even not `presentModalViewController` before.
    }
}

@end
