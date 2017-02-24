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
#import "SHViewController.h" //for checking internal vc to avoid enter/exit log
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
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PointziBridge_SuperTag_Notification" object:nil userInfo:@{@"vc": self}];
}

//tricky: Record `viewWillAppear` as backup, become in canceled pop up `viewDidAppear` is not called.
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[NSUserDefaults standardUserDefaults] setObject:self.class.description forKey:@"ENTERBAK_PAGE_HISTORY"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

//tricky: Here must use `viewDidAppear` and `viewWillDisappear`.
//if use `viewWillAppear`, two issues: 1) Launch App `viewWillAppear` is called before `didFinishLaunchingWithOptions`, making home page not logged; 2) `viewWillAppear` cannot get self.view.window, always null, making it's unknown to check `SHCoverWindow`(deprecated).
//if use `viewDidDisappear`, present modal view controller has problem. For example, A present modal B, first call B `viewDidAppear` then call A `viewDidDisappear`, making the order wrong, expecting A disappear first and then B appear. Use `viewWillDisappear` solve this problem.
//the mix just match requirement: disappear first and appear.
- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (![self isKindOfClass:[SHBaseViewController class]]
        && ![self isKindOfClass:[SHBaseTableViewController class]]) //several internal used vc not need log, such as SHFeedbackViewController, SHSlideWebViewController (it calls appear even not show).
    {
        [StreetHawk shNotifyPageEnter:[self.class.description refinePageName]];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PointziBridge_ShowAuthor_Notification" object:nil userInfo:@{@"vc": self}];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    if (![self isKindOfClass:[SHBaseViewController class]]
        && ![self isKindOfClass:[SHBaseTableViewController class]]) //several internal used vc not need log, such as SHFeedbackViewController, SHSlideWebViewController (it calls appear even not show).
    {
        [StreetHawk shNotifyPageExit:[self.class.description refinePageName]];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PointziBridge_ForceDismissTip_Notification" object:nil userInfo:@{@"vc": self}];
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
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PointziBridge_SuperTag_Notification" object:nil userInfo:@{@"vc": self}];
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
    if (![self isKindOfClass:[SHBaseViewController class]]
        && ![self isKindOfClass:[SHBaseTableViewController class]]) //several internal used vc not need log, such as SHFeedbackViewController, SHSlideWebViewController (it calls appear even not show).
    {
        [StreetHawk shNotifyPageEnter:[self.class.description refinePageName]];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PointziBridge_ShowAuthor_Notification" object:nil userInfo:@{@"vc": self}];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    if (![self isKindOfClass:[SHBaseViewController class]]
        && ![self isKindOfClass:[SHBaseTableViewController class]]) //several internal used vc not need log, such as SHFeedbackViewController, SHSlideWebViewController (it calls appear even not show).
    {
        [StreetHawk shNotifyPageExit:[self.class.description refinePageName]];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PointziBridge_ForceDismissTip_Notification" object:nil userInfo:@{@"vc": self}];
}

@end

typedef void (^SHCoverViewOrientationChanged) ();
typedef void (^SHCoverViewTouched) (CGPoint touchPoint);

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

/**
 Callback when orientation changes.
 */
@property (nonatomic, copy) SHCoverViewOrientationChanged orientationChangedHandler;

/**
 Callback when full screen cover view is touched.
 */
@property (nonatomic, copy) SHCoverViewTouched touchedHandler;

- (void)orientationChanged:(NSNotification *)notification;

@end

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
    if (self.touchedHandler)
    {
        UITouch *touch = [[event allTouches] anyObject];
        CGPoint touchLocation = [touch locationInView:self];
        self.touchedHandler(touchLocation);
    }
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

- (void)presentOnTopWithCover:(BOOL)needCover withCoverColor:(UIColor *)coverColor withCoverAlpha:(CGFloat)coverAlpha withCoverTouchHandler:(void (^)(CGPoint touchPoint))coverTouchHandler withAnimationHandler:(void (^)(CGRect fullScreenRect))animationHandler withOrientationChangedHandler:(void (^)(CGRect))orientationChangedHandler
{
    double delayInMilliSeconds = 500; //delay, otherwise if previous is an alert view, the rootVC is UIAlertShimPresentingViewController. Test this is minimum time.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInMilliSeconds * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^(void)
    {
        UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
        CGRect rootRect = rootVC.view.bounds; //this has orientation included. when rotate it can get the real CGRect accoriding to orientation.
        self.view.frame = CGRectOffset(self.view.frame, INT_MAX, INT_MAX); //make it out of screen, but not change size.
        if (needCover)
        {
            self.coverView = [[SHCoverView alloc] initWithFrame:rootVC.view.bounds];
            self.coverView.contentVC = self; //must have someone retain self as VC. Because it only added view and VC is dealloc, causing keyboard notification cannot trigger. Here has cover view to retain it. This only needed for keyboard input view controller, such as feedback input VC.
            self.coverView.overlayColor = coverColor;
            self.coverView.overlayAlpha = coverAlpha;
            self.coverView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; //make cover always full screen during rotation.
            [rootVC.view addSubview:self.coverView];
            self.view.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin; //content vc by default always in center, not affected by rotatation.
            [self.coverView addSubview:self.view];
            if (coverTouchHandler != nil)
            {
                self.coverView.touchedHandler = ^ (CGPoint touchPoint)
                {
                    coverTouchHandler(touchPoint);
                };
            }
            if (orientationChangedHandler != nil)
            {
                self.coverView.orientationChangedHandler = ^
                {
                    orientationChangedHandler(rootVC.view.bounds); //get root rect after orientation.
                };
            }
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
    });
}

- (void)dismissOnTop
{
    [self.view removeFromSuperview];
    if (self.coverView != nil)
    {
        [self.coverView removeFromSuperview];
        self.coverView.contentVC = nil; //break loop retain to make self dealloc
    }
}

@end

