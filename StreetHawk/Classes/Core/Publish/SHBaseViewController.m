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
//header from System
#import <objc/runtime.h> //for associate object

@interface NSString (SHEnterExitExt)

//Before logline enter or exit the page name, do some refinement.
- (NSString *)refinePageName;

@end

@implementation NSString (private)

- (NSString *)refinePageName
{
    NSString *page = self;
    //Swift class name contains App name, remove it before logline.
    if ([page rangeOfString:@"."].location != NSNotFound)
    {
        NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
        NSString *appPrefix = [NSString stringWithFormat:@"%@.", appName];
        if ([page hasPrefix:appPrefix])
        {
            page = [page substringFromIndex:appPrefix.length];
        }
    }
    return page;
}

@end

@implementation StreetHawkBaseViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    if ([self respondsToSelector:@selector(displayDeepLinkingToUI)])
    {
        [self performSelector:@selector(displayDeepLinkingToUI)];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PointziBridge_ShowTip_Notification" object:nil userInfo:@{@"vc": self}];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PointziBridge_ShowAuthor_Notification" object:nil userInfo:@{@"vc": self}];
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
    if (![self.view.window isKindOfClass:[SHCoverWindow class]]
        && ![self.class.description isEqualToString:@"SHModalTipViewController"]
        && ![self.class.description isEqualToString:@"SHPopTipViewController"]) //several internal used vc not need log, such as SHFeedbackViewController, SHSlideWebViewController (it calls appear even not show).
    {
        [StreetHawk shNotifyPageEnter:[self.class.description refinePageName]];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    if (![self.view.window isKindOfClass:[SHCoverWindow class]])  //If push two slides together, this happen.
    {
        [StreetHawk shNotifyPageExit:[self.class.description refinePageName]];
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
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PointziBridge_ShowTip_Notification" object:nil userInfo:@{@"vc": self}];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PointziBridge_ShowAuthor_Notification" object:nil userInfo:@{@"vc": self}];
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
    if (![self.view.window isKindOfClass:[SHCoverWindow class]]
        && ![self.class.description isEqualToString:@"SHModalTipViewController"]
        && ![self.class.description isEqualToString:@"SHPopTipViewController"]) //several internal used vc not need log, such as SHFeedbackViewController, SHSlideWebViewController (it calls appear even not show).
    {
        [StreetHawk shNotifyPageEnter:[self.class.description refinePageName]];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    if (![self.view.window isKindOfClass:[SHCoverWindow class]])  //If push two slides together, this happen.
    {
        [StreetHawk shNotifyPageExit:[self.class.description refinePageName]];
    }
}

@end

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

@end

@implementation SHCoverView

-(id)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame])
    {
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
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
        CGContextSetFillColorWithColor(UIGraphicsGetCurrentContext(), self.overlayColor.CGColor);
        CGContextSetAlpha(UIGraphicsGetCurrentContext(), self.overlayAlpha);
    }
    CGContextFillRect(UIGraphicsGetCurrentContext(), CGRectMake(0, 0, self.frame.size.width, self.frame.size.height));
}

@end

@interface UIViewController (SHViewExt_private)

@property (nonatomic, strong) SHCoverView *coverView; //if it has cover view required, assign to this property.

@end

@implementation UIViewController(SHViewExt)

- (SHCoverView *)coverView
{
    return objc_getAssociatedObject(self, @selector(coverView));
}

- (void)setCoverView:(SHCoverView *)coverView
{
    objc_setAssociatedObject(self, @selector(coverView), coverView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)presentOnTopWithCover:(BOOL)needCover withCoverColor:(UIColor *)coverColor withCoverAlpha:(CGFloat)coverAlpha withCoverTouchHandler:(void (^)())coverTouchHandler withAnimationHandler:(void (^)(CGRect))animationHandler
{
    UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
    CGRect rootRect = rootVC.view.bounds; //this has orientation included. when rotate it can get the real CGRect accoriding to orientation.
    self.view.frame = CGRectOffset(self.view.frame, -1000, -1000); //make it out of screen, but not change size.
    if (needCover)
    {
        self.coverView = [[SHCoverView alloc] initWithFrame:rootVC.view.bounds];
        self.coverView.contentVC = self; //must have someone retain self as VC. Because it only added view and VC is dealloc, causing keyboard notification cannot trigger. Here has cover view to retain it. This only needed for keyboard input view controller, such as feedback input VC.
        self.coverView.overlayColor = coverColor;
        self.coverView.overlayAlpha = coverAlpha;
        //TODO: touch event
        [rootVC.view addSubview:self.coverView];
        [self.coverView addSubview:self.view];
    }
    else
    {
        [rootVC.view addSubview:self.view];
    }
    if (animationHandler != nil)
    {
        animationHandler(rootRect); //allow customer code to animation show.
    }
    else
    {
        //directly add, not need animation. by default, put the content vc in middle of screen.
        self.view.frame = CGRectMake((rootRect.size.width - self.view.frame.size.width) / 2, (rootRect.size.height - self.view.frame.size.height) / 2, self.view.frame.size.width, self.view.frame.size.height);
    }
}

- (void)dismissOnTop
{
    [self.view removeFromSuperview];
    if (self.coverView != nil)
    {
        [self.coverView removeFromSuperview];
    }
}

@end

